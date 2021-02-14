#!/bin/bash

exec /bin/bash -c "java $JAVA_OPTS -jar /usr/lib/jenkins-plugin-manager.jar $*"
