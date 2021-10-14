FROM bats-jenkins

# Define a custom location for the war
ENV JENKINS_WAR /test-custom-dockerfile/my-custom-jenkins.war
WORKDIR /test-custom-dockerfile
# Add there a new weird plugin to assert
COPY --chown=jenkins:jenkins WEB-INF/ WEB-INF/

USER root
RUN chown jenkins:jenkins /test-custom-dockerfile
USER jenkins

# Copy the original jenkins.war to the custom location 
RUN cp /usr/share/jenkins/jenkins.war $JENKINS_WAR && \
    chown jenkins:jenkins $JENKINS_WAR

# Add the weird plugin to the new custom war
RUN jar -uf my-custom-jenkins.war WEB-INF/* 

# Run the jenkins-plugin-cli script
RUN jenkins-plugin-cli --war $JENKINS_WAR --plugins junit:1.6
