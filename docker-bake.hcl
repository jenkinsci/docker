// TODO handle latest / latest-variant / latest-lts

group "linux" {
  targets = [
    "alpine_jdk8",
    "centos7_jdk8",
    "centos8_jdk8",
    "debian_jdk8",
    "debian_jdk11",
    "debian_slim_jdk8",
  ]
}

group "linux-arm64" {
  targets = [
    "centos8_jdk8",
    "debian_jdk8",
    "debian_jdk11",
    "debian_slim_jdk8",
  ]
}

group "linux-s390x" {
  targets = [
    "debian_jdk11",
  ]
}

group "linux-ppc64le" {
  targets = [
    "centos8_jdk8",
    "debian_jdk8",
    "debian_jdk11",
    "debian_slim_jdk8",
  ]
}

group "windows" {
  targets = [
    "windows_1809_jdk11",
    "windows_2019_jdk11",
  ]
}

variable "JENKINS_VERSION" {
  default = "2.300"
}

variable "JENKINS_SHA" {
  default = "2f6aa548373b038af4fb6a4d6eaa5d13679510008f1712532732bf77c55b9670"
}

variable "REGISTRY" {
  default = "docker.io"
}

variable "JENKINS_REPO" {
  default = "jenkins/jenkins"
}

target "alpine_jdk8" {
  dockerfile = "8/alpine/hotspot/Dockerfile"
  context = "."
  args = {
    JENKINS_VERSION = JENKINS_VERSION
    JENKINS_SHA = JENKINS_SHA
  }
  tags = ["${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}-alpine"]
  platforms = ["linux/amd64"]
}

target "centos7_jdk8" {
  dockerfile = "8/centos/centos7/hotspot/Dockerfile"
  context = "."
  args = {
    JENKINS_VERSION = JENKINS_VERSION
    JENKINS_SHA = JENKINS_SHA
  }
  tags = ["${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}-centos7"]
  platforms = ["linux/amd64"]
}

target "centos8_jdk8" {
  dockerfile = "8/centos/centos8/hotspot/Dockerfile"
  context = "."
  args = {
    JENKINS_VERSION = JENKINS_VERSION
    JENKINS_SHA = JENKINS_SHA
  }
  tags = ["${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}-centos"]
  platforms = ["linux/amd64", "linux/ppc64le", "linux/arm64"]
}

target "debian_jdk8" {
  dockerfile = "8/debian/buster/hotspot/Dockerfile"
  context = "."
  args = {
    JENKINS_VERSION = JENKINS_VERSION
    JENKINS_SHA = JENKINS_SHA
  }
  tags = ["${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}"]
  platforms = ["linux/amd64", "linux/ppc64le", "linux/arm64"]
}

target "debian_jdk11" {
  dockerfile = "11/debian/buster/hotspot/Dockerfile"
  context = "."
  args = {
    JENKINS_VERSION = JENKINS_VERSION
    JENKINS_SHA = JENKINS_SHA
  }
  tags = ["${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}-jdk11"]
  platforms = ["linux/amd64", "linux/ppc64le", "linux/arm64", "linux/s390x"]
}

target "debian_slim_jdk8" {
  dockerfile = "8/debian/buster-slim/hotspot/Dockerfile"
  context = "."
  args = {
    JENKINS_VERSION = JENKINS_VERSION
    JENKINS_SHA = JENKINS_SHA
  }
  tags = ["${REGISTRY}/${JENKINS_REPO}:${JENKINS_VERSION}-slim"]
  platforms = ["linux/amd64", "linux/ppc64le", "linux/arm64"]
}

target "windows_1809_jdk11" {
  dockerfile = "11/windows/windowsservercore-1809/hotspot/Dockerfile"
  context = "."
  args = {
    JENKINS_VERSION = JENKINS_VERSION
    JENKINS_SHA = JENKINS_SHA
  }

  tags = ["{REGISTRY}/${JENKINS_REPO}:jdk11-hotspot-windowsservercore-1809"]
}

target "windows_2019_jdk11" {
  dockerfile = "11/windows/windowsservercore-2019/hotspot/Dockerfile"
  context = "."
  args = {
    JENKINS_VERSION = JENKINS_VERSION
    JENKINS_SHA = JENKINS_SHA
  }
  tags = ["{REGISTRY}/${JENKINS_REPO}:jdk11-hotspot-windowsservercore-2019"]
}
