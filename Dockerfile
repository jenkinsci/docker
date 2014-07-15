FROM ubuntu:14.04
 
RUN apt-get update && apt-get install -y wget git curl
RUN apt-get update && apt-get install -y --no-install-recommends openjdk-7-jdk
RUN apt-get update && apt-get install -y maven ant
RUN wget -q -O - http://pkg.jenkins-ci.org/debian/jenkins-ci.org.key | sudo apt-key add -
RUN echo deb http://pkg.jenkins-ci.org/debian binary/ >> /etc/apt/sources.list
RUN apt-get update && apt-get install -y jenkins
RUN mkdir -p /var/jenkins_home && chown -R jenkins /var/jenkins_home
ADD init.groovy /tmp/WEB-INF/init.groovy
RUN apt-get install -y zip && cd /tmp && zip -g /usr/share/jenkins/jenkins.war WEB-INF/init.groovy
USER jenkins



# VOLUME /var/jenkins_home
ENV JENKINS_HOME /var/jenkins_home
EXPOSE 8080
CMD ["/usr/bin/java",  "-jar",  "/usr/share/jenkins/jenkins.war"]