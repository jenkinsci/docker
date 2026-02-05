## Variables
variable "jdks_to_build" {
  default = [21, 25]
}

variable "windows_version_to_build" {
  default = ["windowsservercore-ltsc2019", "windowsservercore-ltsc2022"]
}

variable "default_jdk" {
  default = 21
}

variable "JENKINS_VERSION" {
  default = "2.549"
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
  default = "2.14.0"
}

variable "COMMIT_SHA" {
  default = ""
}

variable "ALPINE_FULL_TAG" {
  default = "3.23.3"
}

variable "ALPINE_SHORT_TAG" {
  default = regex_replace(ALPINE_FULL_TAG, "\\.\\d+$", "")
}

variable "JAVA17_VERSION" {
  default = "17.0.18_8"
}

variable "JAVA21_VERSION" {
  default = "21.0.10_7"
}

variable "JAVA25_VERSION" {
  default = "25.0.2_10"
}

variable "DEBIAN_RELEASE_LINE" {
  default = "trixie"
}

variable "DEBIAN_VERSION" {
  default = "20251117"
}

variable "RHEL_TAG" {
  default = "9.7-1770238273"
}

variable "RHEL_RELEASE_LINE" {
  default = "ubi9"
}

# Set this value to a specific Windows version to override Windows versions to build returned by windowsversions function
variable "WINDOWS_VERSION_OVERRIDE" {
  default = ""
}

## Internal variables
variable "jdk_versions" {
  default = {
    17 = JAVA17_VERSION
    21 = JAVA21_VERSION
    25 = JAVA25_VERSION
  }
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
    jdk = jdks_to_build
  }
  name       = "alpine_jdk${jdk}"
  dockerfile = "alpine/hotspot/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    WAR_URL            = war_url()
    COMMIT_SHA         = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
    JAVA_VERSION       = javaversion(jdk)
    ALPINE_TAG         = ALPINE_FULL_TAG
  }
  tags      = linux_tags("alpine", jdk)
  platforms = platforms("alpine", jdk)
}

target "debian" {
  matrix = {
    jdk     = jdks_to_build
    variant = debian_variants
  }
  name       = "${variant}_jdk${jdk}"
  dockerfile = "debian/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION     = JENKINS_VERSION
    WAR_URL             = war_url()
    COMMIT_SHA          = COMMIT_SHA
    PLUGIN_CLI_VERSION  = PLUGIN_CLI_VERSION
    JAVA_VERSION        = javaversion(jdk)
    DEBIAN_RELEASE_LINE = DEBIAN_RELEASE_LINE
    DEBIAN_VERSION      = DEBIAN_VERSION
    DEBIAN_VARIANT      = is_debian_slim(variant) ? "-slim" : ""
  }
  tags      = linux_tags(variant, jdk)
  platforms = platforms(variant, jdk)
}

target "rhel" {
  matrix = {
    jdk = jdks_to_build
  }
  name       = "rhel_jdk${jdk}"
  dockerfile = "rhel/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    WAR_URL            = war_url()
    COMMIT_SHA         = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
    JAVA_VERSION       = javaversion(jdk)
    RHEL_TAG           = RHEL_TAG
    RHEL_RELEASE_LINE  = RHEL_RELEASE_LINE
  }
  tags      = linux_tags(current_rhel, jdk)
  platforms = platforms(current_rhel, jdk)
}

target "windowsservercore" {
  matrix = {
    jdk             = jdks_to_build
    windows_version = windowsversions()
  }
  name       = "${windows_version}_jdk${jdk}"
  dockerfile = "windows/windowsservercore/hotspot/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    WAR_URL            = war_url()
    COMMIT_SHA         = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
    JAVA_VERSION       = javaversion(jdk)
    JAVA_HOME          = "C:/openjdk-${jdk}"
    WINDOWS_VERSION    = windows_version
  }
  tags      = windows_tags(windows_version, jdk)
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
function "is_default_jdk" {
  params = [jdk]
  result = equal(default_jdk, jdk) ? true : false
}

# Return the complete Java version corresponding to the jdk passed as parameter
function "javaversion" {
  params = [jdk]
  result = lookup(jdk_versions, jdk, "Unsupported JDK version")
}

# Return an array of platforms depending on the distribution and the jdk
function "platforms" {
  params = [distribution, jdk]
  result = (
    # Alpine
    is_alpine(distribution)
    ? (equal(17, jdk)
      ? ["linux/amd64"]
    : ["linux/amd64", "linux/arm64"])

    # Debian slim
    : is_debian_slim(distribution)
    ? (equal(17, jdk)
      ? ["linux/amd64"]
    : ["linux/amd64", "linux/arm64"])

    # RHEL
    : is_rhel(distribution)
    ? ["linux/amd64", "linux/arm64", "linux/ppc64le"]

    # Default (Debian)
    : ["linux/amd64", "linux/arm64", "linux/s390x", "linux/ppc64le"]
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
      is_default_jdk(jdk) && !is_rhel(distribution) ? tag(true, distribution) : "",
      is_default_jdk(jdk) && !is_rhel(distribution) ? tag_weekly(false, distribution) : "",
      is_default_jdk(jdk) && !is_rhel(distribution) ? tag_lts(false, "lts-${distribution}") : "",
      is_default_jdk(jdk) && !is_rhel(distribution) ? tag_lts(true, "lts-${distribution}") : "",
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

    # ## Default JDK extra short tags
    is_default_jdk(jdk) ? tag(true, "hotspot-${distribution}") : "",
    is_default_jdk(jdk) ? tag_weekly(false, distribution) : "",
    is_default_jdk(jdk) ? tag_weekly(true, distribution) : "",
    is_default_jdk(jdk) ? tag_lts(false, "lts-${distribution}") : "",
    is_default_jdk(jdk) ? tag_lts(true, distribution) : "",
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
    is_default_jdk(jdk) ? tag(true, slim_prefix(variant, "")) : "",
    is_default_jdk(jdk) ? tag_weekly(false, slim_prefix(variant, "latest")) : "",
    is_default_jdk(jdk) ? tag_lts(false, slim_suffix(variant, "lts")) : "",
    is_default_jdk(jdk) ? tag_lts(true, slim_suffix(variant, "lts")) : "",
  ]
}

# Return array of Windows version(s) to build
# Can be overridden by setting WINDOWS_VERSION_OVERRIDE to a specific Windows version
# Ex: WINDOWS_VERSION_OVERRIDE=ltsc2025 docker buildx bake windows
function "windowsversions" {
  params = []
  result = notequal(WINDOWS_VERSION_OVERRIDE, "") ? [WINDOWS_VERSION_OVERRIDE] : windows_version_to_build
}
