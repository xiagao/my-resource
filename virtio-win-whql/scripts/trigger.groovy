#!/usr/bin/env groovy

@Library('kvmqe-ci') _

def jSlaveLabel = "jslave-virt-kvm-whql"
def prewhqlVersion
def driverName
def otherParams
def targetRelease
def jobsList = []
def isNotification = true

properties(
    [
        [$class: 'CachetJobProperty',
            requiredResources: true,
            resources: [
                'beaker',
                'brew',
                'code.engineering.redhat.com',
                'openstack.psi.redhat.com',
                'umb'
            ]
        ]
    ]
)

pipeline {
    agent {
        label jSlaveLabel
    }

    environment {
        GERRIT_URL = 'https://code.engineering.redhat.com/gerrit'
        YAML_CONFIG = 'my-resource/virtio-win-whql/config/whql_config.yml'
        EMAIL_RECIPIENTS = 'xiagao@redhat.com'
    }

    options {
        buildDiscarder(logRotator(daysToKeepStr: '180', numToKeepStr: '', artifactDaysToKeepStr: '180', artifactNumToKeepStr: ''))
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

        stage("Trigger job manually.") {
            steps {
                script {
                    logging.info("Trigger job manually.")
                    if (!params.VIRTIO_WIN_PREWHQL_VERSION?.trim() || !params.DRIVER_NAME?.trim() || !params.OTHER_PARAMS?.trim() || !params.TARGET_RELEASE?.trim())  {
                        logging.error("Parameters are empty, please provide")
                    }
                    prewhqlVersion = params.VIRTIO_WIN_PREWHQL_VERSION
                    driverName = params.DRIVER_NAME
                    otherParams = params.OTHER_PARAMS
                    targetRelease = params.TARGET_RELEASE
                    logging.info("Manually trigger WHQL tests for ${prewhqlVersion}-${driverName}")
                }//end script
            }//end steps
            post {
                success {
                    script {
                        currentBuild.displayName = "${prewhqlVersion}-${driverName}-${targetRelease}"
                    }
                }
            }//end post 
        }//end stage

        stage("Generate the list of downstream jobs") {
            steps {
                script {
                    logging.info("Generate the list of downstream jobs")
                    confs = readYaml file: env.YAML_CONFIG
                    tasks = confs.get('tasks')
                    for (task in tasks.keySet()) {
                        jobsList.add("whql-${task}")
                    }
                    if (jobsList.isEmpty()) {
                        logging.error("No tests could be run according to the given parameters")
                    }
                }//end script
            }//end steps
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
                                string(name: 'VIRTIO_WIN_PREWHQL_VERSION', value: "${prewhqlVersion}"),
                                string(name: 'DRIVER_NAME', value: "${driverName}"),
                                string(name: 'OTHER_PARAMS', value: "${otherParams}"),
                                string(name: 'TARGET_RELEASE', value: "${targetRelease}")],
                            quietPeriod: 2, propagate: false, wait: false
                        }
                    }
                    parallel branches
                }//end script
            }//end steps
        }//end stage
    }//end stages

    post {
        always {
            script {
                if (isNotification) {
                    utils.emailNotification("trigger - virtio-win-prewhql-${prewhqlVersion} whql test")
                }
            }//end script
        }//end always
    }//end post
}//end pipeline
