#!/bin/sh

echo "Copying init scripts"
mkdir -p $JENKINS_HOME/init.groovy.d
find /usr/share/jenkins/init.groovy.d/ -type f -exec cp {} $JENKINS_HOME/init.groovy.d/ \;

echo "Copying plugins"
mkdir -p $JENKINS_HOME/plugins
find /usr/share/jenkins/plugins/ -type f -exec cp {} $JENKINS_HOME/plugins/ \;

exec java $JAVA_OPTS -jar /usr/share/jenkins/jenkins.war --prefix=$JENKINS_PREFIX "$@"
