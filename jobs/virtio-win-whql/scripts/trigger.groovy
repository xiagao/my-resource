#!/usr/bin/env groovy

@Library('kvmqe-ci') _

def jSlaveLabel = "jslave-virt-kvm-whql"
def component = "virtio-win-prewhql"
def prewhqlVersion
def driverName
def otherParams
def qemuBrewNvr
def qemuBrewTag
def jobsList = []

pipeline {

    agent {
        label jSlaveLabel
    }

    environment {
        GERRIT_URL = 'https://code.engineering.redhat.com/gerrit'
        YAML_CONFIG = 'kvmqe-ci/jobs/virtio-win-whql/config'
        JOB_GROUP = 'trigger'
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
                    datas = readYaml file: env.YAML_CONFIG
                    env.EMAIL_RECIPIENTS = datas.get(env.JOB_GROUP).get("email_recipients")
                    env.SUPPORTED_WIN_GROUP = datas.get(env.JOB_GROUP).get("windows_group")
                    env.MAJOR = datas.get(env.JOB_GROUP).get("osversion").get(params.OSVERSION).get("major")
                }
            }
        }//end stage

        stage("Check component information") {
            steps {
                script {
                    if (!params.VIRTIO_WIN_PREWHQL_VERSION?.trim()) {
                        logging.error("Parameters are empty, please provide")
                    }
                    prewhqlVersion = params.VIRTIO_WIN_PREWHQL_VERSION

                    if (!params.DRIVER_NAME?.trim()) {
                        logging.error("Parameters are empty, please provide")
                    }
                    driverName = params.DRIVER_NAME

                    if (!params.OTHER_PARAMS?.trim()) {
                        logging.error("Parameters are empty, please provide")
                    }
                    otherParams = params.OTHER_PARAMS

                    logging.info("Manually trigger WHQL tests for ${prewhqlVersion}-${driverName}.")
                }
            }//end steps

            post {
                always {
                    script {
                        currentBuild.displayName = "${prewhqlVersion}-${driverName}"
                        for (wg in env.SUPPORTED_WIN_GROUP.split()) {
                            jobsList.add("pipeline-whql-${params.OSVERSION}-${wg}-runtest")
                        }
                    }
                }
            }//end post 
        }//end stage

        stage("Get Qemu info.") {
            steps {
                script {
                    logging.info("Get qemu info.")
                    composeID = new URL("http://download-node-02.eng.bos.redhat.com/rel-eng/latest-RHEL-${env.MAJOR}/COMPOSE_ID").getText('UTF-8').trim()
                    // RHEL-7.6-20181010.0
                    X_Y = composeID.split('-')[1]
                    qemuBrewTag = "rhevh-rhel-${X_Y}-candidate"
                    qemuBrewNvr = sh(script: "brew latest-build rhevh-rhel-7.6-candidate qemu-kvm-rhev | awk 'END {print \$1}'", returnStdout: true)
                    logging.info("The qemu version is ${qemuBrewNvr};the qemu tag is ${qemuBrewTag}")
                }
            }
        }//end stages

        stage("Trigger downstream jobs") {
            steps {
                script {
                    logging.info("Trigger downstream jobs ${jobsList}")
                    // in this array we'll place the jobs that we wish to run
                    def branches = [:]
                    for (int i = 0; i < jobsList.size(); i++) {
                        //if we tried to use i below, it would equal jobsList.size() in each job execution.
                        def index = i
                        branches["branch${i}"] = {
                            build job: "${jobsList[index]}", parameters: [
                                string(name: 'VIRTIO_WIN_PREWHQL_VERSION', value: "${prewhqlVersion}"),
                                string(name: 'DRIVER_NAME', value: "${driverName}"),
                                string(name: 'OTHER_PARAMS', value: "${otherParams}"),				
                                string(name: 'QEMU_BREW_NVR', value: "${qemuBrewNvr}"),
                                string(name: 'QEMU_BREW_TAG', value: "${qemuBrewTag}")],
                            quietPeriod: 2, propagate: false, wait: false
                        }
                    }
                    parallel branches
                }
            }
        }//end stage
    }//end stages

    post {
        always {
            script {
                utils.emailNotification("Whql testing(trigger) - ${prewhqlVersion}-${driverName}")
            }
        }
    }
}//end pipeline
