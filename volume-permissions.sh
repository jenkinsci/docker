#!/bin/bash -e

if [ "$(whoami)" == "root" ]; then

  # if root owns the jenkins home, change it to the jenkins user
  if [ "$(stat -c '%U' $JENKINS_HOME)" == "root" ]; then
    echo "Setting Jenkins home ownership to jenkins user"
    chown jenkins:jenkins $JENKINS_HOME
  fi

  # run main program as jenkins user
  exec gosu jenkins /usr/local/bin/jenkins.sh "$@"

else
  # running as a unprivileged user already
  exec /usr/local/bin/jenkins.sh "$@"
fi
