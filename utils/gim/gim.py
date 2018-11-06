'''
Guest ISO Manager (GIM)
'''
import os
import re
import threading
import traceback
import logging

from collections import namedtuple
from hashlib import md5
from logging.handlers import RotatingFileHandler
from urllib import urlretrieve
from urllib2 import urlopen


_Compose = namedtuple(
    'Compose',
    [
        'build',        # Build name,       e.g. 'RHEL-7.3-20161019.0'
        'product',      # Product name,     e.g. 'RHEL'
        'version',      # Version name,     e.g. '7.3'
        'release',      # Release name,     e.g. '20161019.0'
        'variant',      # Variant name,     e.g. 'Server'
        'arch',         # Arch name,        e.g. 'x86_64'
        'is_nightly',   # Nightly build?,   e,g. False
    ]
)


class ComposeAttrError(Exception):

    pass


def Compose(build, variant, arch):
    build_info = re.match(r'(\S+?)-?(\d+\.\d+)-(\d{8}\.(n\.)?\d+)', build)

    # FIXME: support other variants if possible
    if variant not in ['Server', 'BaseOS']:
        raise ComposeAttrError("Invalid variant name '{0}'".format(variant))

    # FIXME: better to check this with the combination of product and variant
    if arch not in ['i386', 'aarch64', 'ppc64', 'ppc64le', 'x86_64', 's390x']:
        raise ComposeAttrError("Invalid arch name '{0}'".format(arch))

    if not build_info:
        raise ComposeAttrError("Invalid build name '{0}'".format(build))

    product, version, release, is_nightly = build_info.groups()
    return _Compose(build, product, version, release,
                    variant, arch, bool(is_nightly))


class GuestISOManager(object):

    def __init__(self, top_url, isos_dir, keep_old, nightly_first, log_path):
        self.top_url = top_url
        self.isos_dir = os.path.abspath(isos_dir)
        self.keep_old = keep_old
        self.nightly_first = nightly_first

        self.gim_mutex_lock = threading.Lock()

        self.logger = logging.getLogger('gim')
        self.logger.setLevel(logging.INFO)
        self.log_path = log_path
        log_handler = RotatingFileHandler(
            self.log_path, maxBytes=1024*1024, backupCount=0)
        log_handler.setLevel(logging.INFO)
        log_handler.setFormatter(logging.Formatter(
            'Thread: %(threadName)s\n'
            'Date:   %(asctime)s\n'
            'Level:  %(levelname)s\n'
            'Message:\n%(message)s\n',
            datefmt='%d/%m/%Y %H:%M:%S'))
        self.logger.addHandler(log_handler)
        self.logger.info('Service started')

    @staticmethod
    def get_symlink_name(compose):
        return '{product}{version}-{variant}-{arch}.iso'.format(
            **compose._asdict())

    def _get_symlink_path(self, compose):
        return os.path.join(self.isos_dir, self.get_symlink_name(compose))

    def need_to_update(self, compose):

        def release_numeric(release_str):
            return float(re.sub(r'n\.', '', release_str))

        symlink_path = self._get_symlink_path(compose)
        if not os.path.lexists(symlink_path):
            return True
        if not os.path.exists(os.path.realpath(symlink_path)):
            return True

        cur_release = 0
        cur_is_nightly = False
        cur_info = re.search(r'(\d{8}\.(n\.)?\d+)',
                             os.path.basename(os.path.realpath(symlink_path)))
        if cur_info:
            cur_release = cur_info.group(1)
            cur_is_nightly = bool(cur_info.group(2))
        if compose.is_nightly != cur_is_nightly:
            if compose.is_nightly and self.nightly_first:
                return True
        if release_numeric(compose.release) > release_numeric(cur_release):
            return True

        return False

    def _update_iso_image(self, compose):

        def get_iso_top_url(compose):
            work_dir = 'nightly' if compose.is_nightly else 'rel-eng'
            url_pattern = '/'.join(['{top_url}',
                                    work_dir,
                                    '{build}',
                                    'compose',
                                    '{variant}',
                                    '{arch}',
                                    'iso/'])
            return url_pattern.format(
                top_url=self.top_url, **compose._asdict())

        def get_iso_name(iso_top_url):
            iso_info = urlopen(iso_top_url).read()
            iso = re.search(r'href="(\S+dvd1\.iso)"', iso_info, re.M)
            if not iso:
                raise IOError("Could not find dvd1 in '{0}'".format(
                    iso_top_url))
            return iso.group(1)

        def download_iso(iso_url, iso_path, validate=True):
            urlretrieve(iso_url, iso_path)
            if not validate:
                return

            ori_md5_url = '{0}.MD5SUM'.format(iso_url)
            ori_md5_info = urlopen(ori_md5_url).read()
            ori_md5 = re.search(r'[0-9a-f]{32}', ori_md5_info)
            if not ori_md5:
                raise IOError("Could not find original MD5SUM")
            ori_md5_hex = ori_md5.group(0)

            iso_md5 = md5()
            with open(iso_path, 'rb') as iso_file:
                for buf in iter(lambda: iso_file.read(4096), b''):
                    iso_md5.update(buf)
            iso_md5_hex = iso_md5.hexdigest()

            if iso_md5_hex != ori_md5_hex:
                raise AssertionError("MD5 checksum did not match")

        def update_symlink(iso_path, symlink_path):
            old_iso_path = ''
            iso_name = os.path.basename(iso_path)

            if os.path.lexists(symlink_path):
                old_iso_path = os.path.realpath(symlink_path)
                os.remove(symlink_path)
            os.symlink(iso_name, symlink_path)

            if (not self.keep_old) and os.path.exists(old_iso_path) \
                    and (os.path.basename(old_iso_path) != iso_name):
                os.remove(old_iso_path)

        iso_path = ''
        iso_top_url = get_iso_top_url(compose)
        symlink_path = self._get_symlink_path(compose)
        iso_validate = True

        try:
            iso_name = get_iso_name(iso_top_url)
            iso_path = os.path.join(self.isos_dir, iso_name)
            download_iso('{0}/{1}'.format(iso_top_url, iso_name),
                         iso_path, iso_validate)
            update_symlink(iso_path, symlink_path)
        except:
            self.logger.error(traceback.format_exc())
            if os.path.exists(iso_path):
                os.remove(iso_path)
            return False

        return True

    def get_all_tasks(self):
        return [t.name for t in threading.enumerate()
                if t.name.startswith('task')]

    def has_task(self, compose):
        return bool([tname for tname in self.get_all_tasks()
                     if self.get_symlink_name(compose) in tname])

    def submit_task(self, compose):
        if not self.need_to_update(compose):
            return False

        with self.gim_mutex_lock:
            if self.has_task(compose):
                return False
            try:
                threading.Thread(
                    target=self._update_iso_image,
                    args=(compose,),
                    name="task/{0}/{1}".format(self.get_symlink_name(compose),
                                               compose.build)
                ).start()
            except:
                return False

            return True

    def read_log(self):
        with open(self.log_path, 'r') as log_file:
            return log_file.read()

    def list_isos_dir(self):
        raise NotImplementedError()
