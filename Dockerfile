#FROM java:openjdk-7u65-jdk
FROM java:7u65

RUN apt-get update && apt-get install -y wget git curl zip && rm -rf /var/lib/apt/lists/*

ENV JENKINS_VERSION 1.565.3
RUN mkdir /usr/share/jenkins/
RUN useradd -d /home/jenkins -m -s /bin/bash jenkins

RUN curl -L http://mirrors.jenkins-ci.org/war-stable/$JENKINS_VERSION/jenkins.war -o /usr/share/jenkins/jenkins.war

ENV JENKINS_HOME /var/jenkins_home
RUN usermod -m -d "$JENKINS_HOME" jenkins && chown -R jenkins "$JENKINS_HOME"
VOLUME /var/jenkins_home

COPY ./jenkins.sh /usr/local/bin/jenkins.sh

COPY ./jnlp.groovy /usr/share/jenkins/init.groovy.d/
RUN mkdir -p /usr/share/jenkins/plugins && chown -R jenkins /usr/share/jenkins/plugins /usr/share/jenkins/init.groovy.d

# define url prefix for running jenkins behind Apache (https://wiki.jenkins-ci.org/display/JENKINS/Running+Jenkins+behind+Apache)
ENV JENKINS_PREFIX /

# for main web interface:
EXPOSE 8080

# will be used by attached slave agents:
EXPOSE 50000

USER jenkins

ENTRYPOINT /usr/local/bin/jenkins.sh
