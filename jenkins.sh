#!/bin/bash

export TZ

if [[ ! -d "${JENKINS_HOME}/log" && ! -L "${JENKINS_HOME}/log" ]] ; then
  mkdir -p ${JENKINS_HOME}/log
fi

# Enable downloaded plugins
if [[ ! -d "${JENKINS_HOME}/plugins" && ! -L "${JENKINS_HOME}/plugins" ]] ; then
  mkdir -p ${JENKINS_HOME}/plugins
fi

for plugin in $(find /plugins/ -type f -name "*.[hj]pi")
do
  mv ${plugin} ${JENKINS_HOME}/plugins/
done

rm -rf /plugins/*

exec $JAVA $JAVA_ARGS -server -jar $JENKINS_WAR $JENKINS_ARGS

