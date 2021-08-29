#!/bin/bash
. $WORKSPACE/kvmqe-ci/lib/common.sh

# Get job result
_log_info "Getting Junit result from $BEAKER_JOB_ID"
wget $(bkr job-logs $BEAKER_JOB_ID --hub=$HUB_URL | grep "{junit_xml}")
