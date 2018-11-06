#!/usr/bin/env groovy

@Library('kvmqe-ci') _

def jSlaveLabel = "jslave-virt-kvm-x86"
def cmdGen

pipeline {

    agent {
        label jSlaveLabel
    }

    environment {
        GERRIT_URL = 'https://code.engineering.redhat.com/gerrit'
        ARCH = 'x86_64'
        YAML_CONFIG = 'kvmqe-ci/jobs/compose/config'
        JOB_GROUP = 'runtest-x86_64'
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
                    currentBuild.displayName = params.COMPOSE_ID
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
                    env.COMPOSE_VERSION = component.getComposeVersion(params.COMPOSE_ID)
                    datas = readYaml file: env.YAML_CONFIG
                    env.EMAIL_RECIPIENTS = datas.get(env.JOB_GROUP).get("email_recipients")
                    env.JOB_OWNER = datas.get(env.JOB_GROUP).get("job_owner")
                    env.RESERVE_TIME = datas.get(env.JOB_GROUP).get("reserve_time")
                    env.XML_FILE = datas.get(env.JOB_GROUP).get("xml_file").replaceAll('\\$WORKSPACE', env.WORKSPACE)
                    env.BOOTSTRAP_PARAMS = datas.get(env.JOB_GROUP).get("bootstrap_params")
                    env.PKG_LIST = datas.get(env.JOB_GROUP).get("test_type").get(params.TEST_TYPE).get("pkg_list")
                    env.QEMU_REQ = datas.get(env.JOB_GROUP).get("test_type").get(params.TEST_TYPE).get("qemu_req").replaceAll('\\$\\{\\{COMPOSE_VERSION\\}\\}', env.COMPOSE_VERSION)
                    env.STAF_CMD = datas.get(env.JOB_GROUP).get("test_type").get(params.TEST_TYPE).get("staf_cmd").replaceAll('\\$\\{\\{COMPOSE_VERSION\\}\\}', env.COMPOSE_VERSION)
                    env.HOST_REQS = datas.get(env.JOB_GROUP).get("hardware").get(params.HARDWARE).get("host_reqs")
                    env.KS_FILE = datas.get(env.JOB_GROUP).get("osversion").get(params.OSVERSION).get("ks_file").replaceAll('\\$WORKSPACE', env.WORKSPACE)
                    env.OUT_FILE = "${env.WORKSPACE}/beaker-job-${params.HARDWARE}-${params.TEST_TYPE}.xml"
                    env.WHITEBOARD = "Compose testing (${params.COMPOSE_ID} ${params.TEST_TYPE}, ${params.HARDWARE})"

                    cmdGen = "${env.WORKSPACE}/kvmqe-ci/utils/jobgen/jobgen"
                    cmdGen += " --arch='${env.ARCH}'"
                    cmdGen += " --compose='${params.COMPOSE_ID}'"
                    cmdGen += " --bootstrap-params='${env.BOOTSTRAP_PARAMS}'"
                    cmdGen += " --staf-cmd=\"${env.STAF_CMD}\""
                    cmdGen += " --out-file='${env.OUT_FILE}'"
                    cmdGen += " --whiteboard='${env.WHITEBOARD}'"
                    cmdGen += " --reserve-time='${env.RESERVE_TIME}'"
                    cmdGen += " --host-requires='${env.HOST_REQS}'"
                    if (env.KS_FILE) {
                        cmdGen += " --ks-file='${env.KS_FILE}'"
                    }
                    cmdGen += " --xml-file='${env.XML_FILE}'"
                    if (env.PKG_LIST) {
                        cmdGen += " --packages='${env.PKG_LIST}'"
                    }
                    if (env.QEMU_REQ) {
                        cmdGen += " --qemu-req='${env.QEMU_REQ}'"
                    }
                    logging.info("[Job infomation]\ncompose id:\t${params.COMPOSE_ID}\nhost type:\t${params.HARDWARE}\nstaf cmd:\t${env.STAF_CMD}")
                }
            }
        }//end stage

        stage("Run tests") {
            steps {
                script {
                    logging.info("Run tests")
                    if (sh(returnStatus: true, script: "${cmdGen}") != 0) {
                        logging.error("Failed to generate beaker job")
                    }
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
                utils.emailNotification("Compose testing(${params.TEST_TYPE}, ${params.HARDWARE}) - ${params.COMPOSE_ID}")
            }
        }
    }
}
