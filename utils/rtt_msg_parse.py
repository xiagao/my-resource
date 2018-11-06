import json
import os
import sys


PROPERTY_FILE = os.path.join(os.environ.get('WORKSPACE'),
                             'rtt-msg.properties')

RTT_MSG = os.environ.get('CI_MESSAGE')
if RTT_MSG is None:
    sys.stderr.write("No CI message!")
    sys.exit(1)
data = json.loads(RTT_MSG)

build = data['build']
build_url = data['build_url']
product = data['product']
version = data['version']
arches = list(data['arches'])
tags = list(data['bkr_info']['distro_tags'])

with open(PROPERTY_FILE, 'w') as f:
    f.write("COMPOSE_ID=" + build + "\n")
    f.write("COMPOSE_URL=" + build_url + "\n")
    f.write("COMPOSE_PRODUCT=" + product + "\n")
    f.write("COMPOSE_VERSION=" + version + "\n")
    f.write("COMPOSE_ARCHES=" + ','.join(map(str, arches)) + "\n")
    f.write("COMPOSE_TAGS=" + ','.join(map(str, tags)) + "\n")
