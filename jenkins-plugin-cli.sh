#!/bin/bash

eval exec java "$JAVA_OPTS" -jar /opt/jenkins-plugin-manager.jar "$*"
