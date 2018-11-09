#!/usr/bin/env bash

source ./vars.sh
: "${JENKINS_DOCKER_IMAGE_TAG:?JENKINS_DOCKER_IMAGE_TAG must be set to build the jenkins-docker image}"

docker run \
--name jenkins \
--rm \
-d \
-v /var/run/docker.sock:/var/run/docker.sock \
-v ${LOCAL_SRC}:/src \
--mount source=jenkins-home,target=/var/jenkins_home \
-p 8080:8080 \
-p 50000:50000 \
jenkins-docker:${JENKINS_DOCKER_IMAGE_TAG}

#-v $(which docker):$(which docker) \
#-v ~/jenkins_home:/var/jenkins_home \
#--mount source=jenkins-log,target=/var/log/jenkins \
