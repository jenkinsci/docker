## Variables
variable "java_releases_to_build" {
  default = [21, 25]
}

variable "windows_version_to_build" {
  default = ["ltsc2022", "ltsc2025"]
}

variable "default_java_release" {
  default = 21
}

variable "JENKINS_VERSION" {
  default = "2.587"
}

variable "WAR_URL" {
  default = ""
}

variable "REGISTRY" {
  default = "docker.io"
}

variable "JENKINS_REPO" {
  default = "jenkins/jenkins"
}

variable "LATEST_WEEKLY" {
  default = "false"
}

variable "LATEST_LTS" {
  default = "false"
}

variable "PLUGIN_CLI_VERSION" {
  default = "2.15.0"
}

variable "COMMIT_SHA" {
  default = ""
}

variable "ALPINE_FULL_TAG" {
  default = "3.24.3"
}

variable "ALPINE_SHORT_TAG" {
  default = regex_replace(ALPINE_FULL_TAG, "\\.\\d+$", "")
}

variable "DEBIAN_RELEASE_LINE" {
  default = "trixie"
}

variable "DEBIAN_VERSION" {
  default = 20261020
}

variable "RHEL_TAG" {
  default = "9.8-1793179168"
}

variable "RHEL_RELEASE_LINE" {
  default = "ubi9"
}

# Set this value to a specific Windows version to override Windows versions to build returned by windowsversions function
variable "WINDOWS_VERSION_OVERRIDE" {
  default = ""
}

# Set this value to a specific version to override java release to build
variable "JAVA_RELEASE_OVERRIDE" {
  default = ""
}

variable "debian_variants" {
  default = ["debian", "debian-slim"]
}

variable "current_rhel" {
  default = "rhel-${RHEL_RELEASE_LINE}"
}

## Targets
target "alpine" {
  matrix = {
    java_release = java_releases(JAVA_RELEASE_OVERRIDE)
  }
  name       = "alpine_jdk${java_release}"
  dockerfile = "alpine/hotspot/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    WAR_URL            = war_url()
    COMMIT_SHA         = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
    ALPINE_TAG         = ALPINE_FULL_TAG
    JAVA_RELEASE       = java_release
  }
  tags      = linux_tags("alpine", java_release)
  platforms = platforms("alpine", java_release)
}

target "debian" {
  matrix = {
    java_release = java_releases(JAVA_RELEASE_OVERRIDE)
    variant      = debian_variants
  }
  name       = "${variant}_jdk${java_release}"
  dockerfile = "debian/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION     = JENKINS_VERSION
    WAR_URL             = war_url()
    COMMIT_SHA          = COMMIT_SHA
    PLUGIN_CLI_VERSION  = PLUGIN_CLI_VERSION
    DEBIAN_RELEASE_LINE = DEBIAN_RELEASE_LINE
    DEBIAN_VERSION      = DEBIAN_VERSION
    DEBIAN_VARIANT      = is_debian_slim(variant) ? "-slim" : ""
    JAVA_RELEASE        = java_release
  }
  tags      = linux_tags(variant, java_release)
  platforms = platforms(variant, java_release)
}

target "rhel" {
  matrix = {
    java_release    = java_releases(JAVA_RELEASE_OVERRIDE)
  }
  name       = "rhel_jdk${java_release}"
  dockerfile = "rhel/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    WAR_URL            = war_url()
    COMMIT_SHA         = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
    RHEL_TAG           = RHEL_TAG
    RHEL_RELEASE_LINE  = RHEL_RELEASE_LINE
    JAVA_RELEASE       = java_release
  }
  tags      = linux_tags(current_rhel, java_release)
  platforms = platforms(current_rhel, java_release)
}

target "windowsservercore" {
  matrix = {
    java_release    = java_releases_to_build
    windows_version = windowsversions()
  }
  name       = "windowsservercore-${windows_version}_jdk${java_release}"
  dockerfile = "windows/windowsservercore/hotspot/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    WAR_URL            = war_url()
    COMMIT_SHA         = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
    JAVA_HOME          = "C:/openjdk-${java_release}"
    WINDOWS_VERSION    = windows_version
    JAVA_RELEASE       = java_release
  }
  tags      = windows_tags("windowsservercore-${windows_version}", java_release)
  platforms = ["windows/amd64"]
}

