#!/usr/bin/env groovy

@Library('kvmqe-ci') _

def jSlaveLabel = "jslave-virt-kvm-whql"
def prefix = 'virtkvm'
def jobsList = []
def isNotification = true
def buildRelease = ['virtio-win': '(supp-)?rhel-\\d+\\.\\d+(\\.\\d+)?(-z)?(-beta)?-gate',
                    'virtio-win-prewhql': 'rhv-\\d+\\.\\d+-rhel-\\d+\\.\\d+\\.\\d+-candidate']

/*properties(
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
)*/

pipeline {
    agent {
        label jSlaveLabel
    }

    environment {
        GIT_URL = 'https://gitlab.cee.redhat.com/kvm-qe'
        YAML_CONFIG = 'kvmqe-ci/jobs/virtio-win-acceptance/config/virtio_win_config.yml'
        ARTIFACT = 'brew-build'
        EMAIL_RECIPIENTS = 'xiagao@redhat.com, lijin@redhat.com'
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
                        relativeTargetDir: 'kvmqe-ci']],
                      userRemoteConfigs: [[url: "${GIT_URL}/kvmqe-ci.git"]]
                    ]
                )
            }
        }//end stage

        stage("Parallel Stage: Parse parameters") {
            parallel {
                stage("Triggered by new published brew build") {
                    when {
                        expression {params.CI_MESSAGE}
                    }
                    steps {
                        script {
                            logging.info("CI header:\n${params.MESSAGE_HEADERS}")
                            logging.info("CI message:\n${params.CI_MESSAGE}")
                            pipelineUtils.flattenJSON(prefix, env.CI_MESSAGE)
                            env.BREW_TASK_ID = env."${prefix}_build_task_id"
                            if (!pipelineUtils.checkRelease(env."${prefix}_tag_name", buildRelease[env."${prefix}_build_name"])) {
                                isNotification = false
                                currentBuild.displayName = env.BREW_TASK_ID
                                manager.buildAborted()
                                logging.error("Do not run tests on the build with unmatched release")
                            }
                            env.BREW_TAG = env."${prefix}_tag_name"
                            pipelineUtils.buildMdFromId(env.BREW_TASK_ID)
                            pipelineUtils.getTargetRelease()
                        }//end script
                    }//end steps
                }//end stage
                stage("Triggered manually") {
                    when {
                        expression {!params.CI_MESSAGE}
                    }
                    steps {
                        script {
                            if (!params.NVR?.trim() || !params.TARGET_RELEASE?.trim()) {
                                logging.error("Please provide the correct parameters")
                            }
                            env.NVR = params.NVR
                            env.BREW_TAG = params.BREW_TAG
                            env.TARGET_RELEASE = params.TARGET_RELEASE
                        }//end script
                    }//end steps
                }//end stage
            }//end parallel
            post {
                success {
                    script {
                        currentBuild.displayName = env.NVR
                    }//end script
                }//end always
            }//end post
        }//end parallel stage
        
        stage("Update virtio-win.iso(virtio-win-prewhql.iso) to NFS server.") {
            steps {
                script {
                    brewNvr = env.NVR
                    brewTag = env.BREW_TAG
                    logging.info("The new brew package is ${brewNvr} and update iso to NFS.")
                    if (brewNvr =~ /virtio-win-prewhql/) {
                        verNum = brewNvr.split('-')[4]
                        isoCmd = "${env.WORKSPACE}/kvmqe-ci/jobs/virtio-win-acceptance/scripts/prewhql_iso_create.sh -u -w ${verNum}"
                    } else if (brewNvr =~ /virtio-win.*el/) {
                        isoCmd = "${env.WORKSPACE}/kvmqe-ci/jobs/virtio-win-acceptance/scripts/virtio-win/update_virtio_win.py ${brewTag}"
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

        stage("Generate the list of downstream jobs") {
            steps {
                script {
                    logging.info("Parse variables values from Yaml")
                    env.PKG_NAME = pipelineUtils.pkgNameFromNVR(env.NVR)
                    pipelineUtils.getTargetStream()
                    confs = readYaml file: env.YAML_CONFIG
                    if (!confs.get('builds').containsKey(env.PKG_NAME)) {
                        isNotification = false
                        manager.buildAborted()
                        logging.error("Do not support to run tests for ${env.PKG_NAME}")
                    }
                    if (!confs.get('builds').get(env.PKG_NAME).get('target_stream').containsKey(env.TARGET_STREAM)) {
                        isNotification = false
                        manager.buildAborted()
                        logging.error("Do not run tests for ${env.PKG_NAME} on ${env.TARGET_STREAM}")
                    }

                    tasks = confs.get('builds').get(env.PKG_NAME).get('target_stream').get(env.TARGET_STREAM).get('tasks')
                    for (task in tasks.keySet()) {
                        jobsList.add("virt-kvm-${env.PKG_NAME}-${env.TARGET_STREAM}-${task}")
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
                                string(name: 'NVR', value: "${env.NVR}"),
                                string(name: 'TARGET_RELEASE', value: "${env.TARGET_RELEASE}")],
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
                if (isNotification) {
                    utils.emailNotification("Brew build(trigger) - ${env.NVR}")
                }
            }//end script
        }//end always
    }//end post
}//end pipeline
