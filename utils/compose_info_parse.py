#!/usr/bin/env python

import os
import json
import sys
import urllib2

PROPERTY_FILE = os.path.join(os.environ.get('WORKSPACE'),
                             'compose-info.properties')

ctype = sys.argv[1]
build = sys.argv[2]
url = "http://download.lab.bos.redhat.com/%s/%s/" % (ctype, build)

composeinfo = json.load(
    urllib2.urlopen(url+"/compose/metadata/composeinfo.json"))
if composeinfo.get("payload", {}).get("product", {}):
    release = composeinfo.get("payload", {}).get("product", {})
else:
    release = composeinfo.get("payload", {}).get("release", {})
product = release.get("short", {})
version = release.get("version", {})
arches = composeinfo.get("payload", {}).get("variants", {}).get("Server", {}).get("arches", "")

with open(PROPERTY_FILE, 'w') as f:
    f.write("COMPOSE_ID=" + build + "\n")
    f.write("COMPOSE_URL=" + url + "\n")
    f.write("COMPOSE_PRODUCT=" + product + "\n")
    f.write("COMPOSE_VERSION=" + version + "\n")
    f.write("COMPOSE_ARCHES=" + ','.join(map(str, arches)) + "\n")
