#!/usr/bin/env python
# -*- coding:utf-8 -*-
import os
import re
import shutil
import smtplib
import logging.config
import subprocess
import time
import sys

try:
    import ConfigParser
except:
    import configparser as ConfigParser
from email.mime.text import MIMEText

__maintainer__ = 'xiagao@redhat.com'
__version__ = '1.0'
__all__ = []


class UpdateVirtioWin:
    #Todo: The class needs to be rearranged so that some of the repeated code could be eliminated.
    virtio_win_name_list = []

    def __init__(self, tag, packagename, virtio_win_version, nfspath, workdir, nfsserver, decompressed_dir):
        self.tag = tag
        self.packagename = packagename
        self.nfspath = nfspath
        self.nfsserver = nfsserver
        self.workdir = workdir
        self.decompressed_dir = decompressed_dir
        self.virtio_win_version = virtio_win_version

    def check_virtio_win(self):
        """
        Check if there is new virtio_win version.
        :return: bool
        """
        existed_virtio_win = os.listdir(self.nfspath)
        logger.info('Existed virtio_win_file and its linkname:\n %s ' % existed_virtio_win)
        self.virtio_win_name = self.get_latest_virtio_win_name().strip()
        for version in existed_virtio_win:
            if self.virtio_win_name in version:
                return True
        return False

    def process_cmd(self, cmd):
        # run shell cmd
        try:
            logger.info('Start to execute the command: %s' % cmd)
            output = subprocess.Popen(
                cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            data, data_err = output.communicate()
            return data
        except:
            if not output.returncode == 0:
                logger.info("Can't execute the command %s" % cmd)
    def __get_latest_virtio_win(self):
        """
        Get the latest virtio_win and its info.
        :return: virtio_win name
        """
        cmd = "brew latest-pkg %s %s" % (self.tag, self.packagename)
        cmd += " | grep virtio | awk '{print $1}'"

        return self.process_cmd(cmd), self.tag

    def get_latest_virtio_win_name(self):
        """
        Get the latest virtio_win_name
        :return: latest virtio_win_name
        """
        virtio_win_name = self.__get_latest_virtio_win()[0]
        logger.info('The latest virtio_win_name is: %s' % virtio_win_name)
        return virtio_win_name

    def get_latest_virtio_win_tag(self):
        """
        Get the latest virtio_win_tag
        :return: latest virtio_win_tag
        """
        virtio_win_tag = self.__get_latest_virtio_win()[1]
        logger.info('The latest virtio_win_tag is: %s' % virtio_win_tag)
        return virtio_win_tag

    def download(self):
        """
        Download the virtio_win package.
        :return: None
        """
        tagname = self.get_latest_virtio_win_tag()
        cmd = "cd %s;brew download-build --arch=noarch --latestfrom=%s %s"
        cmd = cmd % (self.workdir, tagname, self.packagename)
        logger.info('Start to Download virtio_win rpm package: %s' % self.packagename)
        self.process_cmd(cmd)

    def decompress_rpm_package(self):
        """
        Decompress the package and find the iso files needed.
        :return: None
        """
        package = "%s.noarch.rpm" % self.virtio_win_name
        cmd = "cd %s;rpm2cpio %s | cpio -dimv" % (self.workdir, package)
        logger.info('Start to execute %s' % cmd)
        logger.info('Start to decompress: %s' % package)
        self.process_cmd(cmd)

    def __get_file_dir(self):
        """
        Get the directory after decompress
        :return:
        """
        return os.path.join(self.workdir, self.decompressed_dir)

    def __rename_file(self, pattern='virtio-win-'):
        """
        Rename the virio_win file name according to the one defined.
        :param pattern:
        :return:
        """
        virtio_win_name = self.virtio_win_name
        file_dir = self.__get_file_dir()
        logger.info('Current directory: %s' % file_dir)
        os.chdir(file_dir)
        for i in os.listdir(file_dir):
            if pattern in i:
                if i.endswith('.iso'):
                    shutil.move(i, '%s.iso' % virtio_win_name)
                elif i.endswith('amd64.vfd') and 'servers' not in i:
                    shutil.move(i, '%s_amd64.vfd' % virtio_win_name)
                elif i.endswith('amd64.vfd') and 'servers' in i:
                    shutil.move(i, '%s_servers_amd64.vfd' % virtio_win_name)
                elif i.endswith('x86.vfd') and 'servers' not in i:
                    shutil.move(i, '%s_x86.vfd' % virtio_win_name)
                else:
                    shutil.move(i, '%s_servers_x86.vfd' % virtio_win_name)

    def __get_virtio_win_name_list(self, pattern='virtio-win-'):
        """
        Get the virtio_win list after rename
        :param pattern:
        :return: the virtio_win list after rename
        """
        self.__rename_file()
        virtio_list = []
        file_dir = self.__get_file_dir()
        for filename in os.listdir(file_dir):
            if pattern in filename:
                virtio_list.append(os.path.join(file_dir, filename))
                print virtio_list

        return virtio_list

    def copy_to_nfs(self):
        """
        Copy the needed iso/vfd files to our working nfs.
        :return: None
        """
        logger.info('Start to copy packages to nfs server: %s' % self.nfsserver)
        self.virtio_list = self.__get_virtio_win_name_list()
        for filename in self.virtio_list:
            shutil.copy(filename, self.nfspath)

    def __create_soft_link(self, target, linkname):
        """
        Create soft link
        :param target:
        :param linkname:
        :return:
        """
        cmd = 'ln -sf %s %s' % (target, linkname)
        logger.info('Start make softlink, command: %s' % cmd)
        return self.process_cmd(cmd)

    def make_link(self):
        """
        Create the predefined soft link name:
        if el9 comes out ,we could add the map in the dict and etc.
        the name is got from ./staf-kvm-devel/internal_cfg/host-kernel/Host_RHEL/7.cfg
        From rhel7.6,there are two kinds of vfd file,one is for windows desktop and the
        other is for windows server.
        map:
        virtio-win.iso.el6 -> virtio-win-latest-signed-el6.iso ->
        virtio-win_x86.vfd.el6 -> virtio-win-latest-signed-el6.vfd.i386 ->
        virtio-win_amd64.vfd.el6 -> virtio-win-latest-signed-el6.vfd.amd64 ->
        virtio-win.iso.el7 -> virtio-win-latest-signed-el7.iso ->
        virtio-win_x86.vfd.el7 -> virtio-win-latest-signed-el7_x86.vfd ->
        virtio-win_amd64.vfd.el7 -> virtio-win-latest-signed-el7_amd64.vfd ->
        virtio-win_x86.vfd.el7 -> virtio-win-latest-signed-el7_servers_x86.vfd ->
        virtio-win_amd64.vfd.el7 -> virtio-win-latest-signed-el7_servers_amd64.vfd ->
        virtio-win.iso.el8 -> virtio-win-latest-signed-el8.iso ->
        virtio-win_x86.vfd.el8 -> virtio-win-latest-signed-el8_x86.vfd ->
        virtio-win_amd64.vfd.el8 -> virtio-win-latest-signed-el8_amd64.vfd ->
        virtio-win_servers_x86.vfd.el8 -> virtio-win-latest-signed-el8_servers_x86.vfd ->
        virtio-win_servers_amd64.vfd.el8 -> virtio-win-latest-signed-el8_servers_amd64.vfd ->
        :return:
        """
        virtio_win_map = {
            "el6": {
                "virtio-win.iso.el6": "virtio-win-latest-signed-el6.iso",
                "virtio-win_x86.vfd.el6": "virtio-win-latest-signed-el6_x86.vfd",
                "virtio-win_amd64.vfd.el6": "virtio-win-latest-signed-el6_amd64.vfd",
            },
            "el7": {
                "virtio-win.iso.el7": "virtio-win-latest-signed-el7.iso",
                "virtio-win_x86.vfd.el7": "virtio-win-latest-signed-el7_x86.vfd",
                "virtio-win_amd64.vfd.el7": "virtio-win-latest-signed-el7_amd64.vfd",
                "virtio-win_servers_x86.vfd.el7": "virtio-win-latest-signed-el7_servers_x86.vfd",
                "virtio-win_servers_amd64.vfd.el7": "virtio-win-latest-signed-el7_servers_amd64.vfd",
            },
            "el8": {
                "virtio-win.iso.el8": "virtio-win-latest-signed-el8.iso",
                "virtio-win_x86.vfd.el8": "virtio-win-latest-signed-el8_x86.vfd",
                "virtio-win_amd64.vfd.el8": "virtio-win-latest-signed-el8_amd64.vfd",
                "virtio-win_servers_x86.vfd.el8": "virtio-win-latest-signed-el8_servers_x86.vfd",
                "virtio-win_servers_amd64.vfd.el8": "virtio-win-latest-signed-el8_servers_amd64.vfd",
            }
        }
        image_type = ['amd64.vfd', 'x86.vfd', 'servers_amd64.vfd', 'servers_x86.vfd', 'iso']


        def __create(imagetype):

            for virtio_win_name in self.virtio_list:
                logger.info("The virtio_win_name is %s." % virtio_win_name)
                #if imagetype is amd64/x86,will exclude servers virtio_win_name.
                if imagetype == 'amd64.vfd' or imagetype == 'x86.vfd':
                    if 'servers' in virtio_win_name:
                        continue
                if virtio_win_name.endswith(imagetype):
                    #make one virtio-win-name match with one dict item
                    for key, value in virtio_win_map[self.virtio_win_version].items():
                        if value.endswith(imagetype) and virtio_win_name.find(self.virtio_win_version):
                            #if imagetype is amd64/x86,will exclude servers dict.
                            if imagetype == 'amd64.vfd' or imagetype == 'x86.vfd':
                                if 'servers' in key:
                                    continue
                            if os.path.exists(os.path.basename(virtio_win_name)):
                                self.virtio_win_name_list.append(os.path.basename(virtio_win_name))
                                logger.info("The virtio_win_name_list is %s." % self.virtio_win_name_list)
                                os.chdir(self.nfspath)
                                self.__create_soft_link(os.path.basename(virtio_win_name), value)
                                # didn't link latest-singed.xx to virtio-win.xxx.elx
                                # self.__create_soft_link(value, key)

        for image in image_type:
            __create(image)

    def __make_dir(self):
        """
        Create directory
        :return:
        """
        logger.info('Start to create nfs mountpoint: %s' % self.nfspath)
        if not os.path.exists(self.nfspath):
            os.mkdir(self.nfspath)

        logger.info('Start to create working directory: %s' % self.workdir)
        if not os.path.exists(self.workdir):
            os.mkdir(self.workdir)

    def umount_dir(self):
        """
        Umount directory
        :return:
        """
        if os.path.ismount(self.nfspath):
            u1 = subprocess.Popen("umount -l %s" % self.nfspath,
                                  shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            data, data_err = u1.communicate()
            if not u1.returncode == 0:
                logger.error("Fail to umount because of the following error: %s" % data_err)
                return
        self.__clean()

    def mount_dir(self):
        """
        Mount directory
        :return:
        """
        self.umount_dir()
        self.__make_dir()
        virtio_win_nfs_server = "mount -t nfs %s %s" % (self.nfsserver, self.nfspath)
        m1 = subprocess.Popen(virtio_win_nfs_server, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        data, data_err = m1.communicate()
        if not m1.returncode == 0:
            logger.error("mounting %s got error %s" % (virtio_win_nfs_server, data_err))
            exit(1)

    def __clean(self):
        """
        Clean everything such as the downloaded package, the mounted dir and etc.
        :return:
        """
        if os.path.exists(self.nfspath) and not os.path.ismount(self.nfspath):
            os.rmdir(self.nfspath)
        if os.path.exists(self.workdir):
            shutil.rmtree(self.workdir)

    def update_virtio_win(self):
        """
        update the latest version for non-released rhel, like rhel7.5
        """
        logger.info('Start to update virtio_win, Please wait for a while.')
        self.mount_dir()
        if not self.check_virtio_win():
            self.download()
            self.decompress_rpm_package()
            self.copy_to_nfs()
            self.make_link()
            self.umount_dir()
        else:
            logger.warn('%s exists, will not recreate it.' % self.virtio_win_name)

    def __str__(self):
        pass


def mail_sent(to_list, subject, content, maintainer="xiagao",
              smtp="smtp.corp.redhat.com"):
    """
    send email
    """
    mail = MIMEText(content, _subtype='plain', _charset='utf-8')
    mail['Subject'] = subject
    mail['To'] = ";".join(to_list)
    mail['From'] = maintainer

    try:
        server = smtplib.SMTP(smtp)
        server.sendmail(maintainer, to_list, mail.as_string())
        server.quit()
    except Exception as e:
        logger.info(e)
    return


def main():
    """
    working function of all.
    """
    logger.debug('Start init Env:')
    cfg = ConfigParser.ConfigParser()
    cfg.read(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'virtio_win.cfg'))
    base = 'BASE'
    nfsserver = cfg.get(base, 'nfsserver')
    nfspath = cfg.get(base, 'nfspath')
    packagename = cfg.get(base, 'package_name')
    workdir = cfg.get(base, 'workdir')
    decompressed_dir = cfg.get(base, 'decompressed_dir')
    maintainer = cfg.get(base, 'maintainer')
    sender = maintainer.split('@')[0]
    sender = "%s <%s>" % (sender, maintainer)
    notification_list = cfg.get(base, 'notification_list').split()
    subject = cfg.get(base, 'subject')
    content = open(os.path.join(os.path.dirname(__file__), 'mailcontent'), 'r').read()

    virtio_win_version = ""
    name_list = []

    # update the latest version according to tag,such as supp-rhel-8.0.1-candidate
    tag = sys.argv[1]
    main_version = re.findall(r"rhel-\d", tag)[0].split('-')[1]
    virtio_win_version = "el%s" % main_version
    logger.info('virtio_win_version is %s' % virtio_win_version)

    update_virtio_win_package = UpdateVirtioWin(
        tag, packagename, virtio_win_version, nfspath, workdir, nfsserver, decompressed_dir)
    update_virtio_win_package.update_virtio_win()
    content = content.replace('NFS_SERVER', update_virtio_win_package.nfsserver)
    name_list = update_virtio_win_package.virtio_win_name_list

    logger.debug("*" * 100)

    virtio_list = []
    virtio_list.extend(name_list)
    
    if virtio_list:
        content = content.replace('VIRTIO_WIN', ' '.join(virtio_list))
        # mail_sent(notification_list, subject, content, sender)

if __name__ == '__main__':
    logcfgfile = 'logfile.cfg'
    logging.config.fileConfig(os.path.join(os.path.dirname(__file__), logcfgfile))
    logger = logging.getLogger('root')
    main()
