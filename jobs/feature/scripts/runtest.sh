#!/bin/bash
. $WORKSPACE/kvmqe-ci/lib/common.sh

JOB_PREFIX="$WORKSPACE/beaker-job"
MAP_OUTPUT_FILE="$WORKSPACE/job-mapping.csv"
FEATURE_INFO_FILE="$WORKSPACE/feature-info.csv"
BEAKER_JOB_FILE="$WORKSPACE/beaker-job.properties"
FEATURE_PROFILE="$WORKSPACE/feature.properties"
JIRA_DESCRIPTION_PROFILE="$WORKSPACE/jira-description.properties"
#POLARION_TESTRUN_PROFILE="$WORKSPACE/polarion.properties"
HUB_URL="https://beaker.engineering.redhat.com"
BKS_DEFAULT="$WORKSPACE/kvmqe-ci/utils/beaker-workflow/bks-defaults"

JOB_CMD=$(awk -F"\t" 'NR=='$COUNT' {{print $1}}' $MAP_OUTPUT_FILE)
RELATED_FILES=$(awk -F"\t" 'NR=='$COUNT' {{print $2}}' $MAP_OUTPUT_FILE)

$WORKSPACE/kvmqe-ci/utils/feature-mapping/GetFeatureInfo \
    --task-cmd "$JOB_CMD" \
    --out-file "$FEATURE_INFO_FILE"
FEATURE_OWNER=$(awk -F"\t" '{{print $1}}' $FEATURE_INFO_FILE)
FEATURE=$(awk -F"\t" '{{print $2}}' $FEATURE_INFO_FILE)
EXTRA_HOST_REQ=$(echo $(awk -F"\t" '{{print $3}}' $FEATURE_INFO_FILE) | sed $'s/\\r//')

