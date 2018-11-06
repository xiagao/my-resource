#!/bin/bash
_BASE_DIR="$(cd $(dirname $0) && pwd)"
. $_BASE_DIR/../lib/common.sh

_WORKSPACE=${WORKSPACE:-.}
_HUB_URL="https://beaker.engineering.redhat.com"
_PROFILE="$_WORKSPACE/beaker-job.properties"

_WATCH=true
_JOB_OWNER=
_TIME_OUT=24
while [ $# -gt 0 ]; do
    case $1 in
        --not-watch)
            _WATCH=false
            ;;
        --owner)
            shift
            _JOB_OWNER=$1
            ;;
        -o|--outfile)
            shift
            _PROFILE=$1
            ;;
        --timeout)
            shift
            _TIME_OUT=$1
            ;;
        *)
            _XML_PATH_LIST=(${_XML_PATH_LIST[@]} $1)
            ;;
    esac
    shift
done

rpm -q "beaker-client" >/dev/null 2>&1
_exit_on_error "Package 'beaker-client' is not installed"

# Fix for bz#1313580
_support_multi_instance()
{
    bkr --version | grep -oE '[0-9]+\.[0-9]+' | awk -F'.' '{
        if ($1 < 22) { exit(1); }
        if ($2 < 3)  { exit(1); }
        exit(0); }'
    return $?
}
if ! _support_multi_instance; then
    # Workaround for the above issue
    export KRB5CCNAME=$(mktemp /tmp/krb5cc_XXXXXXXX)
fi

for _XML_PATH in ${_XML_PATH_LIST[@]}; do
    [ -f "$_XML_PATH" ]
    _exit_on_error "Job xml file '$_XML_PATH' is not existed"
done

# Submit job(s)
_ARGS=("--hub=$_HUB_URL")
if [ -n "$_JOB_OWNER" ]; then
    _ARGS=(${_ARGS[@]} "--job-owner=$_JOB_OWNER")
fi
if [ "${#_XML_PATH_LIST[@]}" -gt 1 ]; then
    _ARGS=(${_ARGS[@]} "--combine")
fi
_OUT_MSG="$(bkr job-submit ${_ARGS[@]} ${_XML_PATH_LIST[@]} 2>&1)"
_exit_on_error "Failed to submit beaker job, bkr output:\n$_OUT_MSG"

_JOB_ID=$(echo $_OUT_MSG | grep -o -E "J:[0-9]+")
_JOB_LINK="$_HUB_URL/jobs/${_JOB_ID#*:}"
_log_info "$_JOB_ID is successfully submitted ($_JOB_LINK)"
cat >$_PROFILE <<EOF
BEAKER_JOB_ID=$_JOB_ID
BEAKER_JOB_LINK=$_JOB_LINK
EOF

$_WATCH || exit 0
RESULT=$(bkr job-results --hub=$_HUB_URL $_JOB_ID)
BEAKER_TASK_ID=$(echo $RESULT | grep -oP '(?<=<task name="/virt/Durations/autotest-upstream").*(?=<param name="PYTHON_CMD")' | grep -oP '(?<=id=").*(?=" result)')
START=`date +%s`
_log_info "Waiting for task $BEAKER_TASK_ID to finish"
while [ $(( $(date +%s) - $((${_TIME_OUT}*3600)) )) -lt $START ]; do
    exec 3>&1
    OUT_MSG=$(stdbuf -oL bkr job-watch "T:$BEAKER_TASK_ID" 2>&1 1>&3)
    exec 3>&-
    if [[ ! $OUT_MSG =~ "Traceback (most recent call last):" ]]; then
        break
    fi
    sleep 3600
done
exit 0
