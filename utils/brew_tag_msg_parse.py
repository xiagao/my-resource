import json
import os
import sys


PROPERTY_FILE = os.path.join(os.environ.get('WORKSPACE'),
                             'brew-tag-msg.properties')

BREW_TAG_MSG = os.environ.get('CI_MESSAGE')
if BREW_TAG_MSG is None:
    sys.stderr.write("No CI message!")
    sys.exit(1)
data = json.loads(BREW_TAG_MSG)

owner = data['build']['owner_name']
pkgname = data['build']['package_name']
nvr = data['build']['nvr']
brew_taskid = str(data['build']['task_id'])
brew_buildid = str(data['build']['id'])
tag = data['tag']['name']
version = data['build']['version']
release = data['build']['release']
arches = data['rpms'].keys()

with open(PROPERTY_FILE, 'w') as f:
    f.write("BREW_TASKID=" + brew_taskid + "\n")
    f.write("BREW_BUILDID=" + brew_buildid + "\n")
    f.write("BREW_TAG=" + tag + "\n")
    f.write("BREW_OWNER=" + str(owner) + "\n")
    f.write("BREW_NVR=" + nvr + "\n")
    f.write("BREW_PKGNAME=" + pkgname + "\n")
    f.write("BREW_VERSION=" + version + "\n")
    f.write("BREW_RELEASE=" + release + "\n")
    f.write("BREW_ARCHES=" + ','.join(map(str, arches)) + "\n")
