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
                    env.COMPOSE_ID = component.getComposeID(params.QEMU_BREW_TAG, params.OSVERSION, true)
                    if (!env.COMPOSE_ID) {
                        logging.error("Failed to get Compose ID")
                    }
                    dependTag = component.getDependTag(params.OSVERSION, params.QEMU_BREW_TAG, params.QEMU_BREW_NVR)
                    env.REPO_URLS = component.getRepos(dependTag)
                    if (env.REPO_URLS && !env.COMPOSE_ID.contains(".n.")) {
                        env.REPO_URLS = env.REPO_URLS.replaceAll('\\$basearch', env.ARCH)
                    }
                    datas = readYaml file: env.YAML_CONFIG
                    env.EMAIL_RECIPIENTS = datas.get(env.JOB_GROUP).get("email_recipients")
                    env.RESERVE_TIME = datas.get(env.JOB_GROUP).get("reserve_time")
                    env.JOB_OWNER = datas.get(env.JOB_GROUP).get("job_owner")
                    env.XML_FILE = datas.get(env.JOB_GROUP).get("xml_file").replaceAll('\\$WORKSPACE', env.WORKSPACE)
                    env.KS_FILE = datas.get(env.JOB_GROUP).get("ks_file").replaceAll('\\$WORKSPACE', env.WORKSPACE)

                    cmd_base1 = datas.get(env.JOB_GROUP).get("windows_group").get(params.WINDOWS_GROUP).get("cmd_base1")
                    cmd_base2 = datas.get(env.JOB_GROUP).get("windows_group").get(params.WINDOWS_GROUP).get("cmd_base2")
                    if (${cmd_base2} == "None") {
                        env.STAF_CMD = "${cmd_base1} -v ${params.VIRTIO_WIN_PREWHQL_VERSION} -n ${params.DRIVER_NAME} ${params.OTHERS}"
                    } else {
                        env.STAF_CMD = "${cmd_base1} -v ${params.VIRTIO_WIN_PREWHQL_VERSION} -n ${params.DRIVER_NAME} ${params.OTHERS} ; ${cmd_base2} -v ${params.VIRTIO_WIN_PREWHQL_VERSION} -n ${params.DRIVER_NAME} ${params.OTHERS}"
                    }
 
                    env.HOST_REQS = datas.get(env.JOB_GROUP).get("windows_group").get(params.WINDOWS_GROUP).get("host_reqs")
                    env.WHITEBOARD = "WHQL testing (${params.VIRTIO_WIN_PREWHQL_VERSION} ${params.DRIVER_NAME} ${params.WINDOWS_GROUP}, ${params.QEMU_BREW_NVR})"
                    env.OUT_FILE = "${env.WORKSPACE}/beaker-job-${params.VIRTIO_WIN_PREWHQL_VERSION}.xml"

                    cmdGen = "${env.WORKSPACE}/kvmqe-ci/utils/jobgen/jobgen"
                    cmdGen = "${cmdGen} --arch='${env.ARCH}'"
                    cmdGen = "${cmdGen} --compose='${env.COMPOSE_ID}'"
                    cmdGen = "${cmdGen} --qemu-req='${params.QEMU_BREW_NVR}'"
                    cmdGen = "${cmdGen} --staf-cmd='${env.STAF_CMD}'"
                    cmdGen = "${cmdGen} --out-file='${env.OUT_FILE}'"
                    cmdGen = "${cmdGen} --whiteboard='${env.WHITEBOARD}'"
                    cmdGen = "${cmdGen} --reserve-time='${env.RESERVE_TIME}'"
                    cmdGen = "${cmdGen} --host-requires='${env.HOST_REQS}'"
                    cmdGen = "${cmdGen} --xml-file='${env.XML_FILE}'"
                    if (env.REPO_URLS) {
                        cmdGen = "${cmdGen} --repos='${env.REPO_URLS}'"
                    }
                    if (env.KS_FILE) {
                        cmdGen = "${cmdGen} --ks-file='${env.KS_FILE}'"
                    }
                    logging.info("[Job infomation]\nvirtio-win-prewhql info:\t${params.VIRTIO_WIN_PREWHQL_VERSION} ${params.DRIVER_NAME}\nqemu info:\t${params.QEMU_BREW_NVR} ${params.QEMU_BREW_TAG}\ncompose id:\t${env.COMPOSE_ID}\nwindows group:\t${params.WINDOWS_GROUP}\nwhql command:\t${env.STAF_CMD}")
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
                        beaker.RunBeakerJob(env.JOB_OWNER, true, env.OUT_FILE, "WHQL testing(${params.WINDOWS_GROUP}) - ${params.DRIVER_NAME} -${params.VIRTIO_WIN_PREWHQL_VERSION}")
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
                utils.emailNotification("WHQL testing(${params.VIRTIO_WIN_PREWHQL_VERSION} - ${params.DRIVER_NAME} - ${params.WINDOWS_GROUP})")
            }
        }
    }
}//end pipeline
