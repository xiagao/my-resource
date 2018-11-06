#!/usr/bin/env groovy

@Library('kvmqe-ci') _

def jSlaveLabel = "jslave-virt-kvm-ppc"
def cmdGen

pipeline {

    agent {
        label jSlaveLabel
    }

    environment {
        GERRIT_URL = 'https://code.engineering.redhat.com/gerrit'
        ARCH = 'ppc64le'
        YAML_CONFIG = 'kvmqe-ci/jobs/acceptance/config'
        JOB_GROUP = 'runtest-ppc64le'
        HUB_URL = 'https://beaker.engineering.redhat.com'
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
                    env.COMPOSE_ID = component.getComposeID(params.BREW_TAG, params.OSVERSION, true)
                    if (!env.COMPOSE_ID) {
                        logging.error("Failed to get Compose ID")
                    }
                    dependTag = component.getDependTag(params.OSVERSION, params.BREW_TAG, params.BREW_NVR)
                    env.REPO_URLS = component.getRepos(dependTag)
                    if (env.REPO_URLS && !env.COMPOSE_ID.contains(".n.")) {
                        env.REPO_URLS = env.REPO_URLS.replaceAll('\\$basearch', env.ARCH)
                    }
                    datas = readYaml file: env.YAML_CONFIG
                    env.EMAIL_RECIPIENTS = datas.get(env.JOB_GROUP).get("email_recipients")
                    env.JOB_OWNER = datas.get(env.JOB_GROUP).get("job_owner")
                    env.BOOTSTRAP_PARAMS = datas.get(env.JOB_GROUP).get("bootstrap_params")
                    env.RESERVE_TIME = datas.get(env.JOB_GROUP).get("reserve_time")
                    env.XML_FILE = datas.get(env.JOB_GROUP).get("xml_file").replaceAll('\\$WORKSPACE', env.WORKSPACE)
                    env.STAF_CMD = datas.get(env.JOB_GROUP).get("staf_cmd")
                    env.HOST_REQS = datas.get(env.JOB_GROUP).get("hardware").get(params.HARDWARE).get("host_reqs")
                    env.WHITEBOARD = "Acceptance testing (${params.BREW_NVR} ${params.BREW_TAG}, ${params.HARDWARE})"
                    env.OUT_FILE = "${env.WORKSPACE}/beaker-job-${params.HARDWARE}.xml"

                    cmdGen = "${env.WORKSPACE}/kvmqe-ci/utils/jobgen/jobgen"
                    cmdGen = "${cmdGen} --arch='${env.ARCH}'"
                    cmdGen = "${cmdGen} --compose='${env.COMPOSE_ID}'"
                    cmdGen = "${cmdGen} --qemu-req='${params.BREW_NVR}'"
                    cmdGen = "${cmdGen} --staf-cmd='${env.STAF_CMD}'"
                    cmdGen = "${cmdGen} --out-file='${env.OUT_FILE}'"
                    cmdGen = "${cmdGen} --whiteboard='${env.WHITEBOARD}'"
                    cmdGen = "${cmdGen} --reserve-time='${env.RESERVE_TIME}'"
                    cmdGen = "${cmdGen} --host-requires='${env.HOST_REQS}'"
                    cmdGen = "${cmdGen} --xml-file='${env.XML_FILE}'"
                    cmdGen = "${cmdGen} --bootstrap-params='${env.BOOTSTRAP_PARAMS}'"
                    if (env.REPO_URLS) {
                        cmdGen = "${cmdGen} --repos='${env.REPO_URLS}'"
                    }
                    logging.info("[Job infomation]\nqemu info:\t${params.BREW_NVR} ${params.BREW_TAG}\ncompose id:\t${env.COMPOSE_ID}\nhost type:\t${params.HARDWARE}\nstaf command:\t${env.STAF_CMD}")
                    if (sh(returnStatus: true, script: "${cmdGen}") != 0) {
                        logging.error("Failed to generate beaker job")
                    }
                }
            }
        }//end stage

        stage("Run tests") {
            steps {
                script {
                    logging.info("Run tests")
                    timeout(time: env.TIMEOUT_MONITOR_BEAKER.toInteger(), unit: 'DAYS') {
                        beaker.RunBeakerJob(env.JOB_OWNER, true, env.OUT_FILE)
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
                utils.emailNotification("Acceptance testing(${params.HARDWARE}) - ${params.BREW_NVR}")
            }
        }
    }
}//end pipeline
