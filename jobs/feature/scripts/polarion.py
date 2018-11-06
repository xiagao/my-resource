#!/usr/bin/env python
import os
import sys
import datetime
import re
import hashlib
import random
import ssl

from pylarion.test_run import TestRun

ssl._create_default_https_context = ssl._create_unverified_context
TEMPLATE_FORMAT = "virtkvmqe-{category}-automation"
TESTRUN_FORMAT = "virtkvmqe-{arch}-{category}-{qemu_version}-{datetime}-{unique_id}"
PROPERTY_FILE = os.path.join(os.environ.get('WORKSPACE'), 'polarion.properties')

def create_unique_testrun_id():
    """
    Create a 8 digit hex number to be used as a testrun ID string.
    (similar to SHA1)

    :return: 8 digit hex number string
    :rtype: str
    """
    _RAND_POOL = random.SystemRandom()
    return hashlib.sha1(hex(_RAND_POOL.getrandbits(160)).encode()).hexdigest()[:7]

if __name__ == '__main__':
    if len(sys.argv) != 7:
        print "Usage: python polarion.py [arch] [component] [qemu-version] [tag] [category] [description]"
        sys.exit(1)
    rhel_version = re.search(r"rhel-(\d+\.\d+)", sys.argv[4], re.I).group(1)
    component = sys.argv[2]
    if rhel_version.startswith('6'):
        project_id = "RHEL6"
        component = "qemu-kvm"
        user_name = "rhel6_machine"
    if rhel_version.startswith('7'):
        project_id = "RedHatEnterpriseLinux7"
        user_name = "rhel7_machine"
    arch = "x86"
    if sys.argv[1].startswith('x86'):
        arch = "x86"
        arch_list = "x8664"
    if sys.argv[1].startswith('ppc'):
        arch = "ppc"
        arch_list = "ppc64le"
    if sys.argv[1].startswith('aarch'):
        arch = "aarch"
        arch_list = "aarch64"
    testrun_template_id = TEMPLATE_FORMAT.format(
        category=re.sub(r'[\s".""/"]',"_",sys.argv[5])
    )
    testrun_id = TESTRUN_FORMAT.format(
        arch=arch,
        category=re.sub(r'[\s".""/"]',"_",sys.argv[5]),
        qemu_version=sys.argv[3].replace(".", "-"),
        datetime=datetime.datetime.now().strftime('%Y-%m-%d-%H-%M-%S'),
        unique_id=create_unique_testrun_id()
    )
    testrun_root_url = "https://polarion.engineering.redhat.com/polarion/#/project/%s/testrun?id=" % project_id
    url = testrun_root_url + testrun_id
    print "Using template:", testrun_template_id
    print "Creating test run:", testrun_id
    print "Link of test run:", url
    testrun_title = testrun_id
    tr = TestRun.create(project_id, testrun_id, testrun_template_id, testrun_title)
    with open(PROPERTY_FILE, 'w') as f:
        f.write("TESTRUN_LINK=" + url + "\n")
    tr.description = sys.argv[6]
    tr.arch = arch_list
    component_list = []
    component_list.append(component)
    tr.component = component_list
    tr.isautomated = True
    tr.update()
    for rec in tr.records:
        tr.update_test_record_by_fields(
            rec.test_case_id,
            test_result='passed',
            test_comment="",
            executed_by=user_name,
            executed=datetime.datetime.now(),
            duration=None
        )
    tr.update()
