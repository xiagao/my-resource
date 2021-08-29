#!/bin/bash
#############################################################################
# This script is used to create virtio-win-prewhql iso
# before start the script you should
# 1. config the version of the virtio-win using: -w xx -q xx
# 2. check the default url is correct.
# 3. check the drvier path in the Associative Arrays.
# 4. using root to run this script
# the iso will put in you $ROOT_PATH
#############################################################################
#set -x

SEND_MAIL=yes
MAINTAINER_MAIL="xiagao@redhat.com"
NOTIFY_MAIL_LIST="xiagao@redhat.com"

usage()
{
    cat << EOF
    command [option]
    option:
    -p : assign the root path like "/root"
    -n : if don't want download, add -n,default is down the package
    -w : set virtio_win_version, like : " -w 55"
    -q : set qxl_version like "-q 17"
    -u : set update nfs, default is put the iso under the root path
    -r : clear the package that download, default is not clear
    -h : help
    example: ./create  -d no   this will not download the package, using it when you have downloaded the package
             ./create  -w 55
             ./create  -w 55 -q 17
EOF
    exit 0
}

ARGS=`getopt -o p:nw:q:urh -- "$@"`
[ $? -ne 0 ] && usage
eval set -- "${ARGS}"
while true
do
    case "$1" in
        -p|--rootpath) P_PATH=$2; shift 2;;
        -n|--download) DOWNLOAD='No'; shift;;
        -w|--virtio_win_version) VIRTIO_WIN_VER=$2; shift 2;;
        -q|--qxl_version) QXL_VERSION=$2; shift 2;;
        -u|--update_nfs) UPDATE_NFS='Yes'; shift ;;
        -r|--remove) REMOVE="Yes"; shift;;
        -h|--help) usage ;;
        --)shift; break ;;
        *) usage;exit 1;;
    esac
done

TMP_DIR=/var/tmp
NFS_MNT=$TMP_DIR/nfs
INFO_FILE=$TMP_DIR/.virtio-win-prewhql-info
URL_ROOT=http://download-node-02.eng.bos.redhat.com/brewroot/packages
VIRTIO_PKG_LINK=$URL_ROOT/virtio-win-prewhql/0.1/
QXL_PKG_LINK=$URL_ROOT/qxl-win/0.1/
QEMU_GA_LINK=$URL_ROOT/mingw-qemu-ga-win/
QEMU_GA_MAIN_VERSION=$(curl -s $QEMU_GA_LINK | sed -n 's/.*<a href="\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p'| sed -n '$p')
QEMU_GA_SUB_VERSION=$(curl -s $QEMU_GA_LINK$QEMU_GA_MAIN_VERSION/ | sed -n 's/.*<a href="\([0-9]\+\.[a-z]\+[0-9]\+\).*/\1/p'| sed -n '$p')

[ -d $TMP_DIR ] || mkdir -p $TMP_DIR

#if specified virtio_win_ver,will do not check the latest version.
if [ "_$VIRTIO_WIN_VER" == "_" ]
then
    # the ROOT_URL has been changed ,need to update or the following commands will not work
    VIRTIO_WIN_VER_LAT=$(curl -s $VIRTIO_PKG_LINK | sed -n 's/.*<a href="\([0-9]\+\).*/\1/p'| sed -n '$p')
    echo "The latest virtio-win-prewhql version is: $VIRTIO_WIN_VER_LAT"
fi

if [ "_$QXL_VERSION" == "_" ]
then
    QXL_VERSION_LAT=$(curl -s $QXL_PKG_LINK | sed -n 's/.*<a href="\([0-9]\+\).*/\1/p'| sed -n '$p')
fi

UPDATE_NFS=${UPDATE_NFS:-'No'}
NEED_WGET=${DOWNLOAD:-'Yes'}
ROOT_PATH=${P_PATH:=$PWD}
SUB_VERSION=${VIRTIO_WIN_VER:=$VIRTIO_WIN_VER_LAT}
QXL_VERSION=${QXL_VERSION:=$QXL_VERSION_LAT}
MAIN_VERSION=0.1
CLEAR_PATH=${REMOVE:="No"}
VIRTIO_WIN_PKG_NAME=virtio-win-prewhql-$MAIN_VERSION-$SUB_VERSION.zip
VIRTIO_WIN_ISO_NAME=virtio-win-prewhql-$MAIN_VERSION-$SUB_VERSION.iso
QEMU_GA_PKG="qemu-ga-win-$QEMU_GA_MAIN_VERSION-${QEMU_GA_SUB_VERSION}.noarch.rpm"

