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
        ARCH = 'x86_64'
        YAML_CONFIG = 'kvmqe-ci/jobs/virtio-win-acceptance/config'
        JOB_GROUP = 'runtest'
        HUB_URL = 'https://beaker.engineering.redhat.com'
        LAB_CONTROLLER = 'lab-01.rhts.eng.pek2.redhat.com'
        TIMEOUT_MONITOR_BEAKER = '7'
    }

    options {
        buildDiscarder(logRotator(daysToKeepStr: '180', artifactDaysToKeepStr: '180'))
        timestamps()
    }

    stages {

        stage("Checkout the source code") {
            steps {
                script {
                    logging.info("Checkout source code")
                    cleanWs()
                    currentBuild.displayName = params.BREW_NVR
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

        stage("Parse variables values from Yaml") {
            steps {
                script {
                    logging.info("Parse variables values from Yaml")
                    env.COMPOSE_VERSION = component.getComposeVersion(params.COMPOSE_ID).substring(0,3)
                    datas = readYaml file: env.YAML_CONFIG
                    env.EMAIL_RECIPIENTS = datas.get(env.JOB_GROUP).get("email_recipients")
                    env.RESERVE_TIME = datas.get(env.JOB_GROUP).get("reserve_time")
                    env.JOB_OWNER = datas.get(env.JOB_GROUP).get("job_owner")

                    env.KAR_CMD = datas.get(env.JOB_GROUP).get("windows_group").get(params.WINDOWS_GROUP).get(params.OSVERSION).get("kar_cmd")
                    env.KAR_CMD += " --customsparams=\"cdrom_virtio = isos/windows/${params.BREW_NVR}.iso\""

                    env.WHITEBOARD = "Acceptance testing (${params.BREW_NVR} - ${params.WINDOWS_GROUP} - ${params.OSVERSION} - ${params.MODULE_STREAM})"
                    env.OUT_FILE = "${env.WORKSPACE}/beaker-job-${params.OSVERSION}.xml"
                    env.ENV_OPTIONS = datas.get(env.JOB_GROUP).get("env-options")
                    env.HOSTNAME = datas.get(env.JOB_GROUP).get("windows_group").get(params.WINDOWS_GROUP).get("hostname")
                    env.PROFILE = "${params.OSVERSION}.x86_64"

                    env.INSTALL_PARAMS = datas.get(env.JOB_GROUP).get("module_stream").get(params.MODULE_STREAM).get("install_params").replaceAll('\\$\\{\\{COMPOSE_VERSION\\}\\}', env.COMPOSE_VERSION)
                    env.REPO_URLS = datas.get(env.JOB_GROUP).get("module_stream").get(params.MODULE_STREAM).get("repo").replaceAll('\\$\\{\\{MAJOR_VERSION\\}\\}', env.COMPOSE_VERSION.split('\\.')[0])

                    cmdGen = "bkr workflow-xslt --dry-run"
                    cmdGen += " --profile '${env.PROFILE}'"
                    cmdGen += " --distro '${params.COMPOSE_ID}'"
                    cmdGen += " --install-params '${env.INSTALL_PARAMS}'"
                    cmdGen += " --task-cmd '${env.KAR_CMD}'"
                    cmdGen += " --whiteboard '${env.WHITEBOARD}'"
                    cmdGen += " --save-xml '${env.OUT_FILE}'"
                    cmdGen += " --hostname '${env.HOSTNAME}'"
                    cmdGen += " --env-options '${env.ENV_OPTIONS}'"

                    if (env.REPO_URLS) {
                        cmdGen += " --repos '${env.REPO_URLS}'"
                    }
                    if (env.RESERVE_TIME) {
                        cmdGen += " --reserve-time '${env.RESERVE_TIME}'"
                    }
                }
            }
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
            }
        }
    }
}//end pipeline
