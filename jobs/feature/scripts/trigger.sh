#!/bin/bash
. $WORKSPACE/kvmqe-ci/lib/common.sh

QEMU_PKG_REPO="$WORKSPACE/qemu-pkg-src"
MAP_INPUT_FILE="$WORKSPACE/changed-files.txt"
MAP_OUTPUT_FILE="$WORKSPACE/job-mapping.csv"
REQ_MAPPING_FILE="$WORKSPACE/request-mapping.txt"
JOBS_INFO_FILE="$WORKSPACE/job_mapping.properties"

[[ "$COMPOSE_ID" =~ RHEL-?([0-9]+\.[0-9]+) ]]
COMPOSE_VERSION="${{BASH_REMATCH[1]}}"
[ -n "$COMPOSE_VERSION" ]
_exit_on_error "Failed to get compose version from compose id"

STATIC_REPO_URLS=$(sed -n "/^STATIC_REPO_URLS=/{{p}}" \
    $WORKSPACE/static-repo.properties | cut -d'=' -f2)

BREW_TASKID=$(brew buildinfo $BREW_NVR | awk -F' ' '$1 ~ /Task:/ {{print $2}}')
[ -n "$BREW_TASKID" ]
_exit_on_error "Failed to get brew task id"

QEMU_PKG_REPO_URL=$(brew taskinfo -v $BREW_TASKID | grep -oE "git://.*")
git clone $(cut -d' ' -f1 <<<"${{QEMU_PKG_REPO_URL/?#/ }}") $QEMU_PKG_REPO
pushd . >&/dev/null
cd $QEMU_PKG_REPO
git checkout -q $(cut -d' ' -f2 <<<"${{QEMU_PKG_REPO_URL/?#/ }}")
lsdiff -sh --strip=1 $(git diff --name-only HEAD~ HEAD | grep '.*\.patch$') | \
    sort -u | sed -n \
        -e "/^[+-]/w $REQ_MAPPING_FILE" \
        -e "s/^\!\s*//gw $MAP_INPUT_FILE"
popd >&/dev/null

if [ -s "$REQ_MAPPING_FILE" ]; then
    $WORKSPACE/kvmqe-ci/utils/feature-mapping/JiraClient \
        create_issue \
        --description-file "$REQ_MAPPING_FILE" \
        --summary "$BREW_NVR requests new feature mapping" \
        --workers '{jira_assignee}' \
        --project-key 'ELPPCKVM' \
        --parent-key 'ELPPCKVM-349'
fi

ARCH_LIST="aarch64 ppc64le x86_64"
for ARCH in $ARCH_LIST
do
    if [[ $ARCH =~ "ppc" ]]; then
        guest_platform="ppc64le,ppc64"
    else
        guest_platform=$ARCH
    fi

    $WORKSPACE/kvmqe-ci/utils/feature-mapping/ResolveMapping \
        --arch "$ARCH" \
        --default-params \
            "guestname=RHEL.$COMPOSE_VERSION" \
            "platform=$guest_platform" \
            'nicmodel=virtio_net' \
            'driveformat=virtio_blk' \
            'imageformat=qcow2' \
            'image_backend=filesystem' \
            'mem=8192' \
            'vcpu=4' \
        --file "$MAP_INPUT_FILE" \
        --out-file "$MAP_OUTPUT_FILE"
done
_JOB_NUM=`cat $MAP_OUTPUT_FILE | wc -l`
[ $_JOB_NUM -gt 0 ]
_exit_on_error "No feature tests to be triggered"

cat >$JOBS_INFO_FILE <<EOF
JOB_NUM=$_JOB_NUM
STATIC_REPO_URLS=$STATIC_REPO_URLS
EOF