for i in $JOB_CMD
do
    [[ $i =~ "=" ]] && i=${{i:2}} && DESCRIPTION+="[${{i%=*}}: ${{i#*=}}] "
    [[ $i =~ "category" ]] && CATEGORY=${{i##*=}}
    [[ $i =~ "platform" ]] && ARCH=${{i##*=}}
done
if [[ $ARCH =~ "ppc" ]]; then
    ARCH="ppc64le"
    JIRA_PROJECT_KEY="ELPPCKVM"
    JIRA_PARENT_KEY="ELPPCKVM-386"
    MAINTAINERS="yhong@redhat.com"
    LOG_URL="http://10.8.242.200"
elif [[ $ARCH =~ "x86" ]]; then
    JIRA_PROJECT_KEY="KVMAUTO"
    JIRA_PARENT_KEY="KVMAUTO-499"
    MAINTAINERS="pingl@redhat.com"
    LOG_URL="http://fileshare.englab.nay.redhat.com/pub/logs"
fi
cat >$FEATURE_PROFILE <<EOF
ARCH=$ARCH
FEATURE=$FEATURE
MAIL_RECIPIENTS=$FEATURE_OWNER, $MAINTAINERS
EOF

[[ "$COMPOSE_ID" =~ RHEL-?([0-9]+\.[0-9]+) ]]

if [[ "$COMPOSE_ID" == RHEL-7.4* ]]; then
    REPO_URLS=$(echo $STATIC_REPO_URLS | sed "{{s/\(;\|$\)/\/\$basearch&/g}}")
else
    REPO_URLS=$(echo $STATIC_REPO_URLS | sed "{{s/\(;\|$\)/\/$ARCH&/g}}")
fi

pushd . >&/dev/null
cd $WORKSPACE/kvmqe-ci/utils/beaker-workflow
JOB_PROFILE="{osversion}.$ARCH"
DEFAULT_HOST_REQ=$(sed -nr "/^\[\S*$JOB_PROFILE\]/ {{ :l /^host-filters[ ]*:/ {{ s/.*:[ ]*//; p; q;}}; n; b l;}}" $BKS_DEFAULT)
if [ -n "$EXTRA_HOST_REQ" ]; then
    HOST_REQ="$DEFAULT_HOST_REQ,$EXTRA_HOST_REQ"
else
    HOST_REQ=$DEFAULT_HOST_REQ
fi
bkr workflow-xslt --dry-run \
    --profile "$JOB_PROFILE" \
    --distro "$COMPOSE_ID" \
    --repos "${{REPO_URLS//;/,}}" \
    --qemu-ver "$BREW_NVR" \
    --task-cmd "$JOB_CMD" \
    --reserve-time '{reserve_time}' \
    --host-filters $HOST_REQ \
    --whiteboard \
        "Feature testing ($BREW_NVR, $RELATED_FILES)" \
    --save-xml "${{JOB_PREFIX}}.xml"
_exit_on_error "Failed to generate beaker job xml file"
popd >&/dev/null

JOB_OWNER=$(echo $FEATURE_OWNER | awk -F"," '{{print $1}}' | sed $'s/@redhat.com//')
$WORKSPACE/kvmqe-ci/utils/run_bkr_job.sh \
    --owner $JOB_OWNER \
    --not-watch \
    "${{JOB_PREFIX}}.xml"
_exit_on_error "Error occured during submitting job"

BEAKER_JOB_LINK=$(sed -n "/^BEAKER_JOB_LINK=/{{p}}" \
    $BEAKER_JOB_FILE | cut -d'=' -f 2)
BEAKER_JOB_ID=$(sed -n "/^BEAKER_JOB_ID=/{{p}}" \
    $BEAKER_JOB_FILE | cut -d'=' -f 2)
#python $WORKSPACE/kvmqe-ci/jobs/feature/scripts/polarion.py \
#    "$ARCH" "{component}" "$BREW_NVR" "$BREW_TAG" "$FEATURE" "$DESCRIPTION"
#if [ -s $POLARION_TESTRUN_PROFILE ]; then
#    TESTRUN_LINK=$(sed -n "/^TESTRUN_LINK=/{{p}}" \
#        $POLARION_TESTRUN_PROFILE | cut -d'=' -f 2,3)
#else
#    TESTRUN_LINK="Failed to create test run"
#fi
cat >$JIRA_DESCRIPTION_PROFILE <<EOF
Beaker Job: $BEAKER_JOB_LINK
EOF
JIRA_RESULT=`$WORKSPACE/kvmqe-ci/utils/feature-mapping/JiraClient \
    create_issue \
    --description-file "$JIRA_DESCRIPTION_PROFILE" \
    --summary "$BREW_NVR feature test - $FEATURE" \
    --workers "$FEATURE_OWNER" \
    --project-key "$JIRA_PROJECT_KEY" \
    --parent-key "$JIRA_PARENT_KEY"`
echo $JIRA_RESULT
JIRA_ISSUE_KEY=$(echo $JIRA_RESULT | awk -F":" '{{print $2}}' | tr -d " \t\n\r")

RESULT=$(bkr job-results --hub=$HUB_URL $BEAKER_JOB_ID)
BEAKER_TASK_ID=$(echo $RESULT | grep -oP '(?<=<task name="/virt/Durations/autotest-upstream").*(?=<param name="PYTHON_CMD")' | grep -oP '(?<=id=").*(?=" result)')
START=`date +%s`
_log_info "Waiting for task $BEAKER_TASK_ID to finish"
while [ $(( $(date +%s) - $(({reserve_time}*3600)) )) -lt $START ]; do
    exec 3>&1
    OUT_MSG=$(stdbuf -oL bkr job-watch "T:$BEAKER_TASK_ID" 2>&1 1>&3)
    exec 3>&-
    if [[ ! $OUT_MSG =~ "Traceback (most recent call last):" ]]; then
        break
    fi
    sleep 3600
done
TEST_RESULT_LINK="$LOG_URL/$(echo $BEAKER_JOB_ID | cut -d':' -f2)/results.html"
curl --fail $TEST_RESULT_LINK &> /dev/null
if [ $? -eq 0 ]; then
    $WORKSPACE/kvmqe-ci/utils/feature-mapping/JiraClient \
        add_comment \
        --issue-key $JIRA_ISSUE_KEY \
        --comment "Test Result: $TEST_RESULT_LINK"
fi
exit 0