echo "DEBUG: The iso need to be created is: $VIRTIO_WIN_ISO_NAME"

#mount nfs
if [ $UPDATE_NFS == "Yes" ]
then
    [ -d $NFS_MNT ] || mkdir -p $NFS_MNT
    if [ -z $(mount |grep $NFS_MNT) ]
    then
        # mount 10.66.8.115:/home/nfs $NFS_MNT
        mount 10.73.194.27:/vol/s2kvmauto/iso $NFS_MNT
    else
        echo "/var/tmp/nfs is busy or already mounted"
    fi
    DST_PATH=$NFS_MNT/windows
    NEED_UMOUNT="Yes"
else
    DST_PATH=$ROOT_PATH/virtio-win-prewhql
    NEED_UMOUNT="No"
fi

[ -d $DST_PATH ] || mkdir -p $DST_PATH

#judge if the virtio-vin-prewhql iso existed in nfs server.
if [ -f "$DST_PATH/$VIRTIO_WIN_ISO_NAME" ]
then
    echo "$VIRTIO_WIN_ISO_NAME is already in $DST_PATH,no need to create."
    if [ "_$NEED_UMOUNT" == "_Yes" ]
    then
        umount $NFS_MNT
    fi
    exit 0
fi

#http://download-node-02.eng.bos.redhat.com/brewroot/packages/mingw-qemu-ga-win/101.0.0/5.el7ev/noarch/qemu-ga-win-101.0.0-5.el7ev.noarch.rpm
#http://download.eng.pnq.redhat.com/brewroot/packages/virtio-win-prewhql/0.1/125/win/virtio-win-prewhql-0.1.zip
URL_VIRT_WIN_ZIP=$URL_ROOT/virtio-win-prewhql/$MAIN_VERSION/$SUB_VERSION/win/virtio-win-prewhql-$MAIN_VERSION.zip
URL_QXL_W7_X64=$QXL_PKG_LINK/$QXL_VERSION/win/qxl_w7_x64.zip
URL_QXL_W7_X86=$QXL_PKG_LINK/$QXL_VERSION/win/qxl_w7_x86.zip
URL_QXL_2K8R2_X64=$QXL_PKG_LINK/$QXL_VERSION/win/qxl_8k2R2_x64.zip
URL_QEMU_GA_PKG=$QEMU_GA_LINK$QEMU_GA_MAIN_VERSION/$QEMU_GA_SUB_VERSION/noarch/$QEMU_GA_PKG

#create the related dir
if [ ! -e $ROOT_PATH/virt_win_iso_create ]
then
    mkdir -p $ROOT_PATH/virt_win_iso_create/{iso,source,qxl,guest-agent}
fi

ISO_CREATE_ROOT_PATH=$ROOT_PATH/virt_win_iso_create
VIR_WIN_TGT_ISO_PATH=$ISO_CREATE_ROOT_PATH/iso
VIR_WIN_RESOURCE_PATH=$ISO_CREATE_ROOT_PATH/source
VIR_WIN_QXL_RESOURCE_PATH=$ISO_CREATE_ROOT_PATH/qxl
VIR_WIN_QEMU_GA_RESOURCE_PATH=$ISO_CREATE_ROOT_PATH/guest-agent

declare -A ISO_DST_PATH

