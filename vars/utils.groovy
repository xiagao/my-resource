#!/usr/bin/env groovy

def emailNotificationBeforeStartTest(String text) {
    def subject = "${text} - Building"
    def body = "Job name: ${env.JOB_NAME}\nBuild number: ${env.BUILD_NUMBER}\nJob log: ${env.BUILD_URL}console\nBEAKER_JOB_ID: ${env.JOB_ID}\nBEAKER_JOB_LINK: ${env.JOB_LINK}"
    def email_to="${env.EMAIL_RECIPIENTS}"
    if (email_to?.trim()) {
        // Validate the list of emails.
        try {
            def addr = new javax.mail.internet.InternetAddress()
            addr.parse(email_to)
        } catch(javax.mail.internet.AddressException e) {
            println "Given invalid list of emails"
            body += "\n\nWARNING: invalid email addresses: ${email_to}\n"
            email_to=""
        }
    }

    /* Always send email to the job submitter. But if EMAIL_RECIPIENTS is not empty
    * then append the addresses to the recipients list.
    */
    emailext (
    subject: subject,
    body: body,
    recipientProviders: [[$class: 'RequesterRecipientProvider']],
    to: email_to
    )
}

def emailNotification(String text) {
    def subject = "${text} - ${currentBuild.currentResult}"
    def body = "Job name: ${env.JOB_NAME}\nBuild number: ${env.BUILD_NUMBER}\nTest result: ${currentBuild.currentResult}\nJob log: ${env.BUILD_URL}console"
    if (env.JOB_ID) {
        body += "\nBEAKER_JOB_ID: ${env.JOB_ID}\nBEAKER_JOB_LINK: ${env.JOB_LINK}"
    }
    def email_to="${env.EMAIL_RECIPIENTS}"
    if (email_to?.trim()) {
        // Validate the list of emails.
        try {
            def addr = new javax.mail.internet.InternetAddress()
            addr.parse(email_to)
        } catch(javax.mail.internet.AddressException e) {
            println "Given invalid list of emails"
            body += "\n\nWARNING: invalid email addresses: ${email_to}\n"
            email_to=""
        }
    }

    /* Always send email to the job submitter. But if EMAIL_RECIPIENTS is not empty
    * then append the addresses to the recipients list.
    */
    emailext (
    subject: subject,
    body: body,
    recipientProviders: [[$class: 'RequesterRecipientProvider']],
    to: email_to
    )
}
