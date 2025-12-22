## Variables
variable "default_jdk" {
  default = 21
}

variable "JENKINS_VERSION" {
  default = "2.504"
}

variable "WAR_SHA" {
  default = "efc91d6be8d79dd078e7f930fc4a5f135602d0822a5efe9091808fdd74607d32"
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
  default = "2.13.2"
}

variable "COMMIT_SHA" {
  default = ""
}

variable "ALPINE_FULL_TAG" {
  default = "3.23.0"
}

variable "ALPINE_SHORT_TAG" {
  default = regex_replace(ALPINE_FULL_TAG, "\\.\\d+$", "")
}

variable "JAVA17_VERSION" {
  default = "17.0.17_10"
}

variable "JAVA21_VERSION" {
  default = "21.0.9_10"
}

variable "DEBIAN_RELEASE_LINE" {
  default = "trixie"
}

variable "DEBIAN_VERSION" {
  default = "20251103"
}

variable "UBI9_TAG" {
  default = "9.7-1764794285"
}

variable "debian_variants" {
  default = ["debian", "debian-slim"]
}

## Targets
target "alpine_jdk17" {
  dockerfile = "alpine/hotspot/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    WAR_SHA            = WAR_SHA
    WAR_URL            = war_url()
    COMMIT_SHA         = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
    ALPINE_TAG         = ALPINE_FULL_TAG
    JAVA_VERSION       = JAVA17_VERSION
  }
  tags = [
    tag(true, "alpine-jdk17"),
    tag_weekly(false, "alpine-jdk17"),
    tag_weekly(false, "alpine${ALPINE_SHORT_TAG}-jdk17"),
    tag_lts(false, "lts-alpine-jdk17"),
  ]
  platforms = ["linux/amd64"]
}

target "alpine_jdk21" {
  dockerfile = "alpine/hotspot/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    WAR_SHA            = WAR_SHA
    WAR_URL            = war_url()
    COMMIT_SHA         = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
    ALPINE_TAG         = ALPINE_FULL_TAG
    JAVA_VERSION       = JAVA21_VERSION
  }
  tags = [
    tag(true, "alpine"),
    tag(true, "alpine-jdk21"),
    tag_weekly(false, "alpine"),
    tag_weekly(false, "alpine-jdk21"),
    tag_weekly(false, "alpine${ALPINE_SHORT_TAG}-jdk21"),
    tag_lts(false, "lts-alpine"),
    tag_lts(false, "lts-alpine-jdk21"),
    tag_lts(true, "lts-alpine"),
  ]
  platforms = ["linux/amd64", "linux/arm64"]
}

target "debian_jdk17" {
  matrix = {
    variant = debian_variants
  }
  name       = "${variant}_jdk17"
  dockerfile = "debian/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION     = JENKINS_VERSION
    WAR_SHA             = WAR_SHA
    WAR_URL             = war_url()
    COMMIT_SHA          = COMMIT_SHA
    PLUGIN_CLI_VERSION  = PLUGIN_CLI_VERSION
    DEBIAN_RELEASE_LINE = DEBIAN_RELEASE_LINE
    DEBIAN_VERSION      = DEBIAN_VERSION
    DEBIAN_VARIANT      = is_debian_slim(variant) ? "-slim" : ""
    JAVA_VERSION        = JAVA17_VERSION
  }
  tags      = debian_tags(variant, 17)
  platforms = debian_platforms(variant, 17)
}

target "debian_jdk21" {
  matrix = {
    variant = debian_variants
  }
  name       = "${variant}_jdk21"
  dockerfile = "debian/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION     = JENKINS_VERSION
    WAR_SHA             = WAR_SHA
    WAR_URL             = war_url()
    COMMIT_SHA          = COMMIT_SHA
    PLUGIN_CLI_VERSION  = PLUGIN_CLI_VERSION
    DEBIAN_RELEASE_LINE = DEBIAN_RELEASE_LINE
    DEBIAN_VERSION      = DEBIAN_VERSION
    DEBIAN_VARIANT      = is_debian_slim(variant) ? "-slim" : ""
    JAVA_VERSION        = JAVA21_VERSION
  }
  tags      = debian_tags(variant, 21)
  platforms = debian_platforms(variant, 21)
}

target "rhel_ubi9_jdk17" {
  dockerfile = "rhel/ubi9/hotspot/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    WAR_SHA            = WAR_SHA
    WAR_URL            = war_url()
    COMMIT_SHA         = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
    JAVA_VERSION       = JAVA17_VERSION
  }
  tags = [
    tag(true, "rhel-ubi9-jdk17"),
    tag_weekly(false, "rhel-ubi9-jdk17"),
    tag_lts(false, "lts-rhel-ubi9-jdk17"),
    tag_lts(true, "lts-rhel-ubi9-jdk17")
  ]
  platforms = ["linux/amd64", "linux/arm64", "linux/ppc64le"]
}