# Download the packages
if [ "_$NEED_WGET" == "_Yes" ]
then
    echo "DEBUG: Download the files from the url."
    rm -rf $VIR_WIN_RESOURCE_PATH/*
    rm -rf $VIR_WIN_QXL_RESOURCE_PATH/*
    rm -rf $VIR_WIN_TGT_ISO_PATH/*
    rm -rf $VIR_WIN_QEMU_GA_RESOURCE_PATH/*

    set -e
    wget $URL_VIRT_WIN_ZIP  -O $VIR_WIN_RESOURCE_PATH/$VIRTIO_WIN_PKG_NAME  2>&1 >/dev/null
    wget $URL_QXL_W7_X64    -O $VIR_WIN_QXL_RESOURCE_PATH/QXL_W7_X64.zip    2>&1 >/dev/null
    wget $URL_QXL_W7_X86    -O $VIR_WIN_QXL_RESOURCE_PATH/QXL_W7_X86.zip    2>&1 >/dev/null
    wget $URL_QXL_2K8R2_X64 -O $VIR_WIN_QXL_RESOURCE_PATH/QXL_2K8R2_X64.zip 2>&1 >/dev/null

    unzip -d $VIR_WIN_RESOURCE_PATH     $VIR_WIN_RESOURCE_PATH/$VIRTIO_WIN_PKG_NAME  2>&1 >/dev/null
    unzip -d $VIR_WIN_QXL_RESOURCE_PATH $VIR_WIN_QXL_RESOURCE_PATH/QXL_W7_X64.zip    2>&1 >/dev/null
    unzip -d $VIR_WIN_QXL_RESOURCE_PATH $VIR_WIN_QXL_RESOURCE_PATH/QXL_W7_X86.zip    2>&1 >/dev/null
    unzip -d $VIR_WIN_QXL_RESOURCE_PATH $VIR_WIN_QXL_RESOURCE_PATH/QXL_2K8R2_X64.zip 2>&1 >/dev/null

    # get qemu-ga-win msi file
    # qemu-ga-win-102.0.0-2.el8.noarch.rpm
    QEMU_GA_MAIN_VER_RPM=$(rpm -q qemu-ga-win | sed -n 's/.*-\([0-9]\+\.[0-9]\+\.[0-9]\+\)-.*/\1/p')
    QEMU_GA_SUB_VER_RPM=$(rpm -q qemu-ga-win | sed -n 's/.*-\([0-9]\+\.[a-z]\+[0-9]\+\)\..*/\1/p')
    if [ "$QEMU_GA_MAIN_VER_RPM" == "$QEMU_GA_MAIN_VERSION" -a "$QEMU_GA_SUB_VER_RPM" == "$QEMU_GA_SUB_VERSION" ]
    then
        echo "The current qemu-ga-win version is the latest one."
    else
        echo "Update qemu-ga-win."
        wget $URL_QEMU_GA_PKG  2>&1 >/dev/null
        rpm -Uvh $QEMU_GA_PKG  2>&1 >/dev/null
    fi
    cp /usr/x86_64-w64-mingw32/sys-root/mingw/bin/qemu-ga-x86_64.msi $VIR_WIN_QEMU_GA_RESOURCE_PATH/  2>&1 >/dev/null
    cp /usr/i686-w64-mingw32/sys-root/mingw/bin/qemu-ga-i386.msi $VIR_WIN_QEMU_GA_RESOURCE_PATH/  2>&1 >/dev/null

    set +e
