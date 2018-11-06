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
                    env.BOOTSTRAP_PARAMS = datas.get(env.JOB_GROUP).get("bootstrap_params")
                    env.RESERVE_TIME = datas.get(env.JOB_GROUP).get("reserve_time")
                    env.JOB_OWNER = datas.get(env.JOB_GROUP).get("job_owner")
                    env.XML_FILE = datas.get(env.JOB_GROUP).get("xml_file").replaceAll('\\$WORKSPACE', env.WORKSPACE)
                    env.KS_FILE = datas.get(env.JOB_GROUP).get("ks_file").replaceAll('\\$WORKSPACE', env.WORKSPACE)
                    env.STAF_CMD = datas.get(env.JOB_GROUP).get("windows_group").get(params.WINDOWS_GROUP).get("staf_cmd")
                    env.STAF_CMD += " --customsparams=\"cdrom_virtio = isos/windows/${params.BREW_NVR}.iso\""
                    env.HOST_REQS = datas.get(env.JOB_GROUP).get("windows_group").get(params.WINDOWS_GROUP).get("host_reqs")
                    env.WHITEBOARD = "Acceptance testing (${params.BREW_NVR} ${params.WINDOWS_GROUP}, ${params.QEMU_BREW_NVR})"
                    env.OUT_FILE = "${env.WORKSPACE}/beaker-job-${params.OSVERSION}.xml"

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
                    cmdGen = "${cmdGen} --bootstrap-params='${env.BOOTSTRAP_PARAMS}'"
                    if (env.REPO_URLS) {
                        cmdGen = "${cmdGen} --repos='${env.REPO_URLS}'"
                    }
                    if (env.KS_FILE) {
                        cmdGen = "${cmdGen} --ks-file='${env.KS_FILE}'"
                    }
                    logging.info("[Job infomation]\nvirtio-win(-prewhql)info:\t${params.BREW_NVR}\nqemu info:\t${params.QEMU_BREW_NVR} ${params.QEMU_BREW_TAG}\ncompose id:\t${env.COMPOSE_ID}\nwindows group:\t${params.WINDOWS_GROUP}\nstaf command:\t${env.STAF_CMD}")
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
                        beaker.RunBeakerJob(env.JOB_OWNER, true, env.OUT_FILE, "Acceptance testing(${params.WINDOWS_GROUP}) - ${params.BREW_NVR}")
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
                utils.emailNotification("Acceptance testing(${params.WINDOWS_GROUP}) - ${params.BREW_NVR}")
            }
        }
    }
}//end pipeline
