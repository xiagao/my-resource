#!/bin/bash
. $WORKSPACE/kvmqe-ci/lib/common.sh

# Get job result
_log_info "Getting Junit result from $BEAKER_JOB_ID"
bkr job-logs $BEAKER_JOB_ID --hub=$HUB_URL | grep "Result.xml"
if [ $? -ne 0 ]; then
    _log_error "Failed to get Xunit file from $BEAKER_JOB_ID"
    exit 0
fi
wget $(bkr job-logs $BEAKER_JOB_ID --hub=$HUB_URL | grep "Result.xml") --no-check-certificate