## Groups
group "linux" {
  targets = [
    "alpine",
    "debian",
    "rhel",
  ]
}

group "windows" {
  targets = [
    "windowsservercore"
  ]
}

group "all" {
  targets = [
    "linux",
    "windows",
  ]
}

## Common functions
# return true if JENKINS_VERSION is a Weekly (one sequence of digits with a trailing literal '.')
function "is_jenkins_version_weekly" {
  # If JENKINS_VERSION has more than one sequence of digits with a trailing literal '.', this is LTS
  # 2.523 has only one sequence of digits with a trailing literal '.'
  # 2.516.1 has two sequences of digits with a trailing literal '.'
  params = []
  result = length(regexall("[0-9]+[.]", JENKINS_VERSION)) < 2 ? true : false
}

# return a tag prefixed by the Jenkins version
function "_tag_jenkins_version" {
  params = [tag]
  result = notequal(tag, "") ? "${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}-${tag}" : "${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}"
}

# return a tag optionally prefixed by the Jenkins version
function "tag" {
  params = [prepend_jenkins_version, tag]
  result = equal(prepend_jenkins_version, true) ? _tag_jenkins_version(tag) : "${REGISTRY}/${JENKINS_REPO}:${tag}"
}

# return a weekly optionally prefixed by the Jenkins version
function "tag_weekly" {
  params = [prepend_jenkins_version, tag]
  result = equal(LATEST_WEEKLY, "true") ? tag(prepend_jenkins_version, tag) : ""
}

# return a LTS optionally prefixed by the Jenkins version
function "tag_lts" {
  params = [prepend_jenkins_version, tag]
  result = equal(LATEST_LTS, "true") ? tag(prepend_jenkins_version, tag) : ""
}

# return WAR_URL if not empty, get.jenkins.io URL depending on JENKINS_VERSION release line otherwise
function "war_url" {
  params = []
  result = (notequal(WAR_URL, "")
    ? WAR_URL
    : (is_jenkins_version_weekly()
      ? "https://get.jenkins.io/war/${JENKINS_VERSION}/jenkins.war"
  : "https://get.jenkins.io/war-stable/${JENKINS_VERSION}/jenkins.war"))
}

# Return "true" if the jdk passed as parameter is the same as the default jdk, "false" otherwise
function "is_default_java_release" {
  params = [java_release]
  result = equal(default_java_release, java_release) ? true : false
}

# Return array of java releases to build
# Can be overriden to a specific version
function "java_releases" {
  params = [override]
  result = (notequal(override, "")
    ? [parseint(override, 10)]
  : java_releases_to_build)
}

# Return an array of platforms depending on the distribution and the jdk
function "platforms" {
  params = [distribution, jdk]
  result = (
    # Alpine
    is_alpine(distribution)
    ? ["linux/amd64", "linux/arm64"]

    # Debian slim
    : is_debian_slim(distribution)
    ? ["linux/amd64", "linux/arm64", "linux/riscv64"]

    # RHEL
    : is_rhel(distribution)
    ? ["linux/amd64", "linux/arm64", "linux/ppc64le"]

    # Default (Debian)
    : ["linux/amd64", "linux/arm64", "linux/s390x", "linux/ppc64le", "linux/riscv64"]
  )
}

# Return an array of tags for linux images depending on the distribution and the jdk
function "linux_tags" {
  params = [distribution, jdk]
  result = (
    ## Debian variants
    is_debian_variant(distribution)
    ? debian_tags(distribution, jdk)

    : [
      ## Always publish explicit jdk tag
      tag(true, "${distribution}-jdk${jdk}"),
      tag_weekly(false, "${distribution}-jdk${jdk}"),
      tag_lts(false, "lts-${distribution}-jdk${jdk}"),

      # Special case for Alpine
      is_alpine(distribution) ? tag_weekly(false, "alpine${ALPINE_SHORT_TAG}-jdk${jdk}") : "",

      # Special case for RHEL
      is_rhel(distribution) ? tag_lts(true, "lts-${distribution}-jdk${jdk}") : "",

      ## Default JDK extra short tags (except for current rhel)
      is_default_java_release(jdk) && !is_rhel(distribution) ? tag(true, distribution) : "",
      is_default_java_release(jdk) && !is_rhel(distribution) ? tag_weekly(false, distribution) : "",
      is_default_java_release(jdk) && !is_rhel(distribution) ? tag_lts(false, "lts-${distribution}") : "",
      is_default_java_release(jdk) && !is_rhel(distribution) ? tag_lts(true, "lts-${distribution}") : "",
    ]
  )
}

