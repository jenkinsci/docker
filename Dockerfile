FROM eclipse-temurin:17-jdk-alpine

ENV JENKINS_HOME=/var/jenkins_home
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

RUN mkdir -p $JENKINS_HOME /usr/share/jenkins/ref/plugins

# Download only Jenkins WAR
RUN wget -q https://get.jenkins.io/war-stable/2.414.3/jenkins.war -O /usr/share/jenkins/jenkins.war

# Set permissions
RUN adduser -D -u 1000 jenkins && \
    chown -R jenkins:jenkins $JENKINS_HOME /usr/share/jenkins/ref

USER jenkins

EXPOSE 8080 50000

ENTRYPOINT ["java","-jar","/usr/share/jenkins/jenkins.war"]
