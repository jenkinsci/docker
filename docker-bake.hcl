# ---- groups ----

group "linux" {
  targets = [
    "alpine_jdk17",
    "alpine_jdk21",
    "alpine_jdk25",
    "debian_jdk17",
    "debian_jdk21",
    "debian_jdk25",
    "debian_slim_jdk17",
    "debian_slim_jdk21",
    "debian_slim_jdk25",
    "rhel_ubi9_jdk17",
    "rhel_ubi9_jdk21",
    "rhel_ubi9_jdk25",
  ]
}

group "linux-arm64" {
  targets = [
    "alpine_jdk21",
    "alpine_jdk25",
    "debian_jdk17",
    "debian_jdk21",
    "debian_jdk25",
    "debian_slim_jdk21",
    "debian_slim_jdk25",
    "rhel_ubi9_jdk17",
    "rhel_ubi9_jdk21",
    "rhel_ubi9_jdk25",
  ]
}

group "linux-s390x" {
  targets = [
    "debian_jdk17",
    "debian_jdk21",
    "debian_jdk25",
    "debian_slim_jdk25",
  ]
}

group "linux-ppc64le" {
  targets = [
    "debian_jdk17",
    "debian_jdk21",
    "debian_jdk25",
    "debian_slim_jdk25",
    "rhel_ubi9_jdk17",
    "rhel_ubi9_jdk21",
    "rhel_ubi9_jdk25",
  ]
}

# ---- variables ----

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
  default = "3.22.1"
}

variable "ALPINE_SHORT_TAG" {
  default = regex_replace(ALPINE_FULL_TAG, "\\.\\d+$", "")
}

variable "JAVA17_VERSION" {
  default = "17.0.16_8"
}

variable "JAVA21_VERSION" {
  default = "21.0.8_9"
}

variable "JAVA25_VERSION" {
  default = "25+9-ea-beta"
}

variable "TRIXIE_TAG" {
  default = "20250929"
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

# ---- targets ----

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
  dockerfile = "debian/trixie/hotspot/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    WAR_SHA            = WAR_SHA
    WAR_URL            = war_url()
    COMMIT_SHA         = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
    TRIXIE_TAG         = TRIXIE_TAG
    JAVA_VERSION       = JAVA17_VERSION
  }
  tags = [
    tag(true, "jdk17"),
    tag_weekly(false, "latest-jdk17"),
    tag_weekly(false, "jdk17"),
    tag_lts(false, "lts-jdk17"),
    tag_lts(true, "lts-jdk17")
  ]
  platforms = ["linux/amd64", "linux/arm64", "linux/s390x", "linux/ppc64le"]
}

target "debian_jdk21" {
  dockerfile = "debian/trixie/hotspot/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    WAR_SHA            = WAR_SHA
    WAR_URL            = war_url()
    COMMIT_SHA         = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
    TRIXIE_TAG         = TRIXIE_TAG
    JAVA_VERSION       = JAVA21_VERSION
  }
  tags = [
    tag(true, ""),
    tag(true, "jdk21"),
    tag_weekly(false, "latest"),
    tag_weekly(false, "latest-jdk21"),
    tag_weekly(false, "jdk21"),
    tag_lts(false, "lts"),
    tag_lts(false, "lts-jdk21"),
    tag_lts(true, "lts"),
    tag_lts(true, "lts-jdk21")
  ]
  platforms = ["linux/amd64", "linux/arm64", "linux/s390x", "linux/ppc64le"]
}

target "debian_slim_jdk17" {
  dockerfile = "debian/trixie-slim/hotspot/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    WAR_SHA            = WAR_SHA
    WAR_URL            = war_url()
    COMMIT_SHA         = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
    TRIXIE_TAG         = TRIXIE_TAG
    JAVA_VERSION       = JAVA17_VERSION
  }
  tags = [
    tag(true, "slim-jdk17"),
    tag_weekly(false, "slim-jdk17"),
    tag_lts(false, "lts-slim-jdk17"),
  ]
  platforms = ["linux/amd64"]
}

target "debian_slim_jdk21" {
  dockerfile = "debian/trixie-slim/hotspot/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    WAR_SHA            = WAR_SHA
    WAR_URL            = war_url()
    COMMIT_SHA         = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
    TRIXIE_TAG         = TRIXIE_TAG
    JAVA_VERSION       = JAVA21_VERSION
  }
  tags = [
    tag(true, "slim"),
    tag(true, "slim-jdk21"),
    tag_weekly(false, "slim"),
    tag_weekly(false, "slim-jdk21"),
    tag_lts(false, "lts-slim"),
    tag_lts(false, "lts-slim-jdk21"),
    tag_lts(true, "lts-slim"),
  ]
  platforms = ["linux/amd64", "linux/arm64"]
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

target "alpine_jdk25" {
  dockerfile = "alpine/hotspot/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    WAR_SHA            = WAR_SHA
    WAR_URL            = war_url()
    COMMIT_SHA         = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
    ALPINE_TAG         = ALPINE_FULL_TAG
    JAVA_VERSION       = JAVA25_VERSION
  }
  tags = [
    tag(true, "alpine-jdk25"),
    tag_weekly(false, "alpine-jdk25"),
    tag_weekly(false, "alpine${ALPINE_SHORT_TAG}-jdk25"),
    tag_lts(false, "lts-alpine-jdk25"),
  ]
  platforms = ["linux/amd64", "linux/arm64"]
}

target "debian_jdk25" {
  dockerfile = "debian/trixie/hotspot/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    WAR_SHA            = WAR_SHA
    WAR_URL            = war_url()
    COMMIT_SHA         = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
    TRIXIE_TAG       = TRIXIE_TAG
    JAVA_VERSION       = JAVA25_VERSION
  }
  tags = [
    tag(true, "jdk25"),
    tag_weekly(false, "latest-jdk25"),
    tag_weekly(false, "jdk25"),
    tag_lts(false, "lts-jdk25"),
    tag_lts(true, "lts-jdk25")
  ]
  platforms = ["linux/amd64", "linux/arm64", "linux/s390x", "linux/ppc64le"]
}

target "debian_slim_jdk25" {
  dockerfile = "debian/trixie-slim/hotspot/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    WAR_SHA            = WAR_SHA
    WAR_URL            = war_url()
    COMMIT_SHA         = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
    TRIXIE_TAG       = TRIXIE_TAG
    JAVA_VERSION       = JAVA25_VERSION
  }
  tags = [
    tag(true, "slim-jdk25"),
    tag_weekly(false, "slim-jdk25"),
    tag_lts(false, "lts-slim-jdk25"),
  ]
  platforms = ["linux/amd64", "linux/arm64", "linux/s390x", "linux/ppc64le"]
}

target "rhel_ubi9_jdk25" {
  dockerfile = "rhel/ubi9/hotspot/Dockerfile"
  context    = "."
  args = {
    JENKINS_VERSION    = JENKINS_VERSION
    WAR_SHA            = WAR_SHA
    WAR_URL            = war_url()
    COMMIT_SHA         = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
    JAVA_VERSION       = JAVA25_VERSION
  }
  tags = [
    tag(true, "rhel-ubi9-jdk25"),
    tag_weekly(false, "rhel-ubi9-jdk25"),
    tag_lts(false, "lts-rhel-ubi9-jdk25"),
    tag_lts(true, "lts-rhel-ubi9-jdk25")
  ]
  platforms = ["linux/amd64", "linux/arm64", "linux/ppc64le"]
}
