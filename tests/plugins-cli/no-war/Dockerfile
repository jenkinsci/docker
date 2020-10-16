FROM bats-jenkins

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
USER root
RUN rm -rf /usr/share/jenkins/jenkins.war
USER jenkins
RUN jenkins-plugin-cli -f /usr/share/jenkins/ref/plugins.txt