# Return an array of tags depending on the agent type, the jdk
# and the flavor and version of Windows passed as parameters (ex: windowsservercore-ltsc2022)
function "windows_tags" {
  params = [distribution, jdk]
  result = [
    ## Always publish explicit jdk tag
    tag(true, "jdk${jdk}-hotspot-${distribution}"),
    tag_weekly(false, "jdk${jdk}-hotspot-${distribution}"),
    tag_lts(false, "lts-jdk${jdk}-hotspot-${distribution}"),

    ## Default JDK extra short tags
    is_default_java_release(jdk) ? tag(true, "hotspot-${distribution}") : "",
    is_default_java_release(jdk) ? tag_weekly(false, distribution) : "",
    is_default_java_release(jdk) ? tag_weekly(true, distribution) : "",
    is_default_java_release(jdk) ? tag_lts(false, "lts-${distribution}") : "",
    is_default_java_release(jdk) ? tag_lts(true, distribution) : "",
  ]
}

# Return if the distribution passed in parameter is Alpine
function "is_alpine" {
  params = [distribution]
  result = equal("alpine", distribution)
}

# Return if the distribution passed in parameter is Alpine
function "is_rhel" {
  params = [distribution]
  result = equal(current_rhel, distribution)
}

# Return if the distribution passed in parameter is a debian variant
function "is_debian_variant" {
  params = [distribution]
  result = contains(debian_variants, distribution)
}

# Return if the variant passed in parameter is the debian slim one
function "is_debian_slim" {
  params = [variant]
  result = equal("debian-slim", variant)
}

# Return text prefixed with "slim-" if the variant passed in parameter is the slim one
# Return only "slim" if the text passed in parameter is empty or "latest"
function "slim_prefix" {
  params = [variant, text]
  result = (is_debian_slim(variant)
    ? (equal("", text) || equal("latest", text) ? "slim" : "slim-${text}")
  : text)
}

# Return text suffixed with "-slim" if the variant passed in parameter is the slim one
# Return only "slim" if the text passed in parameter is empty
function "slim_suffix" {
  params = [variant, text]
  result = (is_debian_slim(variant)
    ? (equal("", text) ? "slim" : "${text}-slim")
  : text)
}

# Return an array of tags for debian images depending on the variant and the jdk passed as parameters
function "debian_tags" {
  params = [variant, jdk]
  result = [
    ## Default tags including jdk
    tag(true, slim_prefix(variant, "jdk${jdk}")),
    tag_weekly(false, slim_prefix(variant, "jdk${jdk}")),
    tag_lts(false, "${slim_suffix(variant, "lts")}-jdk${jdk}"),
    # Tags for debian only
    is_debian_slim(variant) ? "" : tag_weekly(false, slim_prefix(variant, "latest-jdk${jdk}")),
    is_debian_slim(variant) ? "" : tag_lts(true, "${slim_suffix(variant, "lts")}-jdk${jdk}"),

    ## If default jdk, short tags
    is_default_java_release(jdk) ? tag(true, slim_prefix(variant, "")) : "",
    is_default_java_release(jdk) ? tag_weekly(false, slim_prefix(variant, "latest")) : "",
    is_default_java_release(jdk) ? tag_lts(false, slim_suffix(variant, "lts")) : "",
    is_default_java_release(jdk) ? tag_lts(true, slim_suffix(variant, "lts")) : "",
  ]
}

# Return array of Windows version(s) to build
# Can be overridden by setting WINDOWS_VERSION_OVERRIDE to a specific Windows version
# Ex: WINDOWS_VERSION_OVERRIDE=ltsc2025 docker buildx bake windows
function "windowsversions" {
  params = []
  result = notequal(WINDOWS_VERSION_OVERRIDE, "") ? [WINDOWS_VERSION_OVERRIDE] : windows_version_to_build
}
