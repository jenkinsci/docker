FROM bats-jenkins-install-plugins

RUN rm -rf /usr/share/jenkins/ref ; jenkins-plugin-cli --plugins junit:1.6 ant:1.3 mesos:0.13.0 git:latest filesystem_scm:experimental docker-plugin:1.1.6
