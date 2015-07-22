#!/bin/bash -le
# description: connect slave to jenkins master via JNLP w/ resilency for recovery from bad connection state
# i.e. java -jar slave.jar -jnlpUrl http://jenkins:8080/computer/client1/slave-agent.jnlp

: ${log:="./jenkins_slave.log"}
: ${master:="http://jenkins:80"}
: ${slave:=`hostname -s`}

JAR_FILE=slave.jar

# kill pid of existing connection if slave is offline since it is likely possible a stale network connection preventing recovery of slave after jenkins restart, upgrade, etc.
terminateOfflineSlave() {
  RUNNING=$(ps u -U $(whoami) | grep ${JAR_FILE} | awk '/java/{print $2}')
  if [ ! -z "${RUNNING}" ]; then
    curl --silent -L ${master}/computer/${slave}/api/xml | grep '<offline>false</offline>' 1>/dev/null && echo "Slave process is already running" && exit 0
    echo 'Offline slave process terminated'
    kill -s KILL ${RUNNING}
  else
    echo "Slave process is not running"
  fi
}

# always download from master to match communication incase jenkins was upgraded
downloadJar() {
  rm -f ${JAR_FILE}
  url="${master}/jnlpJars/${JAR_FILE}"
  echo "Downloading latest JAR from $url" >> $log
  curl -OL ${master}/jnlpJars/${JAR_FILE} >> $log
}

startJar() {
  echo "Starting ${JAR_FILE}"  >> $log
  java -jar ${JAR_FILE} -jnlpUrl ${master}/computer/${slave}/slave-agent.jnlp
}

terminateOfflineSlave

# for-loop where initial jenkins setup > +10 min whereas subsequent startup ~1 min
i=15; until [ $i -eq 0 ]; do let i-=1 && downloadJar && startJar && i=0 || sleep 60; done

# check if running
RUNNING=$(ps u -U $(whoami) | grep ${JAR_FILE} | awk '/java/{print $2}')
[ ! -z "${RUNNING}" ] && exit 0 || exit 1
