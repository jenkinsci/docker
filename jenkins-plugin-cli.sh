#!/usr/bin/env bash

JENKINS_UC=${JENKINS_UC_OVERRIDE:-https://updates.jenkins.io/update-center.actual.json}
JENKINS_UC_EXPERIMENTAL=${JENKINS_UC_EXPERIMENTAL_OVERRIDE:-https://updates.jenkins.io/experimental/update-center.actual.json}

java -jar /usr/lib/jenkins-plugin-manager.jar "$@"
