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
TMP_MNT=$TMP_DIR/tmp
NFS_MNT=$TMP_DIR/nfs
INFO_FILE=$TMP_DIR/.virtio-win-prewhql-info
URL_ROOT=http://download-node-02.eng.bos.redhat.com/brewroot/packages
VIRTIO_PKG_LINK=$URL_ROOT/virtio-win-prewhql/0.1/
QXL_PKG_LINK=$URL_ROOT/qxl-win/0.1/
QEMU_GA_LINK=$URL_ROOT/mingw-qemu-ga-win/
QEMU_GA_MAIN_VERSION=$(curl -s $QEMU_GA_LINK | sed -n 's/.*<a href="\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p'| sed -n '$p')
QEMU_GA_SUB_VERSION=$(curl -s $QEMU_GA_LINK$QEMU_GA_MAIN_VERSION/ | sed -n 's/.*<a href="\([0-9]\+\.[a-z]\+[0-9]\+[a-z]\+\).*/\1/p'| sed -n '$p')

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

#mount nfs
if [ $UPDATE_NFS == "Yes" ]
then
    [ -d $NFS_MNT ] || mkdir -p $NFS_MNT
    if [ -z $(mount|grep $NFS_MNT) ]
    then
        # mount 10.73.72.182:/home/nfs $NFS_MNT
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

#judge if the virtio-vin-prewhql iso existed in nfs server.
echo "The iso which will be updated to nfs is: $VIRTIO_WIN_ISO_NAME"
if [ -f "$DST_PATH/$VIRTIO_WIN_ISO_NAME" ]
then
    echo "$VIRTIO_WIN_ISO_NAME is already in nfs server,no need to create."
    if [ "_$NEED_UMOUNT" == "_Yes" ]
    then
        umount $NFS_MNT
    fi
    exit 0
fi

#http://download-node-02.eng.bos.redhat.com/brewroot/packages/mingw-qemu-ga-win/7.5.0/2.el7ev/noarch/qemu-ga-win-7.5.0-2.el7ev.noarch.rpm
#http://download.eng.pnq.redhat.com/brewroot/packages/virtio-win-prewhql/0.1/125/win/virtio-win-prewhql-0.1.zip
URL_VIRT_WIN_ZIP=$URL_ROOT/virtio-win-prewhql/$MAIN_VERSION/$SUB_VERSION/win/virtio-win-prewhql-$MAIN_VERSION.zip
URL_QXL_W7_X64=$QXL_PKG_LINK/$QXL_VERSION/win/qxl_w7_x64.zip
URL_QXL_W7_X86=$QXL_PKG_LINK/$QXL_VERSION/win/qxl_w7_x86.zip
URL_QXL_XP_X86=$QXL_PKG_LINK/$QXL_VERSION/win/qxl_xp_x86.zip
URL_QXL_2K8R2_X64=$QXL_PKG_LINK/$QXL_VERSION/win/qxl_8k2R2_x64.zip
URL_QEMU_GA_PKG=$QEMU_GA_LINK$QEMU_GA_MAIN_VERSION/$QEMU_GA_SUB_VERSION/noarch/$QEMU_GA_PKG

#create the related dir
if [ ! -e $ROOT_PATH/virt_win_iso_create ]
then
    mkdir -p $ROOT_PATH/virt_win_iso_create/{iso,source,virtio-win-vfd,vfs_source,qxl,guest-agent}
fi

ISO_CREATE_ROOT_PATH=$ROOT_PATH/virt_win_iso_create
VIR_WIN_TGT_ISO_PATH=$ISO_CREATE_ROOT_PATH/iso
VIR_WIN_TGT_VFD_PATH=$ISO_CREATE_ROOT_PATH/virtio-win-vfd
VIR_WIN_RESOURCE_PATH=$ISO_CREATE_ROOT_PATH/source
VIR_WIN_VFS_RESOURCE_PATH=$ISO_CREATE_ROOT_PATH/vfs_source
VIR_WIN_QXL_RESOURCE_PATH=$ISO_CREATE_ROOT_PATH/qxl
VIR_WIN_QEMU_GA_RESOURCE_PATH=$ISO_CREATE_ROOT_PATH/guest-agent

