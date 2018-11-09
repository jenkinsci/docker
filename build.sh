#!/usr/bin/env bash

source ./vars.sh
: "${JENKINS_VERSION:?JENKINS_VERSION must be set to build the jenkins-docker image}"
: "${JENKINS_SHA256:?JENKINS_SHA256 must be set to build the jenkins-docker image}"
: "${JENKINS_DOCKER_IMAGE_TAG:?JENKINS_DOCKER_IMAGE_TAG must be set to build the jenkins-docker image}"

docker build \
-t jenkins-docker:${JENKINS_DOCKER_IMAGE_TAG} \
--build-arg uid=$(id -u) \
--build-arg gid=$(id -g) \
--build-arg DOCKER_GID=$(cat /etc/group | grep docker | cut -f 3 -d :) \
--build-arg JENKINS_VERSION=${JENKINS_VERSION} \
--build-arg JENKINS_SHA=${JENKINS_SHA256} \
--build-arg DOCKER_VERSION=${DOCKER_VERSION} \
--no-cache \
.
