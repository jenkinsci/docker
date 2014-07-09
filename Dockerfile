FROM ubuntu:14.04
RUN apt-get update
RUN apt-get install -y wget git curl
RUN apt-get install -y --no-install-recommends openjdk-7-jdk
RUN apt-get install -y maven ant
RUN wget -q -O - http://pkg.jenkins-ci.org/debian/jenkins-ci.org.key | sudo apt-key add -
RUN echo deb http://pkg.jenkins-ci.org/debian binary/ >> /etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y jenkins
CMD exec su jenkins -c "java -jar /usr/share/jenkins/jenkins.war"