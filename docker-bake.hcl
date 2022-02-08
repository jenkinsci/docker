# ---- groups ----

group "linux" {
  targets = [
    "almalinux_jdk11",
    "alpine_jdk8",
    "alpine_jdk11",
    "centos7_jdk8",
    "centos7_jdk11",
    "debian_jdk8",
    "debian_jdk11",
    "debian_jdk17",
    "debian_slim_jdk8",
    "debian_slim_jdk11",
    "rhel_ubi8_jdk11"
  ]
}

group "linux-arm64" {
  targets = [
    "almalinux_jdk11",
    "debian_jdk11",
    "debian_jdk17",
    "rhel_ubi8_jdk11",
  ]
}

group "linux-s390x" {
  targets = [
    "debian_jdk11",
  ]
}

group "linux-ppc64le" {
  targets = []
}

# ---- variables ----

variable "JENKINS_VERSION" {
  default = "2.303"
}

variable "JENKINS_SHA" {
  default = "4dfe49cd7422ec4317a7c7a7c083f40fa475a58a7747bd94187b2cf222006ac0"
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

variable "GIT_LFS_VERSION" {
  default = "3.0.2"
}

variable "PLUGIN_CLI_VERSION" {
  default = "2.12.3"
}

variable "COMMIT_SHA" {
  default = ""
}

# ----  user-defined functions ----

# return a tag including or not jenkins version
function "tag" {
  params = [jenkins_version, tag]
  result = equal(jenkins_version, true) ? "${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}-${tag}" : "${REGISTRY}/${JENKINS_REPO}:${tag}"
}

# return a weekly tag including or not jenkins version
function "tag_weekly" {
  params = [jenkins_version, tag]
  result =  equal(LATEST_WEEKLY, "true") ? tag(false, tag) : ""
}

# return a LTS tag including or not jenkins version
function "tag_lts" {
  params = [jenkins_version, tag]
  result =  equal(LATEST_LTS, "true") ? tag(false, "lts-${tag}") : ""
}

# ---- targets ----
target "almalinux_jdk11" {
  dockerfile = "11/almalinux/almalinux8/hotspot/Dockerfile"
  context = "."
  args = {
    JENKINS_VERSION = JENKINS_VERSION
    JENKINS_SHA = JENKINS_SHA
    COMMIT_SHA = COMMIT_SHA
  }
  tags = [
    tag(true, "almalinux"),
    tag_weekly(false, "almalinux"),
    tag_lts(false, "almalinux")
  ]
  platforms = ["linux/amd64", "linux/arm64"]
}

target "alpine_jdk8" {
  dockerfile = "8/alpine/hotspot/Dockerfile"
  context = "."
  args = {
    JENKINS_VERSION = JENKINS_VERSION
    JENKINS_SHA = JENKINS_SHA
    COMMIT_SHA = COMMIT_SHA
    GIT_LFS_VERSION = GIT_LFS_VERSION
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
  }
  tags = [
    tag(true, "alpine-jdk8"),
    tag_weekly(false, "alpine-jdk8"),
    tag_lts(false, "alpine-jdk8")
  ]
  platforms = ["linux/amd64"]
}

target "alpine_jdk11" {
  dockerfile = "11/alpine/hotspot/Dockerfile"
  context = "."
  args = {
    JENKINS_VERSION = JENKINS_VERSION
    JENKINS_SHA = JENKINS_SHA
    COMMIT_SHA = COMMIT_SHA
    GIT_LFS_VERSION = GIT_LFS_VERSION
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
  }
  tags = [
    tag(true, "alpine"),
    tag_weekly(false, "alpine"),
    tag_lts(false, "alpine"),
    tag_lts(true, "alpine"),
    tag_weekly(false, "alpine-jdk11"),
    tag_lts(false, "alpine-jdk11")
  ]
  platforms = ["linux/amd64"]
}

target "centos7_jdk8" {
  dockerfile = "8/centos/centos7/hotspot/Dockerfile"
  context = "."
  args = {
    JENKINS_VERSION = JENKINS_VERSION
    JENKINS_SHA = JENKINS_SHA
    COMMIT_SHA = COMMIT_SHA
    GIT_LFS_VERSION = GIT_LFS_VERSION
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
  }
  tags = [
    "${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}-centos7-jdk8",
    equal(LATEST_WEEKLY, "true") ? "${REGISTRY}/${JENKINS_REPO}:centos7-jdk8" : "",
    equal(LATEST_LTS, "true") ? "${REGISTRY}/${JENKINS_REPO}:lts-centos7-jdk8" : "",
  ]
  platforms = ["linux/amd64"]
}

target "centos7_jdk11" {
  dockerfile = "11/centos/centos7/hotspot/Dockerfile"
  context = "."
  args = {
    JENKINS_VERSION = JENKINS_VERSION
    JENKINS_SHA = JENKINS_SHA
    COMMIT_SHA = COMMIT_SHA
    GIT_LFS_VERSION = GIT_LFS_VERSION
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
  }
  tags = [
    "${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}-centos7",
    equal(LATEST_WEEKLY, "true") ? "${REGISTRY}/${JENKINS_REPO}:centos7" : "",
    equal(LATEST_WEEKLY, "true") ? "${REGISTRY}/${JENKINS_REPO}:centos7-jdk11" : "",
    equal(LATEST_LTS, "true") ?  "${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}-lts-centos7" : "",
    equal(LATEST_LTS, "true") ? "${REGISTRY}/${JENKINS_REPO}:lts-centos7" : "",
    equal(LATEST_LTS, "true") ? "${REGISTRY}/${JENKINS_REPO}:lts-centos7-jdk11" : "",
  ]
  platforms = ["linux/amd64"]
}

target "debian_jdk8" {
  dockerfile = "8/debian/bullseye/hotspot/Dockerfile"
  context = "."
  args = {
    JENKINS_VERSION = JENKINS_VERSION
    JENKINS_SHA = JENKINS_SHA
    COMMIT_SHA = COMMIT_SHA
    GIT_LFS_VERSION = GIT_LFS_VERSION
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
  }
  tags = [
    "${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}-jdk8",
    equal(LATEST_WEEKLY, "true") ? "${REGISTRY}/${JENKINS_REPO}:latest-jdk8" : "",
    equal(LATEST_LTS, "true") ? "${REGISTRY}/${JENKINS_REPO}:lts-jdk8" : "",
    equal(LATEST_LTS, "true") ? "${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}-lts-jdk8" : "",
  ]
  platforms = ["linux/amd64"]
}

target "debian_jdk11" {
  dockerfile = "11/debian/bullseye/hotspot/Dockerfile"
  context = "."
  args = {
    JENKINS_VERSION = JENKINS_VERSION
    JENKINS_SHA = JENKINS_SHA
    COMMIT_SHA = COMMIT_SHA
    GIT_LFS_VERSION = GIT_LFS_VERSION
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
  }
  tags = [
    "${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}",
    "${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}-jdk11",
    equal(LATEST_WEEKLY, "true") ? "${REGISTRY}/${JENKINS_REPO}:latest" : "",
    equal(LATEST_WEEKLY, "true") ? "${REGISTRY}/${JENKINS_REPO}:latest-jdk11" : "",
    equal(LATEST_WEEKLY, "true") ? "${REGISTRY}/${JENKINS_REPO}:jdk11" : "",
    equal(LATEST_LTS, "true") ? "${REGISTRY}/${JENKINS_REPO}:lts" : "",
    equal(LATEST_LTS, "true") ? "${REGISTRY}/${JENKINS_REPO}:lts-jdk11" : "",
    equal(LATEST_LTS, "true") ? "${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}-lts" : "",
    equal(LATEST_LTS, "true") ? "${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}-lts-jdk11" : "",
  ]
  platforms = ["linux/amd64", "linux/arm64", "linux/s390x"]
}

target "debian_slim_jdk8" {
  dockerfile = "8/debian/bullseye-slim/hotspot/Dockerfile"
  context = "."
  args = {
    JENKINS_VERSION = JENKINS_VERSION
    JENKINS_SHA = JENKINS_SHA
    COMMIT_SHA = COMMIT_SHA
    GIT_LFS_VERSION = GIT_LFS_VERSION
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
  }
  tags = [
    "${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}-slim-jdk8",
    equal(LATEST_WEEKLY, "true") ? "${REGISTRY}/${JENKINS_REPO}:slim-jdk8" : "",
    equal(LATEST_LTS, "true") ? "${REGISTRY}/${JENKINS_REPO}:lts-slim-jdk8" : "",
  ]
  platforms = ["linux/amd64"]
}

target "debian_slim_jdk11" {
  dockerfile = "11/debian/bullseye-slim/hotspot/Dockerfile"
  context = "."
  args = {
    JENKINS_VERSION = JENKINS_VERSION
    JENKINS_SHA = JENKINS_SHA
    COMMIT_SHA = COMMIT_SHA
    GIT_LFS_VERSION = GIT_LFS_VERSION
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
  }
  tags = [
    "${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}-slim",
    equal(LATEST_WEEKLY, "true") ? "${REGISTRY}/${JENKINS_REPO}:slim" : "",
    equal(LATEST_WEEKLY, "true") ? "${REGISTRY}/${JENKINS_REPO}:slim-jdk11" : "",
    equal(LATEST_LTS, "true") ? "${REGISTRY}/${JENKINS_REPO}:lts-slim" : "",
    equal(LATEST_LTS, "true") ? "${REGISTRY}/${JENKINS_REPO}:lts-slim-jdk11" : "",
    equal(LATEST_LTS, "true") ? "${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}-lts-slim" : "",
  ]
  platforms = ["linux/amd64"]
}

target "rhel_ubi8_jdk11" {
  dockerfile = "11/rhel/ubi8/hotspot/Dockerfile"
  context = "."
  args = {
    JENKINS_VERSION = JENKINS_VERSION
    JENKINS_SHA = JENKINS_SHA
    COMMIT_SHA = COMMIT_SHA
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
  }
  tags = [
    "${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}-rhel-ubi8-jdk11",
    equal(LATEST_WEEKLY, "true") ? "${REGISTRY}/${JENKINS_REPO}:rhel-ubi8-jdk11" : "",
    equal(LATEST_LTS, "true") ? "${REGISTRY}/${JENKINS_REPO}:lts-rhel-ubi8-jdk11" : "",
    equal(LATEST_LTS, "true") ? "${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}-lts-rhel-ubi8-jdk11" : "",   
  ]
  platforms = ["linux/amd64", "linux/arm64"]
}

target "debian_jdk17" {
  dockerfile = "17/debian/bullseye/hotspot/Dockerfile"
  context = "."
  args = {
    JENKINS_VERSION = JENKINS_VERSION
    JENKINS_SHA = JENKINS_SHA
    COMMIT_SHA = COMMIT_SHA
    GIT_LFS_VERSION = GIT_LFS_VERSION
    PLUGIN_CLI_VERSION = PLUGIN_CLI_VERSION
  }
  tags = [
    "${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}-jdk17-preview",
    equal(LATEST_WEEKLY, "true") ? "${REGISTRY}/${JENKINS_REPO}:latest-jdk17-preview" : "",
    equal(LATEST_WEEKLY, "true") ? "${REGISTRY}/${JENKINS_REPO}:jdk17-preview" : "",
    equal(LATEST_LTS, "true") ? "${REGISTRY}/${JENKINS_REPO}:lts-jdk17-preview" : "",
    equal(LATEST_LTS, "true") ? "${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}-lts-jdk17-preview" : "",
  ]
  platforms = ["linux/amd64", "linux/arm64"]
}
