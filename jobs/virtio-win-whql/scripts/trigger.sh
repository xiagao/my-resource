#!/bin/bash
. $WORKSPACE/kvmqe-ci/lib/common.sh
OUT_PROFILE="$WORKSPACE/build-params.properties"

# Triggered manully
! [ -z "$VIRTIO_WIN_PREWHQL_VERSION" ]
_exit_on_error "Parameter 'VIRTIO_WIN_PREWHQL_VERSION' is empty, please provide one"
! [ -z "$DRIVER_NAME" ]
_exit_on_error "Parameter 'DRIVER_NAME' is empty, please provide one"
! [ -z "$OTHERS" ]
_exit_on_error "Parameter 'OTHERS' is empty, please provide one"

# Get the downstream job's name
w_list="{windows_group}"
_log_info "w_list:\t\t$w_list"
i=2
_WG="winguest"
while [ "$_WG" != "" ]; do
    _WG=$(echo $w_list | awk -F \' '{{print $v}}' v=$i)
    if [ "$_WG" == "" ]; then
        break
    fi
    _JOB="whql-$_WG-runtest"
    _JOBS=(${{_JOBS[@]}} $_JOB)
    let "i += 2"
done

[ ${{#_JOBS[@]}} -gt 0 ]
_exit_on_error "No downstream job to be triggered"
DOWNSTREAM_JOBS=${{_JOBS[*]}}
_log_info "DOWNSTREAM_JOBS:\t\t$DOWNSTREAM_JOBS"

#get the coresponding qemu-kvm-rhev tag
COMPOSE_PREFIX="{compose_prefix}"
X_Y="{rhel_product}"
QEMU_BREW_TAG="rhevh-rhel-$X_Y-candidate"
#get the latest build NVR of qemu-kvm-rhev
QEMU_BREW_NVR=$(brew latest-build $QEMU_BREW_TAG qemu-kvm-rhev | awk 'END {{print $1}}')
DEPEND_TAG=$(python $WORKSPACE/kvmqe-ci/utils/jobgen/tag-helper.py \
    -t $QEMU_BREW_TAG -n $QEMU_BREW_NVR $COMPOSE_PREFIX)
_exit_on_error "Failed to get the tag list of QEMU's dependencies"
COMPOSE_ID=$(bash $WORKSPACE/kvmqe-ci/utils/jobgen/distro-helper.sh \
   --distro-version $X_Y \
   --labcontroller "lab-01.rhts.eng.pek2.redhat.com" \
   --distro-prefix $COMPOSE_PREFIX \
   --enable-nightly)
_exit_on_error "Failed to get latest compose id"

cat >$OUT_PROFILE <<EOF
VIRTIO_WIN_PREWHQL_VERSION=$VIRTIO_WIN_PREWHQL_VERSION
DRIVER_NAME=$DRIVER_NAME
OTHERS=$OTHERS
QEMU_BREW_TAG=$QEMU_BREW_TAG
QEMU_BREW_NVR=$QEMU_BREW_NVR
DEPEND_TAG=$DEPEND_TAG
COMPOSE_ID=$COMPOSE_ID
DOWNSTREAM_JOBS=${{DOWNSTREAM_JOBS// /,}}
EOF
