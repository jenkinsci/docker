#!/bin/bash

exec /bin/bash -c "java $JAVA_OPTS -jar /opt/jenkins-plugin-manager.jar $*"
