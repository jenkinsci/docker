FROM java:8-jdk

ENV JENKINS_UC "https://updates.jenkins.io"
ENV JENKINS_HOME "/var/jenkins_home"
ENV JENKINS_REF "/usr/share/jenkins/ref"
ENV JENKINS_SLAVE_AGENT_PORT 50000
ENV COPY_REFERENCE_FILE_LOG "$JENKINS_HOME/copy_reference_file.log"

ARG JENKINS_VERSION=1.651.3
ARG JENKINS_SHA=564e49fbd180d077a22a8c7bb5b8d4d58d2a18ce
ARG TINI_VERSION=0.9.0
ARG TINI_SHA=fa23d1e20732501c3bb8eeeca423c89ac80ed452

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000

RUN apt-get update \
    && apt-get install -y git curl zip \
    && rm -rf /var/lib/apt/lists/*

# Jenkins is started by $user:$group with $uid:$gid which defaults 
# respectively to 'jenkins:jenkins' and '1000:1000' (see above)
# If you bind mount a volume from the host or a data container, ensure 
# you use the same uid
RUN groupadd -g ${gid} ${group} \
    && useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -m -s /bin/bash ${user}

# $JENKINS_REF contains all reference configuration we want 
# to set on a fresh new installation. Use it to bundle additional plugins 
# or config file with your custom derived jenkins Dockerfile
RUN mkdir -p ${JENKINS_REF}

# Use tini as subreaper in Docker container to adopt zombie processes 
RUN curl -fsSL "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-static" -o /bin/tini \
    && chmod +x /bin/tini \
    && echo "$TINI_SHA  /bin/tini" | sha1sum -c -

# could use ADD but this one does not check Last-Modified header 
# see https://github.com/docker/docker/issues/8331
RUN curl -fsSL "http://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war" -o /usr/share/jenkins/jenkins.war \
    && echo "$JENKINS_SHA  /usr/share/jenkins/jenkins.war" | sha1sum -c -

# fix perms
RUN chown -R ${user}:${group} "$JENKINS_HOME" "$JENKINS_REF"

# $JENKINS_HOME is a volume, so configuration and build history 
# can be persisted and survive image upgrades
VOLUME $JENKINS_HOME

# expose webui and slave ports
EXPOSE 8080
EXPOSE ${JENKINS_SLAVE_AGENT_PORT}

# switch to non-root
USER ${user}

# Minimal configuration setup:
# Groovy script to set the slave agent port to $JENKINS_SLAVE_AGENT_PORT
RUN mkdir -p ${JENKINS_REF}/init.groovy.d
COPY init.groovy ${JENKINS_REF}/init.groovy.d/tcp-slave-agent-port.groovy

# Include script helpers to install plugins:
# from a derived Dockerfile, can use `RUN plugins.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY plugins.sh /usr/local/bin/plugins.sh
COPY install-plugins.sh /usr/local/bin/install-plugins.sh

COPY jenkins.sh /usr/local/bin/jenkins.sh
ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/jenkins.sh"]

