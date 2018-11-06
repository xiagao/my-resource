#!/bin/bash
. $WORKSPACE/kvmqe-ci/lib/common.sh
PROFILE="$WORKSPACE/static-repo.properties"
TOP_URL="http://download.devel.redhat.com/rel-eng/repos"

touch $PROFILE
REPO_URL=$(grep "^STATIC_REPO_URLS_$DEPEND_TAG=" $PROFILE | cut -d'=' -f2)
if [ -z "$REPO_URL" ]; then
    _log_info "Try to get the latest yum repo of tag '$DEPEND_TAG'"
    REPO_URL="$TOP_URL/$DEPEND_TAG"
    curl -skL "$REPO_URL" | grep "404 Not Found" -q
    if [ $? -eq 0 ]; then
        REPO_URL=""
        _log_warn "Tag '$DEPEND_TAG' is too new to have a yum repo"
    fi
fi

echo $DEPEND_TAG | grep -iq -- '-z'
if [ $? -ne 0 ]; then
    if [ -z "$REPO_URL" ]; then
        # Default value of "STATIC_REPO_URLS" is "null", need to clear it.
        echo > $PROFILE
    else
        sed -i "s'\(STATIC_REPO_URLS=\).*'\1$REPO_URL'" $PROFILE
    fi
    exit 0
fi

# Append the latest y stream repo for z stream
DEPEND_Z_TAG="${{DEPEND_TAG/-[Zz]/}}"
REPO_Y_URL="$TOP_URL/$DEPEND_Z_TAG"
curl -skL "$REPO_Y_URL" | grep "404 Not Found" -q
if [ $? -eq 0 ]; then
    _log_warn "Yum repo for tag '$DEPEND_Z_TAG' doesn't exist or can't be accessed"
else
    if [ -z "$REPO_URL" ]; then
        REPO_URL="$REPO_Y_URL"
    else
        REPO_URL="$REPO_URL;$REPO_Y_URL"
        sed -i "1i STATIC_REPO_URLS_$DEPEND_Z_TAG=$REPO_Y_URL" $PROFILE
    fi
fi
[ -z "$REPO_URL" ] || sed -i "s'\(STATIC_REPO_URLS=\).*'\1$REPO_URL'" $PROFILE
