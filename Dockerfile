#FROM java:openjdk-7u65-jdk
FROM java:7u65

RUN apt-get update && apt-get install -y wget git curl zip && rm -rf /var/lib/apt/lists/*

ENV JENKINS_VERSION 1.565.2
RUN mkdir /usr/share/jenkins/
RUN useradd -d /home/jenkins -m -s /bin/bash jenkins
ADD http://mirrors.jenkins-ci.org/war-stable/$JENKINS_VERSION/jenkins.war /usr/share/jenkins/

ENV JENKINS_HOME /var/jenkins_home
RUN usermod -m -d "$JENKINS_HOME" jenkins && chown -R jenkins "$JENKINS_HOME"
VOLUME /var/jenkins_home

COPY init.groovy /tmp/WEB-INF/init.groovy
RUN cd /tmp && zip -g /usr/share/jenkins/jenkins.war WEB-INF/init.groovy && rm -rf /tmp/WEB-INF

# define url prefix for running jenkins behind Apache (https://wiki.jenkins-ci.org/display/JENKINS/Running+Jenkins+behind+Apache)
ENV JENKINS_PREFIX /

# for main web interface:
EXPOSE 8080

# will be used by attached slave agents:
EXPOSE 50000

COPY ./jenkins.sh /usr/local/bin/jenkins.sh
USER jenkins
CMD ["/usr/local/bin/jenkins.sh"]
