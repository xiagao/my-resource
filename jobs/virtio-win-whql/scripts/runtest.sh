#!/bin/bash
. $WORKSPACE/kvmqe-ci/lib/common.sh

# Get testing options

# Get staf cmd (python cmd to boot up guest)
VIRTIO_WIN_PREWHQL_VERSION=$VIRTIO_WIN_PREWHQL_VERSION
DRIVER_NAME=$DRIVER_NAME
OTHERS=$OTHERS
CMD_BASE1="{cmd_base1}"
CMD_BASE2="{cmd_base2}"
if [[ $CMD_BASE2 == "None" ]]; then
    STAF_CMD="$CMD_BASE1 -v $VIRTIO_WIN_PREWHQL_VERSION -n $DRIVER_NAME $OTHERS"
else
    STAF_CMD="$CMD_BASE1 -v $VIRTIO_WIN_PREWHQL_VERSION -n $DRIVER_NAME $OTHERS ; $CMD_BASE2 -v $VIRTIO_WIN_PREWHQL_VERSION -n $DRIVER_NAME $OTHERS"
fi

HARDWARE="{hardware}"
ARCH="${{HARDWARE%%-*}}"
COMPOSE_ID="$COMPOSE_ID"
HOST_REQS="{host_reqs}"
KS_FILE="{ks_file}"
XML_FILE="{xml_file}"
QEMU_REQ="$QEMU_BREW_NVR"
RESERVE_TIME="{reserve_time}"
GUESTNAME="{windows_group}"
WHITEBOARD="whql testing - virtio-win-prewhql-$VIRTIO_WIN_PREWHQL_VERSION - $DRIVER_NAME - $GUESTNAME"
JOB_OWNER="{job_owner}"
if [[ "$COMPOSE_ID" == RHEL-7.4* ]]; then
    REPO_URLS=$(sed -n "/^STATIC_REPO_URLS=/{{s/\(;\|$\)/\/\$basearch&/g;p}}" \
        $WORKSPACE/static-repo.properties | cut -d'=' -f2)
else
    REPO_URLS=$(sed -n "/^STATIC_REPO_URLS=/{{s/\(;\|$\)/\/$ARCH&/g;p}}" \
        $WORKSPACE/static-repo.properties | cut -d'=' -f2)
fi
JOB_XML_PATH="$WORKSPACE/beaker-job.xml"

_log_info "[Job infomation]"
_log_info "virtio win info:\t\t$BREW_NVR $BREW_TAG"
_log_info "qemu info:\t\t$QEMU_BREW_NVR $QEMU_BREW_TAG"
_log_info "compose id:\t\t$COMPOSE_ID"
_log_info "host type:\t\t$HARDWARE"
_log_info "staf command:\t\t$STAF_CMD"
_log_info "reserve time:\t\t${{RESERVE_TIME}}h"

# Generate job xml
GEN_CMD="$WORKSPACE/kvmqe-ci/utils/jobgen/jobgen"
GEN_CMD="$GEN_CMD --arch='$ARCH'"
GEN_CMD="$GEN_CMD --compose='$COMPOSE_ID'"
GEN_CMD="$GEN_CMD --qemu-req='$QEMU_REQ'"
GEN_CMD="$GEN_CMD --staf-cmd='$STAF_CMD'"
GEN_CMD="$GEN_CMD --out-file='$JOB_XML_PATH'"
GEN_CMD="$GEN_CMD --whiteboard='$WHITEBOARD'"
[ -z "$REPO_URLS" ] || GEN_CMD="$GEN_CMD --repos='$REPO_URLS'"
[ "$RESERVE_TIME" -eq 0 ] || GEN_CMD="$GEN_CMD --reserve-time='$RESERVE_TIME'"
[ -z "$HOST_REQS" ] || GEN_CMD="$GEN_CMD --host-requires='$HOST_REQS'"
[ -z "$KS_FILE" ] || GEN_CMD="$GEN_CMD --ks-file='$KS_FILE'"
[ -z "$XML_FILE" ] || GEN_CMD="$GEN_CMD --xml-file='$XML_FILE'"
eval $GEN_CMD
_exit_on_error "Failed to generate beaker job xml file"

# Submit job to beaker
$WORKSPACE/kvmqe-ci/utils/run_bkr_job.sh --timeout $RESERVE_TIME --owner $JOB_OWNER  $JOB_XML_PATH
_exit_on_error "Issue happened during job running"

