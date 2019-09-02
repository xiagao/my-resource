#!/usr/bin/env groovy

@Library('kvmqe-ci') _

def jSlaveLabel = "jslave-virt-kvm-whql"
def cmdGen
def isNotification = false
def msgAuditFile = "messages/message-audit.json"
def datagrepperRetryCount = 120

pipeline {

    agent {
        label jSlaveLabel
    }

    environment {
        GERRIT_URL = 'https://code.engineering.redhat.com/gerrit'
        YAML_CONFIG = 'kvmqe-ci/jobs/virtio-win-acceptance/config/virtio_win_config.yml'
        ARTIFACT = 'brew-build'
        HUB_URL = 'https://beaker.engineering.redhat.com'
        LABCONTROLLER = 'lab-01.rhts.eng.pek2.redhat.com'
        ARCH = 'x86_64'
        TIMEOUT_MONITOR_BEAKER = '7'
        RESERVE_TIME = 72
    }

    options {
        timestamps()
        buildDiscarder(logRotator(daysToKeepStr: '180', numToKeepStr: '', artifactDaysToKeepStr: '180', artifactNumToKeepStr: ''))
    }

    stages {
        stage("Checkout the source code") {
            steps {
                script {
                    logging.info("Checkout source code")
                    cleanWs()
                }
                checkout(
                    [$class: 'GitSCM', branches: [[name: '*/master']],
                      extensions: [[$class: 'RelativeTargetDirectory',
                        relativeTargetDir: 'kvmqe-ci']],
                      userRemoteConfigs: [[url: "${GERRIT_URL}/kvmqe-ci.git"]]
                    ]
                )
            }
        }//end stage
        stage("Parse configurations for the tests") {
            steps {
                script {
                    logging.info("Parse configurations for the tests")
                    pipelineUtils.initializeAuditFile(msgAuditFile)
                    env.NVR = params.NVR
                    env.TARGET_RELEASE = params.TARGET_RELEASE.toUpperCase().replaceAll('-Z', '-z')
                    pipelineUtils.taskIdFromNVR(env.NVR)
                    // env.JOB_BASE_NAME from jenkins env variable
                    env.TASK = env.JOB_BASE_NAME.split(/-el\d+-/)[1]
                    pipelineUtils.buildMdFromId(env.BREW_TASK_ID)
                    env.PKG_NAME = pipelineUtils.pkgNameFromNVR(env.NVR)
                    pipelineUtils.getTargetStream()

                    confs = readYaml file: env.YAML_CONFIG
                    task_info = confs.get('builds').get(env.PKG_NAME).get('target_stream').get(env.TARGET_STREAM).get('tasks').get(env.TASK)
                    jobmd_index = task_info.get('jobmd')
                    env.EMAIL_RECIPIENTS = confs.get('jobmd_list').get(jobmd_index).get('email_recipients')
                    env.JOB_OWNER = confs.get('jobmd_list').get(jobmd_index).get('job_owner')
                    env.IS_GATING = confs.get('jobmd_list').get(jobmd_index).get('is_gating')

                    kar_cmd_index = task_info.get('kar_cmd')
                    env.KAR_CMD = confs.get('kar_cmd_list').get(kar_cmd_index).get('cmd')
                    env.KAR_CMD += " --customsparams=\"cdrom_virtio = isos/windows/${env.NVR}.iso\""
                    env.HOSTNAME = confs.get('kar_cmd_list').get(kar_cmd_index).get('hostname')

                    install_params = confs.get('kar_cmd_list').get(kar_cmd_index).get('install_params')
                    os_version = pipelineUtils.getOSVersion()
                    if (os_version.compareToIgnoreCase('8') >= 0) {
                        latest_virt = pipelineUtils.getLatestVirt(install_params)
                        env.INSTALL_PARAMS = install_params.replaceAll('\\$\\{\\{LATEST_FAST_VIRT\\}\\}', latest_virt)
                    } else {
                        env.INSTALL_PARAMS = install_params.replaceAll('\\$\\{\\{OS_VERSION\\}\\}', os_version)
                    }

                    env.DISTRO_NAME = pipelineUtils.distroNameFromTargetRelease(env.TARGET_RELEASE)
                    env.PROFILE = "${env.TARGET_STREAM}.x86_64"
                    env.OUT_FILE = "${env.WORKSPACE}/beaker-job.xml"
                    env.WHITEBOARD = "Brew build(testing) - (${env.NVR}, ${env.TARGET_RELEASE}, ${env.TASK})"

                    cmdGen = "bkr workflow-xslt --dry-run"
                    cmdGen += " --profile '${env.PROFILE}'"
                    cmdGen += " --distro '${env.DISTRO_NAME}'"
                    cmdGen += " --install-params '${env.INSTALL_PARAMS}'"
                    cmdGen += " --task-cmd '${env.KAR_CMD}'"
                    cmdGen += " --whiteboard '${env.WHITEBOARD}'"
                    cmdGen += " --save-xml '${env.OUT_FILE}'"
                    cmdGen += " --hostname '${env.HOSTNAME}'"
                    cmdGen += " --reserve-time '${env.RESERVE_TIME}'"
                    if (env.EXTRA_REPO) {
                        cmdGen += " --repos '${env.EXTRA_REPO}'"
                    }
                    if (env.PRODUCT_STREAM) {
                        cmdGen += " --product-stream '${env.PRODUCT_STREAM}'"
                    }
                }//end script
            }//end steps
            post {
                always {
                    script {
                        currentBuild.displayName = env.NVR
                    }//end script
                }//end always
            }//end post
        }//end stage

        stage("Run tests") {
            steps {
                script {
                    logging.info("Run tests")
                    ws("${env.WORKSPACE}/kvmqe-ci/utils/beaker-workflow") {
                        if (sh(returnStatus: true, script: "${cmdGen}") != 0) {
                            logging.error("Failed to generate beaker job")
                        }
                    }
                    timeout(time: env.TIMEOUT_MONITOR_BEAKER.toInteger(), unit: 'DAYS') {
                        beaker.RunBeakerJob(env.JOB_OWNER, true, env.OUT_FILE, env.WHITEBOARD)
                    }
                    beaker.getJunitResult()
                }
            }
        } //end stage
    }//end stages

    post {
        always {
            archiveArtifacts artifacts: '*.xml', fingerprint: true, allowEmptyArchive: true
            step([$class: 'XUnitBuilder',
                    thresholds: [[$class: 'FailedThreshold', failureThreshold: '0']],
                    tools: [[$class: 'JUnitType', pattern: 'Result.xml']]])
            script {
                utils.emailNotification(env.WHITEBOARD)
                if (isNotification) {
                    try {
                        utils.emailNotification(env.WHITEBOARD)
                        isPass = pipelineUtils.checkResultFromXunit()
                        if (!env.XUNIT?.trim()) {
                            messageFields = pipelineUtils.setMessageFields('error', env.ARTIFACT, 'functional', 'ERROR')
                            pipelineUtils.sendMessageWithAudit(messageFields['topic'], messageFields['properties'], messageFields['content'], msgAuditFile, datagrepperRetryCount)
                        } else if (isPass) {
                            messageFields = pipelineUtils.setMessageFields('complete', env.ARTIFACT, 'functional', 'PASSED')
                            pipelineUtils.sendMessageWithAudit(messageFields['topic'], messageFields['properties'], messageFields['content'], msgAuditFile, datagrepperRetryCount)
                        } else {
                            messageFields = pipelineUtils.setMessageFields('complete', env.ARTIFACT, 'functional', 'FAILED')
                            pipelineUtils.sendMessageWithAudit(messageFields['topic'], messageFields['properties'], messageFields['content'], msgAuditFile, datagrepperRetryCount)
                        }
                    } catch (e) {
                        messageFields = pipelineUtils.setMessageFields('error', env.ARTIFACT, 'functional', 'ERROR')
                        pipelineUtils.sendMessageWithAudit(messageFields['topic'], messageFields['properties'], messageFields['content'], msgAuditFile, datagrepperRetryCount)
                    }
                }
            }//end script
        }//end always
    }//end post
}//end pipeline
