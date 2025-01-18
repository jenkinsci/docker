# ---- groups ----

group "linux" {
  targets = [
    "alpine_jdk17",
    "alpine_jdk21",
    "debian_jdk17",
    "debian_jdk21",
    "debian_slim_jdk17",
    "debian_slim_jdk21",
    "rhel_ubi9_jdk17",
    "rhel_ubi9_jdk21",
  ]
}

group "linux-arm64" {
  targets = [
    "alpine_jdk21",
    "debian_jdk17",
    "debian_jdk21",
    "debian_slim_jdk21",
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

# ---- variables ----

variable "JENKINS_VERSION" {
  default = "2.479"
}

variable "JENKINS_SHA" {
  default = "910ea36cef37c45087e39d65e335988e036fccea47c79cc5a52e721a10cb1b49"
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
  default = "3.21.2"
}

variable "ALPINE_SHORT_TAG" {
  default = regex_replace(ALPINE_FULL_TAG, "\\.\\d+$", "")
}

variable "JAVA17_VERSION" {
  default = "17.0.13_11"
}

variable "JAVA21_VERSION" {
  default = "21.0.5_11"
}

variable "BOOKWORM_TAG" {
  default = "20250113"
}

# ----  user-defined functions ----

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

# ---- targets ----

target "alpine_jdk17" {
  dockerfile = "alpine/hotspot/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    JENKINS_SHA        = JENKINS_SHA
    COMMIT_SHA         = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
    ALPINE_TAG         = ALPINE_FULL_TAG
    JAVA_VERSION       = JAVA17_VERSION
  }
  tags = [
    tag(true, "alpine"),
    tag(true, "alpine-jdk17"),
    tag_weekly(false, "alpine"),
    tag_weekly(false, "alpine-jdk17"),
    tag_weekly(false, "alpine${ALPINE_SHORT_TAG}-jdk17"),
    tag_lts(false, "lts-alpine"),
    tag_lts(false, "lts-alpine-jdk17"),
    tag_lts(true, "lts-alpine")
  ]
  platforms = ["linux/amd64"]
}

target "alpine_jdk21" {
  dockerfile = "alpine/hotspot/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    JENKINS_SHA        = JENKINS_SHA
    COMMIT_SHA         = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
    ALPINE_TAG         = ALPINE_FULL_TAG
    JAVA_VERSION       = JAVA21_VERSION
  }
  tags = [
    tag(true, "alpine-jdk21"),
    tag_weekly(false, "alpine-jdk21"),
    tag_weekly(false, "alpine${ALPINE_SHORT_TAG}-jdk21"),
    tag_lts(false, "lts-alpine-jdk21")
  ]
  platforms = ["linux/amd64", "linux/arm64"]
}

target "debian_jdk17" {
  dockerfile = "debian/bookworm/hotspot/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    JENKINS_SHA        = JENKINS_SHA
    COMMIT_SHA         = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
    BOOKWORM_TAG       = BOOKWORM_TAG
    JAVA_VERSION       = JAVA17_VERSION
  }
  tags = [
    tag(true, ""),
    tag(true, "jdk17"),
    tag_weekly(false, "latest"),
    tag_weekly(false, "latest-jdk17"),
    tag_weekly(false, "jdk17"),
    tag_lts(false, "lts"),
    tag_lts(false, "lts-jdk17"),
    tag_lts(true, "lts"),
    tag_lts(true, "lts-jdk17")
  ]
  platforms = ["linux/amd64", "linux/arm64", "linux/s390x", "linux/ppc64le"]
}

target "debian_jdk21" {
  dockerfile = "debian/bookworm/hotspot/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    JENKINS_SHA        = JENKINS_SHA
    COMMIT_SHA         = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
    BOOKWORM_TAG       = BOOKWORM_TAG
    JAVA_VERSION       = JAVA21_VERSION
  }
  tags = [
    tag(true, "jdk21"),
    tag_weekly(false, "latest-jdk21"),
    tag_weekly(false, "jdk21"),
    tag_lts(false, "lts-jdk21"),
    tag_lts(true, "lts-jdk21")
  ]
  platforms = ["linux/amd64", "linux/arm64", "linux/s390x", "linux/ppc64le"]
}

target "debian_slim_jdk17" {
  dockerfile = "debian/bookworm-slim/hotspot/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    JENKINS_SHA        = JENKINS_SHA
    COMMIT_SHA         = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
    BOOKWORM_TAG       = BOOKWORM_TAG
    JAVA_VERSION       = JAVA17_VERSION
  }
  tags = [
    tag(true, "slim"),
    tag(true, "slim-jdk17"),
    tag_weekly(false, "slim"),
    tag_weekly(false, "slim-jdk17"),
    tag_lts(false, "lts-slim"),
    tag_lts(false, "lts-slim-jdk17"),
    tag_lts(true, "lts-slim"),
  ]
  platforms = ["linux/amd64"]
}

target "debian_slim_jdk21" {
  dockerfile = "debian/bookworm-slim/hotspot/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    JENKINS_SHA        = JENKINS_SHA
    COMMIT_SHA         = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
    BOOKWORM_TAG       = BOOKWORM_TAG
    JAVA_VERSION       = JAVA21_VERSION
  }
  tags = [
    tag(true, "slim-jdk21"),
    tag_weekly(false, "slim-jdk21"),
    tag_lts(false, "lts-slim-jdk21"),
  ]
  platforms = ["linux/amd64", "linux/arm64"]
}

target "rhel_ubi9_jdk17" {
  dockerfile = "rhel/ubi9/hotspot/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    JENKINS_SHA        = JENKINS_SHA
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
    JENKINS_SHA        = JENKINS_SHA
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
