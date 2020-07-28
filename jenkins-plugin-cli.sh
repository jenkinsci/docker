#!/usr/bin/env bash

export JENKINS_UC=${JENKINS_UC_OVERRIDE:-https://updates.jenkins.io/update-center.actual.json}
export JENKINS_UC_EXPERIMENTAL=${JENKINS_UC_EXPERIMENTAL_OVERRIDE:-https://updates.jenkins.io/experimental/update-center.actual.json}

java -jar /usr/lib/jenkins-plugin-manager.jar "$@"
