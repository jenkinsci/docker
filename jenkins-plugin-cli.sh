#!/usr/bin/env bash

java ${JAVA_OPTS:+"$JAVA_OPTS"} -jar /usr/lib/jenkins-plugin-manager.jar "$@"
