#!/usr/bin/env groovy

def getJunitResult() {
    logging.info("Getting Junit result from ${env.JOB_ID}")
    try {
        JunitResultUrl = sh(returnStdout: true, script: "bkr job-logs ${env.JOB_ID} --hub=${env.HUB_URL} | grep \"Result.xml\"").trim()
        sh(returnStatus: true, script: "wget ${JunitResultUrl}")
    } catch (Exception ex) {
        logging.warn("Failed to get Junit result, error message:\n${ex}")
    }
    return true
}

@NonCPS
def getJobId(String text) {
    def matcher = text =~ /(J:\d*)/
    matcher ? matcher[0][1] : null
}

@NonCPS
def getTaskId(String text) {
    def matcher = text =~ /autotest-upstream.*id="(\d*)".*tmp-virt-Durations-autotest-upstream/
    matcher ? matcher[0][1] : null
}

def RunBeakerJob(String jobOwner, Boolean watchJob = true, String xmlFile, String text="") {
    def out = ''
    if (sh(returnStatus: true, script: "command -v bkr") != 0 ) {
        logging.error("Package 'beaker-client' is not installed")
    }
    def cmd = "bkr job-submit"
    if (jobOwner) {
        cmd = "${cmd} --job-owner=${jobOwner}"
    }
    cmd = "${cmd} --hub=${env.HUB_URL} ${xmlFile}"
    try {
        out = sh(returnStdout: true, script: "${cmd}").trim()
        env.JOB_ID = getJobId(out)
        env.JOB_LINK = "${env.HUB_URL}/jobs/${env.JOB_ID.split(':')[1]}"
    } catch (Exception ex) {
        logging.error("Failed to submit beaker job, error message:\n${ex}")
    }
    if (!env.JOB_ID) {
        logging.error("Failed to get beaker job id")
    }
    logging.info("${env.JOB_ID} is successfully submitted (${env.JOB_LINK})")
    if (!watchJob) {
        return
    }
    cmd = "bkr job-results --hub=${env.HUB_URL} ${env.JOB_ID}"
    try {
        out = sh(returnStdout: true, script: "${cmd}").trim()
        env.TASK_ID = getTaskId(out)
    } catch (Exception ex) {
        logging.warn("Failed to get beaker task 'autotest-upstream', error message:\n${ex}")
    }
    if (!env.TASK_ID) {
        logging.warn("Failed to get beaker task id")
        return
    }
    if (text) {
        utils.emailNotificationBeforeStartTest(text)
    }
    retry(10) {
        try {
            out = sh(returnStdout: true, script: "bkr job-watch T:${env.TASK_ID}")
        } catch (Exception ex) {
            if (out.contains("Traceback (most recent call last):")) {
                logging.error("Failed to monitor task(${env.TASK_ID}, error message:\n${ex})")
            }
        }
    }
}
