#!/usr/bin/env groovy

@Library('kvmqe-ci') _

def jSlaveLabel = "jslave-virt-kvm-x86"
def brewNvr
def brewTag
def jobsList = []

pipeline {

    agent {
        label jSlaveLabel
    }

    environment {
        GERRIT_URL = 'https://code.engineering.redhat.com/gerrit'
        YAML_CONFIG = 'kvmqe-ci/jobs/acceptance/config'
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
                    env.SUPPORTED_HARDWARES = datas.get(env.JOB_GROUP).get("component").get(params.COMPONENT).get("osversion").get(params.OSVERSION).get("hardwares")
                }
            }
        }//end stage

        stage("Parallel Stage: check component information") {
            parallel {
                stage("Triggered by new published compose") {
                    when {
                        expression {params.CI_MESSAGE}
                    }
                    steps {
                        script {
                            logging.info("Triggered by CI message(${params.CI_MESSAGE})")
                            try {
                                tagInfoMap = component.parseBrewTagInfo(params.CI_MESSAGE)
                                brewNvr = tagInfoMap.get("BREW_NVR")
                                brewTag = tagInfoMap.get("BREW_TAG")
                            } catch (Exception ex) {
                                logging.error("Failed to get tag information, error message:\n${ex}")
                            }
                            for (hw in env.SUPPORTED_HARDWARES.split()) {
                                if (component.containArch(hw.split('-')[0], tagInfoMap.get("BREW_ARCHES"))) {
                                    jobsList.add("pipeline-${params.COMPONENT}-${params.OSVERSION}-${hw}-runtest")
                                }
                            }
                        }
                    }
                }//end stage

                stage("Triggered manually") {
                    when {
                        expression {!params.CI_MESSAGE}
                    }
                    steps {
                        script {
                            if (!params.BREW_NVR?.trim() || !params.BREW_TAG?.trim() || !params.HARDWARES?.trim()) {
                                logging.error("Parameters are empty, please provide")
                            }
                            brewNvr = params.BREW_NVR
                            brewTag = params.BREW_TAG
                            logging.info("Manually trigger Acceptance tests for ${params.BREW_TAG}")
                            for (hw in params.HARDWARES.split(',')) {
                                if (component.containArch(hw, env.SUPPORTED_HARDWARES.split())) {
                                    jobsList.add("pipeline-${params.COMPONENT}-${params.OSVERSION}-${hw}-runtest")
                                }
                            }
                        }
                    }
                }//end stage
            }//end parallel

            post {
                always {
                    script {
                        currentBuild.displayName = brewNvr
                    }
                }
            }
        }//end parallel stage

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
                                string(name: 'BREW_NVR', value: "${brewNvr}"),
                                string(name: 'BREW_TAG', value: "${brewTag}")],
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
                utils.emailNotification("Acceptance testing(trigger) - ${brewNvr}")
            }
        }
    }
}//end pipeline
