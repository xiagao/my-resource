#!/bin/bash

bkr_distro_trees_list()
{
    param="--family=${distro[$distro_prefix]##*,}$1 --name=$2 --tag=$3"
    if [ -n "$labcontroller" ]; then
        param+=" --labcontroller=$labcontroller"
    fi
    /usr/bin/bkr distro-trees-list \
        $param \
        --hub='https://beaker.engineering.redhat.com/' \
        --limit=1 --format=json \
        2>/dev/null | python -c \
            'import sys,json; print(json.load(sys.stdin)[0]["distro_name"])' \
            2>/dev/null
    return $?
}

find_distro()
{
    local n="${distro[$distro_prefix]%%,*}%${1}.${2}"
    bkr_distro_trees_list "$1" "${n}" "RELEASED" || \
        bkr_distro_trees_list "$1" "${n}-________._" "RTT_ACCEPTED" || \
            ($enable_nightly && \
                bkr_distro_trees_list "$1" "${n}-________._._" "RTT_PASSED")
    return $?
}

command -v 'bkr' >/dev/null || exit 1
declare -A distro
distro=([RHEL]="RHEL,RedHatEnterpriseLinux"
        [RHEL-ALT]="RHEL-ALT,RedHatEnterpriseLinuxAlternateArchitectures")

distro_prefix="RHEL"
labcontroller=
enable_nightly=false
while [ $# -gt 0 ]; do
    case $1 in
        --enable-nightly)
            enable_nightly=true
            ;;
        --distro-version)
            shift
            major="${1%.*}"
            minor="${1#*.}"
            ;;
        --distro-prefix)
            shift
            distro_prefix=$1
            ;;
        --labcontroller)
            shift
            labcontroller=$1
            ;;
#        --host-reqs)
#            shift
#            labcontroller=$(echo $1 | awk -F"hostlabcontroller=" '{print $2}' | cut -f1 -d",")
#            ;;
    esac
    shift
done
find_distro "$major" "$minor" || find_distro "$major" "$((--minor))"
