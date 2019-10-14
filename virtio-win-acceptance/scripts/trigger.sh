#!/bin/bash
. $WORKSPACE/kvmqe-ci/lib/common.sh
OUT_PROFILE="$WORKSPACE/build-params.properties"

if ! [ -z "$CI_MESSAGE" ]; then
    # Triggered by ci message
    BREW_MSG_PROFILE="$WORKSPACE/brew-tag-msg.properties"

    python $WORKSPACE/kvmqe-ci/utils/brew_tag_msg_parse.py
    _exit_on_error "Failed to get brew tag message propertie"

    . $BREW_MSG_PROFILE

    w_list="{windows_group}"
    i=2
    _WG="winguest"
    while [ "$_WG" != "" ]; do
        _WG=$(echo $w_list | awk -F \' '{{print $v}}' v=$i)
        if [ "$_WG" == "" ]; then
            break
        fi
        _JOB="{component}-{osversion}-$_WG-runtest"
        _JOBS=(${{_JOBS[@]}} $_JOB)
        let "i=i+2"
    done

else
    # Triggered manully
    ! [ -z "$BREW_NVR" ]
    _exit_on_error "Parameter 'BREW_NVR' is empty, please provide one"
    ! [ -z "$BREW_TAG" ]
    _exit_on_error "Parameter 'BREW_TAG' is empty, please provide one"

    w_list="{windows_group}"
    i=2
    _WG="winguest"
    while [ "$_WG" != "" ]; do
        _WG=$(echo $w_list | awk -F \' '{{print $v}}' v=$i)
        if [ "$_WG" == "" ]; then
            break
        fi
        _JOB="{component}-{osversion}-$_WG-runtest"
        _JOBS=(${{_JOBS[@]}} $_JOB)
        let "i += 2"
    done

fi

#check the brew pkg is virtio-win or virtio-win-prewhql
if [ `echo $BREW_NVR | grep -e virtio-win-prewhql` ]; then
    echo "=============$BREW_NVR============"
    VERNUM=$(echo $BREW_NVR |awk -F- '{{print $5}}')
    $WORKSPACE/kvmqe-ci/jobs/virtio-win-acceptance/scripts/prewhql_iso_create.sh -u -w $VERNUM
    _exit_on_error "Failed to update prewhql iso image"
elif [ `echo $BREW_NVR | grep -e virtio-win.*el` ]; then
    echo "=============$BREW_NVR============"
    python $WORKSPACE/kvmqe-ci/jobs/virtio-win-acceptance/scripts/virtio-win/update_virtio_win.py
    _exit_on_error "Failed to update virtio-win iso image"
    #cd $WORKSPACE/kvmqe-ci/jobs/virtio-win-acceptance/scripts/virtio-win-mapping-check
    #sh acceptance.sh
    #cd $WORKSPACE
    #_exit_on_error "Failed to update virtio-win iso image"
else
    _exit_on_error "Failed to get brew pkg version propertie"
fi


[ ${{#_JOBS[@]}} -gt 0 ]
_exit_on_error "No downstream job to be triggered"
DOWNSTREAM_JOBS=${{_JOBS[*]}}
COMPOSE_PREFIX="{compose_prefix}"
#get the coresponding qemu-kvm-rhev tag
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
QEMU_BREW_TAG=$QEMU_BREW_TAG
QEMU_BREW_NVR=$QEMU_BREW_NVR
BREW_NVR=$BREW_NVR
BREW_TAG=$BREW_TAG
DEPEND_TAG=$DEPEND_TAG
COMPOSE_ID=$COMPOSE_ID
DOWNSTREAM_JOBS=${{DOWNSTREAM_JOBS// /,}}
EOF
