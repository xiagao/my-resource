#!/usr/bin/env groovy
import groovy.json.JsonSlurper

def parseComposeInfo(String cID, String cBuildType) {
    def url = "http://download.lab.bos.redhat.com/"+cBuildType+"/"+cID+"/compose/metadata/composeinfo.json";
    def composeInfo = ["url": url]
    def jsonContent = new URL(url).getText('UTF-8')
    def slurper = new groovy.json.JsonSlurper()
    def info = slurper.parseText(jsonContent)
    def release
    def server
    if ( info.get("payload", {}).containsKey('product') ) {
        release = info.get("payload", {}).get("product", {})
    } else {
        release = info.get("payload", {}).get("release", {})
    }
    composeInfo.put("product", release.get("short", {}))
    composeInfo.put("version", release.get("version", {}))
    if ( info.get("payload", {}).get("variants", {}).containsKey('Server') ) {
        server = info.get("payload", {}).get("variants", {}).get("Server", {})
    } else {
        server = info.get("payload", {}).get("variants", {}).get("BaseOS", {})
    }
    composeInfo.put("arches", server.get("arches", ""))
    return composeInfo
}

def containArch(def arch, def archList) {
    return archList.contains(arch)
}

@NonCPS
def getComposeVersion(String text) {
    def matcher = text =~ /(\d+\.?\d*)/
    matcher ? matcher[0][1] : null
}

def parseBrewTagInfo(String brewTagMsg) {
    def brewTagInfo = [:]
    def slurper = new groovy.json.JsonSlurper()
    def info = slurper.parseText(brewTagMsg)
    brewTagInfo.put("BREW_TASKID", info.get("build", {}).get("task_id", {}).toString())
    brewTagInfo.put("BREW_BUILDID", info.get("build", {}).get("id", {}).toString())
    brewTagInfo.put("BREW_TAG", info.get("tag", {}).get("name", {}))
    brewTagInfo.put("BREW_OWNER", info.get("build", {}).get("owner_name", {}))
    brewTagInfo.put("BREW_NVR", info.get("build", {}).get("nvr", {}))
    brewTagInfo.put("BREW_PKGNAME", info.get("build", {}).get("package_name", {}))
    brewTagInfo.put("BREW_VERSION", info.get("build", {}).get("version", {}))
    brewTagInfo.put("BREW_RELEASE", info.get("build", {}).get("release", {}))
    /*
    There is a field called 'arches' in 'tag'. For qemu-kvm-rhev, it shows
    the supported architectures correctly. However it always show null for
    qemu-kvm. So we can't get it through info.get("tag", {}).get("arches", {})
    */
    brewTagInfo.put("BREW_ARCHES", info.get("rpms", {}).keySet())
    return brewTagInfo
}

def getDependTag(String osVersion, String brewTag, String brewNvr) {
    def tagPrefix = 'rhel'
    def tagZ = '-'
    if (osVersion.contains("alt")) {
        tagPrefix = 'rhel-alt'
    }
    def tagVersion = getComposeVersion(brewTag)
    def matcher = brewNvr =~ /\.el(\d+_\d*)/
    if (matcher) {
        tagZ = '-z-'
    }
    def dependTag = "${tagPrefix}-${tagVersion}${tagZ}candidate"
    if (osVersion.startsWith("el6")) {
        dependTag = dependTag.replaceAll("rhel", "RHEL").replaceAll("-z-","-Z-")
    }
    return dependTag
}

def getRepos(String dependTag) {
    def topUrl = "http://download.devel.redhat.com/rel-eng/repos"
    def repos = ""
    logging.info("Try to get the latest yum repo of tag '${dependTag}'")
    def repoUrl = "${topUrl}/${dependTag}"
    def out = sh(returnStdout: true, script: "curl -skL ${repoUrl}").trim()
    if (out.contains("404 Not Found")) {
        logging.warn("Tag '${dependTag}' is too new to have a yum repo")
    } else {
        repos = "${repoUrl}/\$basearch"
    }
    dependTag = dependTag.replaceAll("-z", "-Z")
    if (dependTag.contains("-Z")) {
        dependYTag = dependTag.replaceAll("-Z","")
    } else {
        return repos
    }
    repoUrl = "${topUrl}/${dependYTag}"
    out = sh(returnStdout: true, script: "curl -skL ${repoUrl}").trim()
    if (out.contains("404 Not Found")) {
        logging.warn("Yum repo for tag '${dependYTag}' doesn't exist or can't be accessed")
    } else if (repos) {
        repos = "${repos};${repoUrl}/\$basearch"
    }
    else {
        repos = "${repoUrl}/\$basearch"
    }
    return repos
}

def bkrDistroTreesList(String distroFamily, String distroName, String distroTag) {
    def out = ""
    def cmd = "/usr/bin/bkr distro-trees-list"
    cmd = "${cmd} --family=${distroFamily} --name=${distroName} --tag=${distroTag}"
    if (env.LAB_CONTROLLER) {
        cmd = "${cmd} --labcontroller=${env.LAB_CONTROLLER}"
    }
    cmd = "${cmd} --hub=${env.HUB_URL} --limit=1 --format=json"
    try {
        out = sh(returnStdout: true, script: "${cmd}").trim()
    } catch (Exception ex) {
        logging.warn("Failed to get a valid tree for distro(${distroName}) with tag(${distroTag}), error message:\n${ex}")
        return null
    }
    def slurper = new groovy.json.JsonSlurper()
    def distroTreeInfo = slurper.parseText(out)
    return distroTreeInfo[0].get("distro_name", "")
}

def findDistro(String distroPrefix, String distroFamilyPrefix, String distroVersionMajor, String distroVersionMinor, Boolean enableNightly = false) {
    def distroFamily = "${distroFamilyPrefix}${distroVersionMajor}"
    def listName = ["${distroPrefix}%${distroVersionMajor}.${distroVersionMinor}", "${distroPrefix}%${distroVersionMajor}.${distroVersionMinor}-________._"]
    def listTag = ['RELEASED', 'RTT_ACCEPTED']
    def validDistro = null
    if (enableNightly) {
        listName.add("${distroPrefix}%${distroVersionMajor}.${distroVersionMinor}-________._._")
        listTag.add('RTT_PASSED')
    }
    for(int i =0; i < listName.size(); i++) {
        validDistro = bkrDistroTreesList(distroFamily, listName[i], listTag[i])
        if (validDistro) {
            break
        }
    }
    return validDistro
}

def getComposeID(String brewTag, String osVersion, Boolean enableNightly = false) {
    if (sh(returnStatus: true, script: "command -v bkr") != 0 ) {
        logging.warn("Package 'beaker-client' is not installed")
        return null
    }
    def distroPrefix = 'RHEL'
    def distroFamilyPrefix = 'RedHatEnterpriseLinux'
    if (osVersion.contains("alt")) {
        distroPrefix = 'RHEL-ALT'
        distroFamilyPrefix = 'RedHatEnterpriseLinuxAlternateArchitectures'
    }
    def distroVersion = getComposeVersion(brewTag)
    def distroVersionMajor = distroVersion.split('\\.')[0]
    def distroVersionMinor = distroVersion.split('\\.')[1]
    def composeID = findDistro(distroPrefix, distroFamilyPrefix, distroVersionMajor, distroVersionMinor, enableNightly)
    return composeID ? composeID : findDistro(distroPrefix, distroFamilyPrefix, distroVersionMajor, --distroVersionMinor, enableNightly)
}
