#!/bin/bash

chown $JENKINS_USER $JENKINS_HOME
su $JENKINS_USER -c "exec java -jar /usr/share/jenkins/jenkins.war --prefix=$JENKINS_PREFIX"
