#get the old and new package url
URL_old=`head -n 1 package.cfg`
URL_new=`tail -1 package.cfg`

#mount old virtio-win iso file 
rpm -e virtio-win
rpm -ivh $URL_old
cp /usr/share/virtio-win/virtio-win.iso ./virtio-win-old.iso
mkdir mnt-iso-old
mount virtio-win-old.iso mnt-iso-old -o loop

#mount new virtio-win iso and floppy
rpm -Uvh $URL_new
mkdir mnt-iso
mkdir mnt-vfd-x86
mkdir mnt-vfd-amd64
mount /usr/share/virtio-win/virtio-win.iso mnt-iso -o loop
mount /usr/share/virtio-win/virtio-win_x86.vfd mnt-vfd-x86 -o loop
mount /usr/share/virtio-win/virtio-win_amd64.vfd mnt-vfd-amd64 -o loop

#check unchanged files(winxp/win2k3)
echo "begain to check the unchanged winxp/2003 files"
for i in `find mnt-iso -maxdepth 4 -mindepth 1 -type f | grep xp`;do diff $i ${i/mnt-iso/mnt-iso-old}; done
for i in `find mnt-iso -maxdepth 4 -mindepth 1 -type f | grep 2k3`;do diff $i ${i/mnt-iso/mnt-iso-old}; done

#check whether virtio-win iso and virtio-win floppy are same
echo "begain to check iso and floppy files are same"
sh diff-iso-vfd.sh
echo " check iso and floppy files are same done"

#get all prewhql version info from prewhql.cfg
VER=($(cut -b 5,6,7 prewhql.cfg))

#wget all version prewhql and unzip them
for i in "${VER[@]}" 
do
if [ -d "virtio-win-prewhql-0.1-$i" ];
    then
        echo "package already existing"
    else
        wget -P virtio-win-prewhql-0.1-$i http://download.devel.redhat.com/brewroot/packages/virtio-win-prewhql/0.1/$i/win/virtio-win-prewhql-0.1.zip;
        unzip virtio-win-prewhql-0.1-$i/virtio-win-prewhql-0.1.zip -d virtio-win-prewhql-0.1-$i/ 
    fi
done


#virtio-win.iso and virito-win-prewhql compare
echo "begain to check iso file is same with the related prewhql files"
echo "check balloon drivers"
sh diff-balloon.sh ${VER[0]}
echo "check netkvm drivers"
sh diff-netkvm.sh ${VER[1]}
echo "check rng drivers"
sh diff-rng.sh  ${VER[2]}
echo "check scsi drivers"
sh diff-scsi.sh ${VER[3]}
echo "check serial drivers"
sh diff-serial.sh ${VER[4]}
echo "check blk drivers"
sh diff-block.sh ${VER[5]}
echo "check pvpanic drivers"
sh diff-pvpanic.sh ${VER[6]}
echo "check input drivers"
sh diff-input.sh ${VER[7]}
echo "check qemupciserial drivers"
sh diff-qsr.sh ${VER[8]}
echo "check qemufwcfg drivers"
sh diff-fwg.sh ${VER[9]}
echo "check smbus drivers"
sh diff-smb.sh ${VER[10]}


#clean up work:
umount mnt-iso-old mnt-iso mnt-vfd-x86 mnt-vfd-amd64 
rm -rf virtio-win-old.iso mnt-iso-old mnt-iso mnt-vfd-x86 mnt-vfd-amd64 virtio-win-prewhql-*
