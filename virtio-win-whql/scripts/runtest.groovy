#!/usr/bin/env groovy

@Library('kvmqe-ci') _

def jSlaveLabel = "jslave-virt-kvm-whql"
def cmdGen


pipeline {
    agent {
        label jSlaveLabel
    }

    environment {
        GERRIT_URL = 'https://code.engineering.redhat.com/gerrit'
        YAML_CONFIG = 'my-resource/jobs/virtio-win-whql/config/whql_config.yml'
        // needed by beaker workflow
        HUB_URL = 'https://beaker.engineering.redhat.com'
        LABCONTROLLER = 'lab-01.rhts.eng.pek2.redhat.com'
        ARCH = 'x86_64'
        TIMEOUT_MONITOR_BEAKER = '7'
        RESERVE_TIME = 72
        PROFILE = 'el8.x86_64'
    }

    options {
        buildDiscarder(logRotator(daysToKeepStr: '180', numToKeepStr: '', artifactDaysToKeepStr: '180', artifactNumToKeepStr: ''))
        timestamps()
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
                        relativeTargetDir: 'my-resource']],
                      userRemoteConfigs: [[url: "https://github.com/xiagao/my-resource"]]
                    ]
                )
            }
        }//end stage

        stage("Parse configurations for the tests") {
            steps {
                script {
                    logging.info("Parse variables values from Yaml config file.")
                    env.TARGET_RELEASE = params.TARGET_RELEASE.toUpperCase().replaceAll('-Z', '-z')
                    env.DISTRO_NAME = pipelineUtils.distroNameFromTargetRelease(env.TARGET_RELEASE)

                    confs = readYaml file: env.YAML_CONFIG
                    env.PACKAGE =confs.get('wqhl_cmd_list').get('package')
                    install_params = confs.get('wqhl_cmd_list').get('install_params')
                    latest_virt = pipelineUtils.getLatestVirt(install_params)
                    env.INSTALL_PARAMS = install_params.replaceAll('\\$\\{\\{LATEST_FAST_VIRT\\}\\}', latest_virt)

                    // env.JOB_BASE_NAME from jenkins env variable
                    env.TASK = env.JOB_BASE_NAME.split(/-el\d+-/)[1]
                    task_info = confs.get('tasks').get(env.TASK)

                    jobmd_index = task_info.get('jobmd')
                    env.EMAIL_RECIPIENTS = confs.get('jobmd_list').get(jobmd_index).get('email_recipients')
                    env.JOB_OWNER = confs.get('jobmd_list').get(jobmd_index).get('job_owner')

                    whql_cmd_index = task_info.get('whql_cmd')
                    env.HOSTNAME = confs.get('wqhl_cmd_list').get(whql_cmd_index).get('hostname')
                    cmd_base1 = confs.get('wqhl_cmd_list').get(whql_cmd_index).get('cmd_base1')
                    cmd_base2 = confs.get('wqhl_cmd_list').get(whql_cmd_index).get('cmd_base2')
                    if (cmd_base2 == "None") {
                        env.WHQL_CMD = "${cmd_base1} -v ${params.VIRTIO_WIN_PREWHQL_VERSION} -n ${params.DRIVER_NAME} ${params.OTHER_PARAMS}"
                    } else {
                        env.WHQL_CMD = "${cmd_base1} -v ${params.VIRTIO_WIN_PREWHQL_VERSION} -n ${params.DRIVER_NAME} ${params.OTHER_PARAMS} ; ${cmd_base2} -v ${params.VIRTIO_WIN_PREWHQL_VERSION} -n ${params.DRIVER_NAME} ${params.OTHER_PARAMS}"
                    }

                    env.WHITEBOARD = "WHQL testing - (${params.VIRTIO_WIN_PREWHQL_VERSION}, ${params.DRIVER_NAME}, ${env.TASK})"
                    env.OUT_FILE = "${env.WORKSPACE}/beaker-job-${params.VIRTIO_WIN_PREWHQL_VERSION}.xml"

                    cmdGen = "bkr workflow-xslt --dry-run"
                    cmdGen += " --profile '${env.PROFILE}'"
                    cmdGen += " --distro '${env.DISTRO_NAME}'"
                    cmdGen += " --install-params '${env.INSTALL_PARAMS}'"
                    cmdGen += " --task-cmd '${env.WHQL_CMD}'"
                    cmdGen += " --whiteboard '${env.WHITEBOARD}'"
                    cmdGen += " --save-xml '${env.OUT_FILE}'"
                    cmdGen += " --hostname '${env.HOSTNAME}'"
                    cmdGen += " --package '${env.PACKAGE}'"
                    cmdGen += " --reserve-time '${env.RESERVE_TIME}'"
                    if (env.EXTRA_REPO) {
                        cmdGen += " --repos '${env.EXTRA_REPO}'"
                    }
                    if (env.PRODUCT_STREAM) {
                        cmdGen += " --product-stream '${env.PRODUCT_STREAM}'"
                }
            }//end script
            post {
                always {
                    script {
                        currentBuild.displayName = "${params.VIRTIO_WIN_PREWHQL_VERSION} - ${params.DRIVER_NAME}"
                    }//end script
                }//end always
            }//end post
        }//end stage

        stage("Run tests") {
            steps {
                script {
                    logging.info("Run tests")
                    ws("${env.WORKSPACE}/my-resource/utils/beaker-workflow/WHQL") {
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
        success {
            archiveArtifacts artifacts: '*.xml', fingerprint: true, allowEmptyArchive: true
            script {
                utils.emailNotification(env.WHITEBOARD)
            }
        }
    }//end post
}//end pipeline
