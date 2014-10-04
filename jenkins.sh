#! /bin/bash

exec java $JAVA_OPTS -jar /usr/share/jenkins/jenkins.war --extractedFilesFolder=/var/lib/jenkins --prefix=$JENKINS_PREFIX $@

