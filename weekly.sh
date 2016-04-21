#!/bin/bash

set -e
set -x

JENKINS_VERSION=`curl -q https://api.github.com/repos/jenkinsci/jenkins/tags | grep '"name":' | grep -o '[0-9]\.[0-9]+'  | uniq | sort | tail -1`
echo $JENKINS_VERSION

JENKINS_SHA=`curl http://repo.jenkins-ci.org/simple/releases/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war.sha1`
echo $JENKINS_SHA

sed -e "s/ENV JENKINS_VERSION .*/ENV JENKINS_VERSION $JENKINS_VERSION/g" -e "s/ENV JENKINS_SHA .*/ENV JENKINS_SHA $JENKINS_SHA/g" Dockerfile > Dockerfile.$JENKINS_VERSION

docker build -f Dockerfile.$JENKINS_VERSION -t jenkinsci/jenkins:$JENKINS_VERSION .
docker push jenkinsci/jenkins:$JENKINS_VERSION

docker build -f Dockerfile.$JENKINS_VERSION -t jenkinsci/jenkins:latest .
docker push jenkinsci/jenkins:latest