else
    rm -rf $VIR_WIN_TGT_ISO_PATH/*

    if [ ! -d $VIR_WIN_RESOURCE_PATH ]
    then
        echo "You must download the source file, not using -n"
        exit 1
    fi
fi

set -e
# Copy iso file. Since 177 version, only have win8+ os
echo "+===========================================+"
echo "|          copy virtio-win iso file         |"
echo "+===========================================+"

#iso dirver path
x86_os="w8.1 w10"
x64_os="2k12 2k12R2 w8.1 w10 2k16 2k19 2k22 w11"
ARCH="amd64 x86"
ISO_PKG_MODULES="sriov viogpudo viofs balloon netkvm viostor vioser vioscsi viorng vioinput pvpanic qemupciserial qemufwcfg fwcfgdmp"
SRIOV_FILE="netkvmno netkvmp vioprot"
for module in $ISO_PKG_MODULES
do 
    module_name=$module
    for arch in $ARCH
    do
        if [ $arch == "amd64" ]
        then
            dst_os_dir=$x64_os
        else
            dst_os_dir=$x86_os
        fi

        for dst_os in $dst_os_dir
        do
            if [ $dst_os == "w8" -o $dst_os == "w8.1" -o $dst_os == "2k12" -o $dst_os == "2k12R2" ]
            then
                src_os="Win8"
                if [ $module == "netkvm" -o $module == "fwcfgdmp" ]
                then
                    if [ $dst_os == "w8.1" -o $dst_os == "2k12R2" ]
                    then
                        src_os="Win8.1"
                    fi
                fi
            elif [ $dst_os == "w10" -o $dst_os == "2k16" -o $dst_os == "2k19" -o $dst_os == "2k22" -o $dst_os == "w11" ]
            then
                src_os="Win10"
            fi

            if [ $module == "balloon" ]
            then
                module_name="Balloon"
            elif [ $module == "vioser" ]
            then
                module_name="vioserial"
	    elif [ $module == "netkvm" ]
	    then
		module_name="NetKVM"
	    elif [ $module == "fwcfgdmp" ]
            then
		module_name="fwcfg64"
            fi

	    # copy qemufwcfg file from VIR_WIN_RESOURCE_PATH
            if [ $module == "qemufwcfg" ];then
                if [ $dst_os == "w10" -o $dst_os == "2k16" -o $dst_os == "2k19" -o $dst_os == "2k22" -o $dst_os == "w11" ];then
                    # create qemufwcfg dst only for win10+
                    mkdir -p $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch
                    cp $VIR_WIN_RESOURCE_PATH/${module}* $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch 2>&1 >/dev/null
                    continue
                else
                    continue
                fi
            fi

	    # copy sriov files from VIR_WIN_RESOURCE_PATH
	    if [ $module == "sriov" ];then
		if [ $dst_os != "w8" -a $dst_os != "2k12" ];then
		    mkdir -p $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch
		    for sriov_file in $SRIOV_FILE; do
		        cp $VIR_WIN_RESOURCE_PATH/$src_os/$arch/${sriov_file}* $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch 2>&1 >/dev/null
		    done
		    continue
	        else
		    continue
	        fi
	    fi

            # create dst path
            mkdir -p $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch

            # copy qemupciserial file from VIR_WIN_RESOURCE_PATH
            if [ $module == "qemupciserial" ];then
                cp $VIR_WIN_RESOURCE_PATH/rhel/${module}* $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch 2>&1 >/dev/null
                continue
            fi

            # copy *gpu* files to dst
            if [ $module == "viogpudo" ];then
                cp $VIR_WIN_RESOURCE_PATH/$src_os/$arch/*gpu* $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch 2>&1 >/dev/null
                continue
            fi

            # copy other driver files from $VIR_WIN_RESOURCE_PATH/$src_os/$arch
            cp $VIR_WIN_RESOURCE_PATH/$src_os/$arch/${module}* $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch 2>&1 >/dev/null

	    # only keep dvl file in w10/amd64
	    if [ $dst_os != "w10" -o $arch != "amd64" ];then
	        rm -rf $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch/*DVL*XML
	    fi

	    # for some special files which should copy to dst
            if [ $module == "balloon" -o $module == "vioser" -o $module == "viorng" -o $module == "vioinput" -o $module == "pvpanic" -o $module == "viofs" ]
            then
                if [ $dst_os != "w10" -a $dst_os != "2k16" -a $dst_os != "2k19" -a $dst_os != "2k22" -a $dst_os != "w11" ]
                then
                    cp $VIR_WIN_RESOURCE_PATH/$src_os/$arch/WdfCoInstaller*.* $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch 2>&1 >/dev/null
                fi
	    fi

	    if [ $module == "balloon" ]
	    then
                cp $VIR_WIN_RESOURCE_PATH/$src_os/$arch/blnsvr.* $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch 2>&1 >/dev/null
	    fi

	    if [ $module == "vioinput" ]
	    then
                cp $VIR_WIN_RESOURCE_PATH/$src_os/$arch/viohidkmdf.* $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch 2>&1 >/dev/null
	    fi

	    if [ $module == "viofs" ]
	    then
	        cp $VIR_WIN_RESOURCE_PATH/$src_os/$arch/virtiofs.* $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch 2>&1 >/dev/null
	    fi

	    # delete netkvm related file of sriov
	    if [ $module == "netkvm" ]
	    then
	        for sriov_file in $SRIOV_FILE; do
	            rm -rf $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch/${sriov_file}*
	        done
	    fi
        done
    done
done


# copy w7 and win2008r2 drivers to dst iso
# mount nfs server
echo "DEBUG: mount nfs server to copy w7_2k8r2_w8 drivers to dst iso folder."
[ -d $NFS_MNT ] || mkdir -p $NFS_MNT
if [ -z "$(mount |grep $NFS_MNT)" ]
then
    # mount 10.66.8.115:/home/nfs $NFS_MNT
    mount 10.73.194.27:/vol/s2kvmauto/iso $NFS_MNT
else
    echo "/var/tmp/nfs is busy or already mounted"
fi
NEED_UMOUNT="Yes"

FIXED_ISO_PKG_MODULES="Balloon NetKVM pvpanic qemupciserial vioinput viorng vioscsi vioserial viostor viofs"
for module in $FIXED_ISO_PKG_MODULES
do
    cp -R $NFS_MNT/fixedwhqldriver/w7_2k8r2_w8_drivers/$module/* $VIR_WIN_TGT_ISO_PATH/$module 2>&1 >/dev/null
done

echo "DEBUG: Copy qxl and qemu-ga-win to $VIR_WIN_TGT_ISO_PATH"
mkdir -p $VIR_WIN_TGT_ISO_PATH/{guest-agent,qxl}

# Copy qxl driver
# https://mojo.redhat.com/docs/DOC-994900
WIN_QXL_VERSION="w7 2k8R2"
for dest_dir in $WIN_QXL_VERSION
do
    cp -R $VIR_WIN_QXL_RESOURCE_PATH/$dest_dir $VIR_WIN_TGT_ISO_PATH/qxl
done

# Copy qemu-ga-win
cp -R $VIR_WIN_QEMU_GA_RESOURCE_PATH/* $VIR_WIN_TGT_ISO_PATH/guest-agent

tree -C $VIR_WIN_TGT_ISO_PATH

echo "+===========================================+"
echo "|          create virtio-win-iso            |"
echo "+===========================================+"

#VIRTIO_WIN_ISO_NAME=virtio-win-prewhql-$MAIN_VERSION-$SUB_VERSION.iso
mkisofs -o $ISO_CREATE_ROOT_PATH/$VIRTIO_WIN_ISO_NAME \
        -input-charset iso8859-1 -J -R -V "Virtio-Win" $VIR_WIN_TGT_ISO_PATH
echo "DEBUG: Copy iso to $DST_PATH"
cp $ISO_CREATE_ROOT_PATH/$VIRTIO_WIN_ISO_NAME $DST_PATH/
echo "DEBUG: Chmod 755 for $DST_PATH/$VIRTIO_WIN_ISO_NAME"
chmod 755 $DST_PATH/$VIRTIO_WIN_ISO_NAME

#DISABLE THE SOFT LINK STEP
#ISO_LAT_NAME=virtio-win-latest-prewhql.iso
#[ -e "$DST_PATH/$ISO_LAT_NAME" ] && rm -r $DST_PATH/$ISO_LAT_NAME
#cd $DST_PATH && ln -sf $VIRTIO_WIN_ISO_NAME $ISO_LAT_NAME

set +e

echo "+===========================================+"
echo "|         Send email and clean env          |"
echo "+===========================================+"
function mail_notify()
{
    mail_content="virtio-win-prewhql-$MAIN_VERSION-${SUB_VERSION} have been created.\n"
    mail_content+="    virtio-win-prewhql version is: ${MAIN_VERSION}.${SUB_VERSION} \n"
    mail_content+="    qxl version is: ${MAIN_VERSION}.${QXL_VERSION} \n"
    #mail_content+="    qxlwddm version is: ${MAIN_VERSION}.${QXLWDDM_VERSION} \n\n"
    mail_content+="This mail is create by a bot, "
    mail_content+="anything please contact the maintainer: ${MAINTAINER_MAIL}."
    mail_subject="Create virtio-win-prewhql-$MAIN_VERSION-${SUB_VERSION}"
    echo -e "$mail_content" | mail -s "$mail_subject" -r virtio-win@redhat.com $NOTIFY_MAIL_LIST
}

if [ "_$SEND_MAIL" == "_Yes" -a "_$UPDATE_NFS" == "_Yes" ]
then
    mail_notify
fi

if [ "_$NEED_UMOUNT" == "_Yes" ]
then
    umount $NFS_MNT
fi


if [ "_$CLEAR_PATH" == "_Yes" ]
then
    rm -rf $VIR_WIN_TGT_ISO_PATH
    rm -rf $ROOT_PATH/virt_win_iso_create
fi

exit 0
