#!/usr/bin/env python
import os
import re
import sys

from optparse import OptionParser

RHEL_TAGS = {
    "<= 6": ("RHEL-{0}.{1}-Z-candidate", "RHEL-{0}.{1}-candidate"),
    "> 6": ("rhel-{0}.{1}-z-candidate", "rhel-{0}.{1}-candidate",
            "rhel-alt-{0}.{1}-z-candidate", "rhel-alt-{0}.{1}-candidate")
}

parser = OptionParser()
parser.add_option("-t", "--tag", dest="tag", help="tag", default=None)
parser.add_option("-n", "--nvr", dest="nvr", help="nvr", default=None)
(opts, args) = parser.parse_args()

tag = opts.tag or os.environ.get("TAG") or sys.exit(1)
nvr = opts.nvr or os.environ.get("NVR") or sys.exit(1)
compose_prefix = "RHEL"
if args:
    compose_prefix = args[0]
rel = re.search(r"rhel-(\d)+\.(\d)+", tag, re.I)
if not rel:
    sys.exit(1)
x = rel.group(1)
y = rel.group(2)
is_not_z = not bool(re.search(r"el{0}_{1}".format(x, y), nvr))
is_alt = bool("alt" in compose_prefix.lower())

for rt in RHEL_TAGS.keys():
    if eval(x + rt):
        print(RHEL_TAGS[rt][is_alt * 2 + is_not_z + 0].format(x, y))
