#!/bin/bash
. $WORKSPACE/kvmqe-ci/lib/common.sh

MAPPING_TABLE_DIR=`eval echo ~$USER/mappingtable`
LATEST_MAPPING_TABLE="$WORKSPACE/MappingTable.xlsx"

$WORKSPACE/kvmqe-ci/utils/feature-mapping/DownloadDoc \
    download \
    --file-id "141xADsEk4c54x6ICfgIsuVxPuQS1_YGOoxe97vQ9XL0" \
    --mime-type "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
_exit_on_error "Failed to download mapping table"

if [ ! -s $LATEST_MAPPING_TABLE ]; then
    _exit_on_error "Failed to downlaod google sheet"
fi

[ -d $MAPPING_TABLE_DIR ] || mkdir -p $MAPPING_TABLE_DIR
cp -f $LATEST_MAPPING_TABLE $MAPPING_TABLE_DIR
_exit_on_error "Failed to copy mapping table"
