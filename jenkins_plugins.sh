#!/bin/bash
#
# Credit goes to: https://github.com/yasn77/docker-jenkins/blob/master/plugins_script/download_plugins.sh
# With some minor modification to work with user

export JENKINS_HOME=$(mktemp -d)

cd ${JENKINS_HOME}
$JAVA -jar ${JENKINS_WAR} --httpPort=8181 &> ${JENKINS_HOME}/jenkins.out &

while ! grep 'INFO: Jenkins is fully up and running' jenkins.out
do
  echo "Waiting for Jenkins to start..."
  sleep 5
done

echo "Jenkins is running, now get plugins.."

# Update updateCenter so we have a valid list of plugins
curl -L http://updates.jenkins-ci.org/stable/update-center.json | sed '1d;$d' | curl -X POST -H 'Accept: application/json' -d @- http://127.0.0.1:8181/updateCenter/byId/default/postBack

while [ ! -f ${JENKINS_HOME}/jenkins-cli.jar ]
do
  wget -q -O ${JENKINS_HOME}/jenkins-cli.jar http://127.0.0.1:8181/jnlpJars/jenkins-cli.jar
done

# Since JENKINS_HOME in this docker image is a volume,
# we want to make sure that the plugins are available when
# volume is mounted
for p in $(cat /plugins.txt)
do
  echo "Adding Jenkins Plugin ${p}..."
  $JAVA -jar  ${JENKINS_HOME}/jenkins-cli.jar -s http://127.0.0.1:8181/ install-plugin ${p}
done

mv ${JENKINS_HOME}/plugins/* /plugins/
chown -R ${JENKINS_USER} /plugins/*

$JAVA -jar ${JENKINS_HOME}/jenkins-cli.jar -s http://127.0.0.1:8181/ safe-shutdown

# Cleanup
rm -rf ${JENKINS_HOME}
