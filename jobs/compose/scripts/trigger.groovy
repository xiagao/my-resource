#!/usr/bin/env groovy

@Library('kvmqe-ci') _

def jSlaveLabel = "jslave-virt-kvm-x86"
def composeID
def jobsList = []

pipeline {

    agent {
        label jSlaveLabel
    }

    environment {
        GERRIT_URL = 'https://code.engineering.redhat.com/gerrit'
        LAB_CONTROLLER = 'lab-02.rhts.eng.bos.redhat.com'
        HUB_URL = 'https://beaker.engineering.redhat.com'
        TIMEOUT_SYNC_DISTRO = '12'
        YAML_CONFIG = 'kvmqe-ci/jobs/compose/config'
        JOB_GROUP = 'trigger'
    }

    options {
        buildDiscarder(logRotator(daysToKeepStr: '180', artifactDaysToKeepStr: '180'))
        timestamps()
        timeout(time: 7, unit: 'DAYS')
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
                    env.GIM_ADDR = datas.get(env.JOB_GROUP).get("gim_addr")
                    env.GIM_PORT = datas.get(env.JOB_GROUP).get("gim_port")
                    env.SUPPORTED_HARDWARES = datas.get(env.JOB_GROUP).get("osversion").get(params.OSVERSION).get("hardwares")
                    env.GIM_ARCHES = datas.get(env.JOB_GROUP).get("osversion").get(params.OSVERSION).get("gim_arches")
                    env.MAJOR = datas.get(env.JOB_GROUP).get("osversion").get(params.OSVERSION).get("major")
                    env.LABS = datas.get(env.JOB_GROUP).get("osversion").get(params.OSVERSION).get("labs")
                }
            }
        }

        stage('Parallel Stage: check compose information') {
            parallel {
                stage("Triggered by new published compose") {
                    when {
                        expression { !params.HARDWARES }
                    }
                    steps {
                        script {
                            composeID = new URL("http://download-node-02.eng.bos.redhat.com/rel-eng/latest-RHEL-${env.MAJOR}/COMPOSE_ID").getText('UTF-8').trim()
                            //composeID = sh(returnStdout: true, script: "curl -s  http://download-node-02.eng.bos.redhat.com/rel-eng/latest-RHEL-${env.MAJOR}/COMPOSE_ID").trim()
                            logging.info("Trigger compose '${composeID}' by new published compose")
                            composeStatus = new URL("http://download-node-02.eng.bos.redhat.com/rel-eng/latest-RHEL-${env.MAJOR}/STATUS").getText('UTF-8').trim()
                            if (composeStatus != 'FINISHED') {
                                logging.error("Distro ${composeID} is syncing")
                            }
                            timeout(time: env.TIMEOUT_SYNC_DISTRO.toInteger(), unit: 'HOURS') {
                                while(true) {
                                    try {
                                        exitCode = sh(returnStatus: true, script: "bkr distro-trees-list --hub=${env.HUB_URL} --labcontroller=${env.LAB_CONTROLLER} --name=${composeID} &> /dev/null")
                                        if (exitCode == 0) {
                                            break
                                        } else {
                                            sleep(3600) //unit: 'SECONDS'
                                        }
                                    } catch (Exception ex) {
                                        logging.warn("Distro ${composeID} is not ready in the lab ${env.LAB_CONTROLLER}, error message:\n${ex}")
                                    }
                                }
                            }
                            try {
                                cInfoMap = component.parseComposeInfo(composeID, 'rel-eng')
                            } catch (Exception ex) {
                                logging.error("Failed to get information of compose ${composeID}, error message:\n${ex}")
                            }
                            for (hw in env.SUPPORTED_HARDWARES.split()) {
                                if (component.containArch(hw.split('-')[0], cInfoMap.get("arches"))) {
                                    jobsList.add("virt-kvm-pipeline-${params.OSVERSION}-${hw}-installation-runtest")
                                    jobsList.add("virt-kvm-pipeline-${params.OSVERSION}-${hw}-functional-runtest")
                                }
                            }
                        }
                    }
                }//end stage

                stage("Triggered manually") {
                    when {
                        expression { params.HARDWARES }
                    }
                    steps {
                        script {
                            logging.info("Manually trigger compose '${params.COMPOSE_ID}'")
                            if (!params.COMPOSE_ID?.trim()) {
                                logging.error("Parameter 'COMPOSE_ID' is empty, please provide one")
                            }
                            composeID = params.COMPOSE_ID
                            for (hw in params.HARDWARES.split(',')) {
                                if (component.containArch(hw, env.SUPPORTED_HARDWARES.split())) {
                                    jobsList.add("virt-kvm-pipeline-${params.OSVERSION}-${hw}-installation-runtest")
                                    jobsList.add("virt-kvm-pipeline-${params.OSVERSION}-${hw}-functional-runtest")
                                }
                            }
                        }
                    }
                }//end stage
            }//end parallel

            post {
                always {
                    script {
                        currentBuild.displayName = composeID
                    }
                }
            }
        }//end Parallel Stage

        stage("Update iso image on the nfs server in boston lab") {
            steps {
                script {
                    logging.info("Updating iso image for ${composeID}")
                    exitCode = sh(returnStatus: true, script: "$WORKSPACE/kvmqe-ci/utils/gim/gim-client -H ${env.GIM_ADDR} -p ${env.GIM_PORT} -c ${composeID} -A ${env.GIM_ARCHES}")
                    if (exitCode != 0) {
                        logging.error("Failed to update guest iso images")
                    }
                    for (lab in env.LABS.split()) {
                        build job: "virt-kvm-pipeline-${params.OSVERSION}-update-iso-images-${lab}", parameters: [
                            string(name: 'COMPOSE_ID', value: "${composeID}")],
                        quietPeriod: 2, wait: false
                    }
                }
            }
        }//end stage

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
                                string(name: 'COMPOSE_ID', value: "${composeID}")],
                            quietPeriod: 2, propagate: false
                        }
                    }
                    parallel branches
                }
            }
        }
    }//end stages

    post {
        always {
            script {
                utils.emailNotification("Compose testing(trigger) - ${composeID}")
            }
        }
    }//end global post
}//end pipeline
