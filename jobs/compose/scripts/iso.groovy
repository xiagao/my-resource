#!/usr/bin/env groovy

@Library('kvmqe-ci') _

def jSlaveLabel = "jslave-virt-kvm-x86"

pipeline {

    agent {
        label jSlaveLabel
    }

    environment {
        GERRIT_URL = 'https://code.engineering.redhat.com/gerrit'
        YAML_CONFIG = 'kvmqe-ci/jobs/compose/config'
        JOB_GROUP = 'update-iso'
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

        stage("Parse variables values from Yaml")
        {
            steps {
                script {
                    logging.info("Parse variables values from Yaml")
                    datas = readYaml file: env.YAML_CONFIG
                    env.EMAIL_RECIPIENTS = datas.get(env.JOB_GROUP).get("email_recipients")
                    env.GIM_PORT = datas.get(env.JOB_GROUP).get("gim_port")
                    env.GIM_ADDR = datas.get(env.JOB_GROUP).get("lab").get(params.LAB).get("gim_addr")
                    env.GIM_ARCHES = datas.get(env.JOB_GROUP).get("osversion").get(params.OSVERSION).get("gim_arches")
                }
            }
        }

        stage("Update iso image") {
            steps {
                script {
                    logging.info("Updating iso image ${params.COMPOSE_ID} in lab ${params.LAB}")
                    retry(3) {
                        exitCode = sh(returnStatus: true,
                            script: "$WORKSPACE/kvmqe-ci/utils/gim/gim-client -H ${env.GIM_ADDR} -p ${env.GIM_PORT} -c ${params.COMPOSE_ID} -A ${env.GIM_ARCHES}")
                        if (exitCode != 0) {
                            logging.error("Failed to update guest iso images")
                            sleep(3600)
                        }
                    }
                }
            }
        }//end stage
    }//end stages

    post {
        always {
            script {
                utils.emailNotification("Update iso - ${params.COMPOSE_ID}")
            }
        }
    }
}
