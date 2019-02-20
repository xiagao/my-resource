#!/usr/bin/env groovy

@Library('kvmqe-ci') _

def jSlaveLabel = "jslave-virt-kvm-whql"
def brewNvr
def composeID
def jobsList = []

pipeline {

    agent {
        label jSlaveLabel
    }

    environment {
        GERRIT_URL = 'https://code.engineering.redhat.com/gerrit'
        YAML_CONFIG = 'my-resource/virtio-win-acceptance/config'
        HUB_URL = 'https://beaker.engineering.redhat.com'
        LAB_CONTROLLER = 'lab-01.rhts.eng.pek2.redhat.com'
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
                        relativeTargetDir: 'my-resource']],
                      userRemoteConfigs: [[url: "https://github.com/xiagao/my-resource"]]
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
                    env.MAJOR = datas.get(env.JOB_GROUP).get("osversion").get(params.OSVERSION).get("major")
                    env.MODULE_STREAM = datas.get(env.JOB_GROUP).get("osversion").get(params.OSVERSION).get("module_stream")
                    env.SUPPORTED_WIN_GROUP = datas.get(env.JOB_GROUP).get("windows_group")
                    if (env.MODULE_STREAM == "fast-train"){
                        env.SUPPORTED_WIN_GROUP = datas.get(env.JOB_GROUP).get("windows_group_fast_train")
                    }
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
                            } catch (Exception ex) {
                                logging.error("Failed to get component information, error message:\n${ex}")
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
                            if (!params.BREW_NVR?.trim()) {
                                logging.error("Parameters are empty, please provide")
                            }
                            brewNvr = params.BREW_NVR
                            logging.info("Manually trigger Acceptance tests for ${params.BREW_NVR}")
                        }
                    }
                }//end stage
            }//end parallel

            post {
                always {
                    script {
                        currentBuild.displayName = brewNvr
                        for (wg in env.SUPPORTED_WIN_GROUP.split()) {
                            for (ms in env.MODULE_STREAM.split()) {
                                jobsList.add("pipeline-${params.COMPONENT}-${params.OSVERSION}-${ms}-${wg}-runtest")
                            }
                        }
                    }
                }
            }
        }//end parallel stage
        
        stage("Update virtio-win.iso(virtio-win-prewhql.iso) to NFS server.") {
            steps {
                script {
                    logging.info("The new brew package is ${brewNvr} and update iso to NFS.")
                    if (brewNvr =~ /virtio-win-prewhql/) {
                        verNum = brewNvr.split('-')[4]
                        isoCmd = "${env.WORKSPACE}/kvmqe-ci/jobs/virtio-win-acceptance/scripts/prewhql_iso_create.sh -u -w ${verNum}"
                    } else if (brewNvr =~ /virtio-win.*el/) {
                        isoCmd = "${env.WORKSPACE}/kvmqe-ci/jobs/virtio-win-acceptance/scripts/virtio-win/update_virtio_win.py"
                    } else {
                        logging.error("Failed to get brew pkg version.")
                    }
                    // run iso cmd.
                    if (sh(returnStatus: true, script: "${isoCmd}") != 0) {
                        logging.error("Failed to update ${brewNvr} iso to NFS.")
                    }
                }
            }
        }//end stages

        stage("Get Compose ID.") {
            steps {
                script {
                    logging.info("Get compose ID.")
                    // RHEL-7.6-20181010.0, RHEL-8.0.0-20190213.0
                    composeID_url = new URL("http://download-node-02.eng.bos.redhat.com/rhel-${env.MAJOR}/rel-eng/RHEL-${env.MAJOR}/latest-RHEL-${env.MAJOR}/COMPOSE_ID").getText('UTF-8').trim()
                    // get the distro_version, such as 7.6, 8.0.0
                    distro_version = composeID_url.split('-')[1]
                    // get the latest distro name of beaker via distro version
                    composeID = component.getComposeID(distro_version, params.OSVERSION, true)
                    if (!composeID) {
                        logging.error("Failed to get Compose ID")
                    }
                    logging.info("The compose id is ${composeID}.")
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
                                string(name: 'BREW_NVR', value: "${brewNvr}"),
                                string(name: 'COMPOSE_ID', value: "${composeID}")],
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
                utils.emailNotification("Acceptance testing(trigger) - ${brewNvr} - ${composeID}")
            }
        }
    }
}//end pipelinE