declare -A VFD_DEST_PATH VFD_ARCH_DEST_PATH ISO_DST_PATH

# Download the packages
if [ "_$NEED_WGET" == "_Yes" ]
then
    echo "=========== Get the files from the server =========="
    rm -rf $VIR_WIN_RESOURCE_PATH/*
    rm -rf $VIR_WIN_VFS_RESOURCE_PATH/*
    rm -rf $VIR_WIN_QXL_RESOURCE_PATH/*
    rm -rf $VIR_WIN_TGT_ISO_PATH/*
    rm -rf $VIR_WIN_TGT_VFD_PATH/*
    rm -rf $VIR_WIN_QEMU_GA_RESOURCE_PATH/*

    set -e
    wget $URL_VIRT_WIN_ZIP  -O $VIR_WIN_RESOURCE_PATH/$VIRTIO_WIN_PKG_NAME  2>&1 >/dev/null
    wget $URL_QXL_W7_X64    -O $VIR_WIN_QXL_RESOURCE_PATH/QXL_W7_X64.zip    2>&1 >/dev/null
    wget $URL_QXL_W7_X86    -O $VIR_WIN_QXL_RESOURCE_PATH/QXL_W7_X86.zip    2>&1 >/dev/null
    wget $URL_QXL_XP_X86    -O $VIR_WIN_QXL_RESOURCE_PATH/QXL_XP_X86.zip    2>&1 >/dev/null
    wget $URL_QXL_2K8R2_X64 -O $VIR_WIN_QXL_RESOURCE_PATH/QXL_2K8R2_X64.zip 2>&1 >/dev/null

    unzip -d $VIR_WIN_RESOURCE_PATH     $VIR_WIN_RESOURCE_PATH/$VIRTIO_WIN_PKG_NAME  2>&1 >/dev/null
    unzip -d $VIR_WIN_QXL_RESOURCE_PATH $VIR_WIN_QXL_RESOURCE_PATH/QXL_W7_X64.zip    2>&1 >/dev/null
    unzip -d $VIR_WIN_QXL_RESOURCE_PATH $VIR_WIN_QXL_RESOURCE_PATH/QXL_W7_X86.zip    2>&1 >/dev/null
    unzip -d $VIR_WIN_QXL_RESOURCE_PATH $VIR_WIN_QXL_RESOURCE_PATH/QXL_XP_X86.zip    2>&1 >/dev/null
    unzip -d $VIR_WIN_QXL_RESOURCE_PATH $VIR_WIN_QXL_RESOURCE_PATH/QXL_2K8R2_X64.zip 2>&1 >/dev/null

    #get qemu-ga-win msi file
    QEMU_GA_WIN_VER=$(rpm -q qemu-ga-win | sed -n 's/.*\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p')
    if [ "$QEMU_GA_WIN_VER" == "$QEMU_GA_MAIN_VERSION" ]
    then
        echo "The current qemu-ga-win version is the latest one."
    else
        wget $URL_QEMU_GA_PKG  2>&1 >/dev/null
        rpm -Uvh $QEMU_GA_PKG  2>&1 >/dev/null
    fi
    cp /usr/x86_64-w64-mingw32/sys-root/mingw/bin/qemu-ga-x86_64.msi $VIR_WIN_QEMU_GA_RESOURCE_PATH/  2>&1 >/dev/null
    cp /usr/i686-w64-mingw32/sys-root/mingw/bin/qemu-ga-i386.msi $VIR_WIN_QEMU_GA_RESOURCE_PATH/  2>&1 >/dev/null

    set +e
else
    rm -rf $VIR_WIN_TGT_ISO_PATH/*
    rm -rf $VIR_WIN_TGT_VFD_PATH/*

    if [ ! -d $VIR_WIN_RESOURCE_PATH ]
    then
        echo "You must download the source file, not using -n"
        exit 1
    fi
fi

mkdir -p $VIR_WIN_TGT_ISO_PATH/{guest-agent,qxl}

set -e
# Copy iso file
echo "+===========================================+"
echo "|          copy virtio-win iso file         |"
echo "+===========================================+"

#iso dirver path
x86_os="w7 w8 w8.1 w10 2k8"
x64_os="2k12 2k12R2 2k8 2k8R2 w7 w8 w8.1 w10 2k16 2k19"
ARCH="amd64 x86"
ISO_PKG_MODULES="balloon netkvm viostor vioser vioscsi viorng vioinput pvpanic qemupciserial qemufwcfg"
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
        # no vioinput driver for 2008 guest
        if [ $module == "vioinput" ]
        then
            dst_os_dir=${dst_os_dir/2k8/}
        fi

        for dst_os in $dst_os_dir
        do
            if [ $dst_os == "2k8" ]
            then
                src_os="Wlh"
            elif [ $dst_os == "w7" -o $dst_os == "2k8R2" ]
            then
                src_os="Win7"
            elif [ $dst_os == "w8" -o $dst_os == "w8.1" -o $dst_os == "2k12" -o $dst_os == "2k12R2" ]
            then
                src_os="Win8"
                if [ $module == "netkvm" ]
                then
                    module_name="NetKVM"
                    if [ $dst_os == "w8.1" -o $dst_os == "2k12R2" ]
                    then
                        src_os="Win8.1"
                    fi
                fi
            elif [ $dst_os == "w10" -o $dst_os == "2k16" -o $dst_os == "2k19" ]
            then
                src_os="Win10"
            fi
            if [ $module == "balloon" ]
            then
                module_name="Balloon"
            elif [ $module == "vioser" ]
            then
                module_name="vioserial"
            fi

            # copy qemufwcfg file from VIR_WIN_RESOURCE_PATH
            if [ $module == "qemufwcfg" ];then
                if [ $dst_os == "w10" -o $dst_os == "2k16" -o $dst_os == "2k19" ];then
                    mkdir -p $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch
                    cp $VIR_WIN_RESOURCE_PATH/${module}* $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch 2>&1 >/dev/null
                    continue
                else
                    continue
                fi
            fi

            mkdir -p $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch
            # copy qemupciserial file from VIR_WIN_RESOURCE_PATH
            if [ $module == "qemupciserial" ];then
                cp $VIR_WIN_RESOURCE_PATH/rhel/${module}* $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch 2>&1 >/dev/null
                continue
            fi
            # copy other driver files from $VIR_WIN_RESOURCE_PATH/$src_os/$arch
            cp $VIR_WIN_RESOURCE_PATH/$src_os/$arch/${module}* $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch 2>&1 >/dev/null

            if [ -e $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch/*.XML ]
            then
                rm $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch/*.XML
            fi
            #if [ $module == "netkvm" ]
            #then
            #    cp $VIR_WIN_RESOURCE_PATH/$src_os/$arch/readme.* $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch 2>&1 >/dev/null
            #elif [ $module == "balloon" -o $module == "vioser" -o $module == "viorng" -o $module == "vioinput" ]
            if [ $module == "balloon" -o $module == "vioser" -o $module == "viorng" -o $module == "vioinput" -o $module == "pvpanic" ]
            then
                if [ $dst_os != "w10" -a $dst_os != "2k16" -a $dst_os != "2k19" ]
                then
                    cp $VIR_WIN_RESOURCE_PATH/$src_os/$arch/WdfCoInstaller*.* $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch 2>&1 >/dev/null
                fi
                if [ $module == "balloon" ]
                then
                    cp $VIR_WIN_RESOURCE_PATH/$src_os/$arch/blnsvr.* $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch 2>&1 >/dev/null
                elif [ $module == "vioinput" ]
                then
                    cp $VIR_WIN_RESOURCE_PATH/$src_os/$arch/viohidkmdf.* $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch 2>&1 >/dev/null
                elif [ $module == "vioser" ]
                then
                    if ls $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch/vioser-test.*
                    then
                        rm $VIR_WIN_TGT_ISO_PATH/$module_name/$dst_os/$arch/vioser-test.*
                    fi
                fi
            fi
        done
    done
done

# As floppy space is not enough after adding win2019 folder,so didn't copy fixed 2003 and xp
##copy fixed 2003 and xp driver from nfs server to dst iso
#FIXED_ISO_PKG_MODULES="Balloon NetKVM vioserial viostor"
#for module in $FIXED_ISO_PKG_MODULES
#do
#    cp -R $NFS_MNT/fixedwhqldriver/for_iso/$module/* $VIR_WIN_TGT_ISO_PATH/$module 2>&1 >/dev/null
#done

# Copy vfd driver
echo "+===========================================+"
echo "|            copy virtio-vfd file           |"
echo "+===========================================+"

#vfd dirver path
ARCH_VFD="amd64 x86 servers_amd64 servers_x86"
amd64_os_vfd="Win7 Win8 Win8.1 Win10"
servers_amd64_os_vfd="Win2008 Win2008R2 Win2012 Win2012R2 Win2016 Win2019"
x86_os_vfd="Win7 Win8 Win8.1 Win10"
servers_x86_os_vfd="Win2008"
VFD_PKG_MODULES="netkvm viostor vioscsi"
for module in $VFD_PKG_MODULES
do
    for arch in $ARCH_VFD
    do
        #get src_arch
        if [[ $arch =~ "amd64" ]]; then
            src_arch="amd64"
        else
            src_arch="x86"
        fi
        #get dst_os_dir's value
        dst_os_dir_name=${arch}_os_vfd

        for dst_os in ${!dst_os_dir_name}
        do
            if [ $dst_os == "Win2008" ]
            then
                src_os="Wlh"
            elif [ $dst_os == "Win7" -o $dst_os == "Win2008R2" ]
            then
                src_os="Win7"
            elif [ $dst_os == "Win8" -o $dst_os == "Win8.1" -o $dst_os == "Win2012" -o $dst_os == "Win2012R2" ]
            then
                src_os="Win8"
                if [ $module == "netkvm" -a $dst_os == "Win8.1" ] || [ $module == "netkvm" -a $dst_os == "Win2012R2" ]
                then
                    src_os="Win8.1"
                fi
            elif [ $dst_os == "Win10" -o $dst_os == "Win2016" -o $dst_os == "Win2019" ]
            then
                src_os="Win10"
            fi
            mkdir -p $VIR_WIN_TGT_VFD_PATH/$arch/$dst_os
            cp $VIR_WIN_RESOURCE_PATH/$src_os/$src_arch/${module}.*  $VIR_WIN_TGT_VFD_PATH/$arch/$dst_os 2>&1 >/dev/null
            if [ -e $VIR_WIN_TGT_VFD_PATH/$arch/$dst_os/*.XML ]
            then
                rm $VIR_WIN_TGT_VFD_PATH/$arch/$dst_os/*.XML
            fi
            if [ -e $VIR_WIN_TGT_VFD_PATH/$arch/$dst_os/*.pdb ]
            then
               rm $VIR_WIN_TGT_VFD_PATH/$arch/$dst_os/*.pdb
            fi
        done
    done
done  

##copy fixed 2003 and xp driver from nfs server to vfd
#ARCH_VFD="amd64 i386"
#for arch in $ARCH_VFD
#do
#    cp -R $NFS_MNT/fixedwhqldriver/for_vfd_$arch/* $VIR_WIN_TGT_VFD_PATH/$arch  2>&1 >/dev/null
#done

# Copy qxl driver
# https://mojo.redhat.com/docs/DOC-994900
WIN_QXL_VERSION="xp w7 2k8R2"
for dest_dir in $WIN_QXL_VERSION
do
    cp -R $VIR_WIN_QXL_RESOURCE_PATH/$dest_dir $VIR_WIN_TGT_ISO_PATH/qxl
done


# Copy qemu-ga-win
cp -R $VIR_WIN_QEMU_GA_RESOURCE_PATH/* $VIR_WIN_TGT_ISO_PATH/guest-agent

tree -C $VIR_WIN_TGT_ISO_PATH
tree -C $VIR_WIN_TGT_VFD_PATH

echo "+===========================================+"
echo "|          create virtio-win-iso            |"
echo "+===========================================+"

touch $VIR_WIN_TGT_VFD_PATH/disk1
cat > $VIR_WIN_TGT_VFD_PATH/txtsetup.oem << EOF
[Disks]
d1 = "OEM DISK (SCSI) WinXP/32-bit",\disk1,\i386\WinXP
d2 = "OEM DISK (SCSI) Win2003/32-bit",\disk1,\i386\Win2003
d3 = "OEM DISK (SCSI) Win2003/64-bit",\disk1,\amd64\Win2003

[Defaults]
SCSI = WXP32

[scsi]
WXP32  = "Red Hat VirtIO SCSI Disk Device WinXP/32-bit"
WNET32 = "Red Hat VirtIO BLOCK Disk Device Win2003/32-bit"
WNET64 = "Red Hat VirtIO BLOCK Disk Device Win2003/64-bit"

[Files.scsi.WXP32]
driver = d1, viostor.sys, viostor
inf    = d1, viostor.inf
catalog= d1, viostor.cat

[Files.scsi.WNET32]
driver = d2, viostor.sys, viostor
inf    = d2, viostor.inf
catalog= d2, viostor.cat

[Files.scsi.WNET64]
driver = d3, viostor.sys, viostor
inf    = d3, viostor.inf
catalog= d3, viostor.cat

[HardwareIds.scsi.WXP32]
id = "PCI\VEN_1AF4&DEV_1001&SUBSYS_00000000", "viostor"
id = "PCI\VEN_1AF4&DEV_1001&SUBSYS_00020000", "viostor"
id = "PCI\VEN_1AF4&DEV_1001&SUBSYS_00021AF4", "viostor"

[HardwareIds.scsi.WNET32]
id = "PCI\VEN_1AF4&DEV_1001&SUBSYS_00000000", "viostor"
id = "PCI\VEN_1AF4&DEV_1001&SUBSYS_00020000", "viostor"
id = "PCI\VEN_1AF4&DEV_1001&SUBSYS_00021AF4", "viostor"

[HardwareIds.scsi.WNET64]
id = "PCI\VEN_1AF4&DEV_1001&SUBSYS_00000000", "viostor"
id = "PCI\VEN_1AF4&DEV_1001&SUBSYS_00020000", "viostor"
id = "PCI\VEN_1AF4&DEV_1001&SUBSYS_00021AF4", "viostor"

[Config.WXP32]
value = Parameters\PnpInterface,5,REG_DWORD,1

[Config.WNET32]
value = Parameters\PnpInterface,5,REG_DWORD,1

[Config.WNET64]
value = Parameters\PnpInterface,5,REG_DWORD,1

EOF

chmod 755 $VIR_WIN_TGT_VFD_PATH/disk1
chmod 755 $VIR_WIN_TGT_VFD_PATH/txtsetup.oem


# Create floppy and iso
ISO_LAT_NAME=virtio-win-latest-prewhql.iso
VFD_LAT_amd64=virtio-win-latest-prewhql_amd64.vfd
VFD_LAT_x86=virtio-win-latest-prewhql_x86.vfd
VFD_LAT_servers_amd64=virtio-win-latest-prewhql_servers_amd64.vfd
VFD_LAT_servers_x86=virtio-win-latest-prewhql_servers_x86.vfd


[ -d $TMP_MNT ] || mkdir -p $TMP_MNT
[ -d $DST_PATH ] || mkdir -p $DST_PATH

## defined above.
## ARCH_VFD="amd64 x86 servers_amd64 servers_x86"
for arch in $ARCH_VFD
do
    # copy vfs resource to floppy.img and crete vfd format
    dd if=/dev/zero of=$VIR_WIN_VFS_RESOURCE_PATH/floppy.img bs=1024 count=2880
    sleep 2
    echo -e "\n\n\n\n\n\n"
    ls $VIR_WIN_VFS_RESOURCE_PATH/floppy.img
    echo -e  "\n\n\n\n\n\n"
    sleep 2
    mkfs.msdos $VIR_WIN_VFS_RESOURCE_PATH/floppy.img
    echo -e "\n\n\n\n\n\n"
    ls $VIR_WIN_VFS_RESOURCE_PATH/floppy.img
    echo -e "\n\n\n\n\n\n"
    mount $VIR_WIN_VFS_RESOURCE_PATH/floppy.img -o loop $TMP_MNT
    ls $VIR_WIN_TGT_VFD_PATH
    cp -R $VIR_WIN_TGT_VFD_PATH/{$arch,disk1,txtsetup.oem} $TMP_MNT
    # rename servers_xxx to xxx in TMP_MNT;and rename x86 to i386
    if [[ $arch == "servers_amd64" ]]; then
        mv $TMP_MNT/$arch $TMP_MNT/amd64
    elif [[ $arch == "servers_x86" ]] || [[ $arch == "x86" ]]; then
        mv $TMP_MNT/$arch $TMP_MNT/i386
    fi
    sync
    cd $TMP_DIR
    umount $TMP_MNT

    # copy floppy.img to dst path,such as nfs path and update name
    DST_VFD_NAME="virtio-win-prewhql-$MAIN_VERSION-${SUB_VERSION}_$arch.vfd"
    #cp $VIR_WIN_VFS_RESOURCE_PATH/floppy.img $VIR_WIN_TGT_ISO_PATH/$DST_VFD_NAME
    [ -e "$DST_PATH/$DST_VFD_NAME" ] && rm -f $DST_PATH/$DST_VFD_NAME
    cp $VIR_WIN_VFS_RESOURCE_PATH/floppy.img $DST_PATH/$DST_VFD_NAME
    chmod 755 $DST_PATH/$DST_VFD_NAME

    # create softlink for vfd
    VFD_LAT_NAME=VFD_LAT_$arch
    #[ -e "${!VFD_LAT_NAME}" ] && rm -f ${!VFD_LAT_NAME}
    cd $DST_PATH && ln -sf $DST_VFD_NAME ${!VFD_LAT_NAME}
    ls
    cd $TMP_DIR
done

#VIRTIO_WIN_ISO_NAME=virtio-win-prewhql-$MAIN_VERSION-$SUB_VERSION.iso
mkisofs -o $ISO_CREATE_ROOT_PATH/$VIRTIO_WIN_ISO_NAME \
        -input-charset iso8859-1 -J -R -V "Virtio-Win" $VIR_WIN_TGT_ISO_PATH
cp $ISO_CREATE_ROOT_PATH/$VIRTIO_WIN_ISO_NAME $DST_PATH/
chmod 755 $DST_PATH/$VIRTIO_WIN_ISO_NAME

[ -e "$DST_PATH/$ISO_LAT_NAME" ] && rm -r $DST_PATH/$ISO_LAT_NAME
cd $DST_PATH && ln -sf $VIRTIO_WIN_ISO_NAME $ISO_LAT_NAME
ls
cd $TMP_DIR

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
    rm -rf $VIR_WIN_TGT_ISO_PATH $VIR_WIN_TGT_VFD_PATH
    rm -rf $ROOT_PATH/virt_win_iso_create
fi

exit 0
