#!/bin/bash

set -e
set -x

JENKINS_VERSION=$(curl -sq https://api.github.com/repos/jenkinsci/jenkins/tags | grep '"name":' | egrep -o '[0-9]+(\.[0-9]+)+' | sort --version-sort | uniq | tail -1)
echo "$JENKINS_VERSION"

JENKINS_SHA=$(curl "http://repo.jenkins-ci.org/simple/releases/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war.sha1")
echo "$JENKINS_SHA"

docker build --build-arg "JENKINS_VERSION=$JENKINS_VERSION" \
             --build-arg "JENKINS_SHA=$JENKINS_SHA" \
             --no-cache --pull \
             --tag "jenkinsci/jenkins:$JENKINS_VERSION" .

docker tag -f "jenkinsci/jenkins:$JENKINS_VERSION" jenkinsci/jenkins:latest

docker push "jenkinsci/jenkins:$JENKINS_VERSION"
docker push jenkinsci/jenkins:latest


