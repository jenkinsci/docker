FROM ubuntu:14.04

RUN echo "1.565.2" > .lts-version-number

RUN apt-get update && apt-get install -y wget git curl zip && apt-get clean
RUN apt-get update && apt-get install -y --no-install-recommends openjdk-7-jdk

RUN wget -q -O - http://pkg.jenkins-ci.org/debian-stable/jenkins-ci.org.key | sudo apt-key add -
RUN echo deb http://pkg.jenkins-ci.org/debian-stable binary/ >> /etc/apt/sources.list
RUN apt-get update && apt-get install -y jenkins
RUN rm -rf /var/lib/apt/lists/*
RUN usermod -m -d /var/jenkins_home jenkins
RUN mkdir -p /var/jenkins_home && chown -R jenkins /var/jenkins_home
ADD init.groovy /tmp/WEB-INF/init.groovy
RUN cd /tmp && zip -g /usr/share/jenkins/jenkins.war WEB-INF/init.groovy && rm -rf /tmp/WEB-INF
ADD ./jenkins.sh /usr/local/bin/jenkins.sh
RUN chmod +x /usr/local/bin/jenkins.sh
USER jenkins

VOLUME /var/jenkins_home
ENV JENKINS_HOME /var/jenkins_home

# define url prefix for running jenkins behind Apache (https://wiki.jenkins-ci.org/display/JENKINS/Running+Jenkins+behind+Apache)
ENV JENKINS_PREFIX /

# for main web interface:
EXPOSE 8080

# will be used by attached slave agents:
EXPOSE 50000

CMD ["/usr/local/bin/jenkins.sh"]
