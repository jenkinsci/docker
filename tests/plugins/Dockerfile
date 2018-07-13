FROM bats-jenkins

ARG IGNORE_SECURITY_WARNINGS=true
COPY plugins.txt /usr/share/jenkins/ref/
RUN /usr/local/bin/plugins.sh /usr/share/jenkins/ref/plugins.txt
