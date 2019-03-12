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
        YAML_CONFIG = 'kvmqe-ci/jobs/virtio-win-whql/config'
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
                    currentBuild.displayName = "${params.VIRTIO_WIN_PREWHQL_VERSION}-${params.DRIVER_NAME}"
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
                    env.JOB_OWNER = datas.get(env.JOB_GROUP).get("job_owner")
                    enb.PACKAGE = datas.get(env.JOB_GROUP).get("package")
                    cmd_base1 = datas.get(env.JOB_GROUP).get("windows_group").get(params.WINDOWS_GROUP).get("cmd_base1")
                    cmd_base2 = datas.get(env.JOB_GROUP).get("windows_group").get(params.WINDOWS_GROUP).get("cmd_base2")
                    if (cmd_base2 == "None") {
                        env.WHQL_CMD = "${cmd_base1} -v ${params.VIRTIO_WIN_PREWHQL_VERSION} -n ${params.DRIVER_NAME} ${params.OTHERS}"
                    } else {
                        env.WHQL_CMD = "${cmd_base1} -v ${params.VIRTIO_WIN_PREWHQL_VERSION} -n ${params.DRIVER_NAME} ${params.OTHERS} ; ${cmd_base2} -v ${params.VIRTIO_WIN_PREWHQL_VERSION} -n ${params.DRIVER_NAME} ${params.OTHERS}"
                    }

                    env.INSTALL_PARAMS = datas.get(env.JOB_GROUP).get("module_stream").get(params.MODULE_STREAM).get("install_params").replaceAll('\\$\\{\\{COMPOSE_VERSION\\}\\}', env.COMPOSE_VERSION)
                    env.REPO_URLS = datas.get(env.JOB_GROUP).get("module_stream").get(params.MODULE_STREAM).get("repo").replaceAll('\\$\\{\\{MAJOR_VERSION\\}\\}', env.COMPOSE_VERSION.split('\\.')[0])
                    env.PROFILE = "${params.OSVERSION}.x86_64"
                    env.HOSTNAME = datas.get(env.JOB_GROUP).get("windows_group").get(params.WINDOWS_GROUP).get("hostname")
                    env.WHITEBOARD = "WHQL testing (${params.VIRTIO_WIN_PREWHQL_VERSION} ${params.DRIVER_NAME} ${params.WINDOWS_GROUP})"
                    env.OUT_FILE = "${env.WORKSPACE}/beaker-job-${params.VIRTIO_WIN_PREWHQL_VERSION}.xml"
                    cmdGen = "bkr workflow-xslt --dry-run"
                    cmdGen += " --profile '${env.PROFILE}'"
                    cmdGen += " --distro '${params.COMPOSE_ID}'"
                    cmdGen += " --install-params '${env.INSTALL_PARAMS}'"
                    cmdGen += " --task-cmd '${env.WHQL_CMD}'"
                    cmdGen += " --whiteboard '${env.WHITEBOARD}'"
                    cmdGen += " --save-xml '${env.OUT_FILE}'"
                    cmdGen += " --hostname '${env.HOSTNAME}'"
                    cmdGen += " --package '${env.PACKAGE}'"
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
                    ws("${env.WORKSPACE}/kvmqe-ci/utils/beaker-workflow/WHQL") {
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
            script {
                utils.emailNotification("WHQL testing(${params.VIRTIO_WIN_PREWHQL_VERSION} - ${params.DRIVER_NAME} - ${params.WINDOWS_GROUP})")
            }
        }
    }
}//end pipeline
