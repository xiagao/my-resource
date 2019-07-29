#!/usr/bin/env groovy

@Library('kvmqe-ci') _

def jSlaveLabel = "jslave-virt-kvm-whql"
def prefix = 'virtkvm'
def jobsList = []
def isNotification = false
def buildRelease = ['virtio-win': 'rhel-\\d+\\.\\d+(\\.\\d+)-candidate',
                    'virtio-win-prewhql': 'rhevm-.*-candidate']

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
        GERRIT_URL = 'https://github.com/xiagao/my-resource'
        YAML_CONFIG = 'my-resource/virtio-win-acceptance/config/virtio_win_config.yml'
        ARTIFACT = 'brew-build'
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

        stage("Generate the list of downstream jobs") {
            steps {
                script {
                	try {
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
                	} catch (e) {
                		logging.info("xxxxxxxxxxx\n${e}")
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