target "rhel_ubi9_jdk21" {
  dockerfile = "rhel/ubi9/hotspot/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    WAR_SHA            = WAR_SHA
    WAR_URL            = war_url()
    COMMIT_SHA         = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
    JAVA_VERSION       = JAVA21_VERSION
  }
  tags = [
    tag(true, "rhel-ubi9-jdk21"),
    tag_weekly(false, "rhel-ubi9-jdk21"),
    tag_lts(false, "lts-rhel-ubi9-jdk21"),
    tag_lts(true, "lts-rhel-ubi9-jdk21")
  ]
  platforms = ["linux/amd64", "linux/arm64", "linux/ppc64le"]
}

## Groups
group "linux" {
  targets = [
    "alpine_jdk17",
    "alpine_jdk21",
    "debian_jdk17",
    "debian_jdk21",
    "debian-slim_jdk17",
    "debian-slim_jdk21",
    "rhel_ubi9_jdk17",
    "rhel_ubi9_jdk21",
  ]
}

group "linux-arm64" {
  targets = [
    "alpine_jdk21",
    "debian_jdk17",
    "debian_jdk21",
    "debian-slim_jdk21",
    "rhel_ubi9_jdk17",
    "rhel_ubi9_jdk21",
  ]
}

group "linux-s390x" {
  targets = [
    "debian_jdk17",
    "debian_jdk21",
  ]
}

group "linux-ppc64le" {
  targets = [
    "debian_jdk17",
    "debian_jdk21",
    "rhel_ubi9_jdk17",
    "rhel_ubi9_jdk21",
  ]
}

## Common functions
# return a tag prefixed by the Jenkins version
function "_tag_jenkins_version" {
  params = [tag]
  result = notequal(tag, "") ? "${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}-${tag}" : "${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}"
}

# return a tag optionaly prefixed by the Jenkins version
function "tag" {
  params = [prepend_jenkins_version, tag]
  result = equal(prepend_jenkins_version, true) ? _tag_jenkins_version(tag) : "${REGISTRY}/${JENKINS_REPO}:${tag}"
}

# return a weekly optionaly prefixed by the Jenkins version
function "tag_weekly" {
  params = [prepend_jenkins_version, tag]
  result = equal(LATEST_WEEKLY, "true") ? tag(prepend_jenkins_version, tag) : ""
}

# return a LTS optionaly prefixed by the Jenkins version
function "tag_lts" {
  params = [prepend_jenkins_version, tag]
  result = equal(LATEST_LTS, "true") ? tag(prepend_jenkins_version, tag) : ""
}

# return WAR_URL if not empty, get.jenkins.io URL depending on JENKINS_VERSION release line otherwise
function "war_url" {
  # If JENKINS_VERSION has more than one sequence of digits with a trailing literal '.', this is LTS
  # 2.523 has only one sequence of digits with a trailing literal '.'
  # 2.516.1 has two sequences of digits with a trailing literal '.'
  params = []
  result = (notequal(WAR_URL, "")
    ? WAR_URL
    : (length(regexall("[0-9]+[.]", JENKINS_VERSION)) < 2
      ? "https://get.jenkins.io/war/${JENKINS_VERSION}/jenkins.war"
  : "https://get.jenkins.io/war-stable/${JENKINS_VERSION}/jenkins.war"))
}

# Return "true" if the jdk passed as parameter is the same as the default jdk, "false" otherwise
function "is_default_jdk" {
  params = [jdk]
  result = equal(default_jdk, jdk) ? true : false
}

## Debian specific functions
# Return if the variant passed in parameter is the debian slim one
function "is_debian_slim" {
  params = [variant]
  result = equal("debian-slim", variant)
}

# Return an array of platforms for Debian images depending on their variant and the jdk
function "debian_platforms" {
  params = [variant, jdk]
  result = (is_debian_slim(variant)
    ? (equal(17, jdk) ? ["linux/amd64"] : ["linux/amd64", "linux/arm64"])
  : ["linux/amd64", "linux/arm64", "linux/s390x", "linux/ppc64le"])
}

# Return text prefixed with "slim-" if the variant passed in parameter is the slim one
# Return only "slim" if the text passed in parameter is empty or "latest"
function "slim_prefix" {
  params = [variant, text]
  result = (is_debian_slim(variant)
    ? (equal("", text) ? "slim" : (equal("latest", text) ? "slim" : "slim-${text}"))
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
