<ks><![CDATA[
rootpw --iscrypted $1$bPnySNFo$QCqmVA1sHhddG7v.ivCbA0

%post
#install certificate
wget https://password.corp.redhat.com/RH-IT-Root-CA.crt -O /etc/pki/ca-trust/source/anchors/RH-IT-Root-CA.crt --no-check-certificate
wget https://password.corp.redhat.com/legacy.crt -O /etc/pki/ca-trust/source/anchors/legacy.crt --no-check-certificate
wget https://engineering.redhat.com/Eng-CA.crt -O /etc/pki/ca-trust/source/anchors/Eng-CA.crt --no-check-certificate
update-ca-trust enable
update-ca-trust extract

## Setup bridge setup
ndev=$(ip route | grep default | grep -Po '(?<=dev )(\S+)' | awk 'BEGIN{ RS = "" ; FS = "\n" }{print $1}')
mac=$(cat /sys/class/net/$ndev/address)

cat > /etc/sysconfig/network-scripts/ifcfg-${ndev} <<EOF
DEVICE="$ndev"
NAME="$ndev"
ONBOOT="yes"
TYPE=Ethernet
HWADDR=$mac
BRIDGE="switch"
BOOTPROTO="none"
NM_CONTROLED="no"
EOF

cat > /etc/sysconfig/network-scripts/ifcfg-switch <<EOF
DEVICE="switch"
NAME="switch"
ONBOOT="yes"
TYPE=Bridge
BOOTPROTO="dhcp"
NM_CONTROLED="no"
DELAY=0
EOF
## End bridge Setup

## Adding qemu-ifup/down scripts to help manually debugging
cat > /etc/qemu-ifup<<EOF
#!/bin/sh
switch=switch
/sbin/ifconfig \$1 0.0.0.0 up
/usr/sbin/brctl addif \${switch} \$1
/usr/sbin/brctl setfd \${switch} 0
/usr/sbin/brctl stp \${switch} off
EOF

cat > /etc/qemu-ifdown <<EOF
#!/bin/sh
switch=switch
/sbin/ifconfig \$1 0.0.0.0 down
/usr/sbin/brctl delif \${switch} \$1
EOF
chmod a+rx /etc/qemu-if*
## End adding qemu-ifup/down scripts

## Install brewkoji
# Enable network to ensure we can download remote repo cfg
ping -c 5 download.eng.bos.redhat.com || service network restart
wget "http://download.eng.bos.redhat.com/rel-eng/internal/rcm-tools-rhel-7-server.repo" -O /etc/yum.repos.d/rcm-tools-rhel-7.repo
yum install brewkoji -y
## End brewkoji installation

## Generate 'brew_install.sh'
cat >/root/brew_install.sh <<EOF
#!/bin/bash
_TOPURL="http://download.devel.redhat.com"

_exit_on_error() { if [ \$? -ne 0 ]; then echo -e \$* >&2; exit 1; fi; }
_install_build() {
    local _RPMS
    _BUILD="\$(echo \${1}/ | cut -d'/' -f1)"
    _TAG="\$(echo \${_BUILD}@ | cut -d'@' -f2)"; _BUILD="\$(echo \${_BUILD}@ | cut -d'@' -f1)"
    _PKGS="\$(echo \${1}/ | cut -d'/' -f2)"; _PKGS="\${_PKGS//,/ }"
    _ARCH="\$(echo \${1}/ | cut -d'/' -f3)"; _ARCH="\${_ARCH:-\$(arch),noarch}"; _ARCH="\${_ARCH//,/|}"

    if [ "x\${_TAG}" == "xlocalrepos" ]; then
        for _PKG in \$_PKGS; do
            _RPMS=(\${_RPMS[@]} \$_PKG)
        done
        _RPMS=\${_RPMS:-\$_BUILD}
    else
        if [ -n "\${_TAG}" ]; then
            _OUTPUT="\$(brew latest-build \$_TAG \$_BUILD --quiet 2>&1)"
            _exit_on_error "Failed to get the latest build of '\$_BUILD (\$_TAG)', command output:\n\$_OUTPUT"
            _BUILD="\$(echo \$_OUTPUT | cut -d' ' -f1)"
        fi
        _OUTPUT="\$(brew buildinfo \$_BUILD 2>&1)"
        _exit_on_error "Failed to get build infomation of '\$_BUILD', command output:\n\$_OUTPUT"
        _URLS=\$(echo \$_OUTPUT | tr ' ' '\n' | grep -E "\$_ARCH\.rpm" | sed "s;/mnt/redhat;\$_TOPURL;g")

        for _PKG in \$_PKGS; do
            _HAS_PKG=""
            for _URL in \$_URLS; do
                _NVR=\${_URL##*/}; _NV=\${_NVR%-*}; _N=\${_NV%-*}
                if [ "\$_PKG" == "\$_N" ]; then _HAS_PKG="\$_URL"; break; fi
            done
            if [ -z "\$_HAS_PKG" ]; then echo "'\$_PKG' is not in '\$_BUILD', skipped" >&2; continue; fi
            _RPMS=(\${_RPMS[@]} \$_HAS_PKG)
        done
        _RPMS=\${_RPMS:-\$_URLS}
    fi
    yum install \${_RPMS[@]} -y || rpm -qa | grep "\$_BUILD" 2>&1 >/dev/null
    _exit_on_error "Failed to install rpm packages of '\$_BUILD'"
}
for _BUILD_REQ in \$@; do _install_build "\$_BUILD_REQ"; done
EOF
chmod a+rx /root/brew_install.sh

# Remove the kernel args we dont like
grubby --remove-args="rhgb quiet" --update-kernel=$(grubby --default-kernel)

## Enable rc.local service
ln -sf /etc/rc.d/rc.local /etc/rc.local
cat >> /etc/rc.d/rc.local <<EOF
#change aio
echo 1048575 > /proc/sys/fs/aio-max-nr
EOF
echo "true" >> /etc/rc.d/rc.local
chmod a+rx /etc/rc.d/rc.local
## End rc.local service setup

sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
systemctl enable kdump.service
systemctl enable rpcbind.service
systemctl enable NetworkManager.service
systemctl enable sshd.service
systemctl enable network.service
systemctl enable rc-local.service
systemctl enable nfs-server.service
systemctl enable nfs.service
systemctl disable firewalld.service
systemctl disable iptables.service
systemctl disable ip6tables.service
systemctl disable user.slice

# change the open files and the core size
echo "*               hard    core            unlimited" >> /etc/security/limits.conf
echo "*               hard    nofile            8192" >> /etc/security/limits.conf

if ! ping "github.com" -c 5; then
    echo "export http_proxy=http://squid.apac.redhat.com:3128" >> /etc/profile
    echo "export https_proxy=https://squid.apac.redhat.com:3128" >> /etc/profile
fi
yum install -y 'https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm'
%end

%packages --ignoremissing
bridge-utils
cyrus-sasl-md5
dracut-config-generic
fakeroot
ftp
gcc
glibc-headers
git
gstreamer-python
gstreamer1-plugins-good
httpd
iproute
iputils
iscsi-initiator-utils
kernel
lftp
lynx
mkisofs
mtools
net-snmp
nfs-utils
nmap-ncat
ntp
numactl
openssl-devel
p7zip
patch
perl-ExtUtils-MakeMaker
pygobject2
python-devel
python-pillow
rpcbind
screen
sg3_utils
sysstat
targetcli
tcpdump
telnet
telnet-server
vnc
vsftpd
xinetd
xorg-x11-xauth
%end
]]></ks>
