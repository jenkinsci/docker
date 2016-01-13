FROM java:8-jdk

RUN apt-get update && apt-get install -y wget git curl zip && rm -rf /var/lib/apt/lists/*

ENV JENKINS_HOME /srv/jenkins_home
ENV JENKINS_SLAVE_AGENT_PORT 50000

#
# XXX: 
# Jenkins is assumed to run on 251 just to have the
# same UID outside/inside the container when mapping the volume
#
#
# Jenkins is run with user `jenkins`, uid = 251
# If you bind mount a volume from the host or a data container, 
# ensure you use the same uid
RUN useradd -d "$JENKINS_HOME" -u 251 -m -s /bin/bash jenkins


# `/usr/share/jenkins/ref/` contains all reference configuration we want 
# to set on a fresh new installation. Use it to bundle additional plugins 
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

ENV TINI_SHA 066ad710107dc7ee05d3aa6e4974f01dc98f3888

# Use tini as subreaper in Docker container to adopt zombie processes 
RUN curl -fL https://github.com/krallin/tini/releases/download/v0.5.0/tini-static -o /bin/tini && chmod +x /bin/tini \
  && echo "$TINI_SHA /bin/tini" | sha1sum -c -

COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy

ENV JENKINS_VERSION 1.632
ENV JENKINS_SHA 59034b776910235ca21436ee8f5f5069fd32048a

# could use ADD but this one does not check Last-Modified header 
# see https://github.com/docker/docker/issues/8331
RUN curl -fL http://mirrors.jenkins-ci.org/war/$JENKINS_VERSION/jenkins.war -o /usr/share/jenkins/jenkins.war \
  && echo "$JENKINS_SHA /usr/share/jenkins/jenkins.war" | sha1sum -c -

ENV JENKINS_UC https://updates.jenkins-ci.org
RUN chown -R jenkins "$JENKINS_HOME" /usr/share/jenkins/ref

# for main web interface:
EXPOSE 8080

# will be used by attached slave agents:
EXPOSE 50000

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

USER jenkins

COPY jenkins.sh /usr/local/bin/jenkins.sh

# from a derived Dockerfile, can use `RUN plugins.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY plugins.sh /usr/local/bin/plugins.sh
COPY plugins.txt /plugins.txt
RUN plugins.sh /plugins.txt

# Jenkins home directory is a volume, so configuration and build history 
# can be persisted and survive image upgrades
VOLUME /srv/jenkins_home
WORKDIR /srv/jenkins_home
ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/jenkins.sh"]

