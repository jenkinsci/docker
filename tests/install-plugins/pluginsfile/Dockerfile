FROM bats-jenkins

ARG IGNORE_SECURITY_WARNINGS=true
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN /usr/local/bin/install-plugins.sh < /usr/share/jenkins/ref/plugins.txt
