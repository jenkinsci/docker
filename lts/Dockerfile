FROM ubuntu:14.04
RUN apt-get update
RUN apt-get install -y wget git curl
RUN apt-get install -y --no-install-recommends openjdk-7-jdk
RUN apt-get install -y maven ant
RUN wget -q -O - http://pkg.jenkins-ci.org/debian-stable/jenkins-ci.org.key | apt-key add -
RUN echo deb http://pkg.jenkins-ci.org/debian-stable binary/ >> /etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y jenkins
RUN mkdir -p /var/jenkins_home && chown -R jenkins /var/jenkins_home
USER jenkins

VOLUME /var/jenkins_home
ENV JENKINS_HOME /var/jenkins_home
EXPOSE 8080
CMD java -jar /usr/share/jenkins/jenkins.war