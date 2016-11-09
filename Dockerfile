FROM openjdk:8-jdk

RUN apt-get update && apt-get install -y git curl && rm -rf /var/lib/apt/lists/*

ENV JENKINS_HOME /var/jenkins_home
ENV JENKINS_SLAVE_AGENT_PORT 50000

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000

# Jenkins is run with user `jenkins`, uid = 1000
# If you bind mount a volume from the host or a data container, 
# ensure you use the same uid
RUN groupadd -g ${gid} ${group} \
    && useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -m -s /bin/bash ${user}

# Jenkins home directory is a volume, so configuration and build history 
# can be persisted and survive image upgrades
VOLUME /var/jenkins_home

# `/usr/share/jenkins/ref/` contains all reference configuration we want 
# to set on a fresh new installation. Use it to bundle additional plugins 
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

ENV TINI_VERSION 0.9.0
ENV TINI_SHA fa23d1e20732501c3bb8eeeca423c89ac80ed452

# Use tini as subreaper in Docker container to adopt zombie processes 
RUN curl -fsSL https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-static -o /bin/tini && chmod +x /bin/tini \
  && echo "$TINI_SHA  /bin/tini" | sha1sum -c -

COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy

# jenkins version being bundled in this docker image
ARG JENKINS_VERSION
ENV JENKINS_VERSION ${JENKINS_VERSION:-2.19.2}

# jenkins.war checksum, download will be validated using it
ARG JENKINS_SHA=32b8bd1a86d6d4a91889bd38fb665db4090db081

# Can be used to customize where jenkins.war get downloaded from
ARG JENKINS_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war

# could use ADD but this one does not check Last-Modified header neither does it allow to control checksum 
# see https://github.com/docker/docker/issues/8331
RUN curl -fsSL ${JENKINS_URL} -o /usr/share/jenkins/jenkins.war \
  && echo "${JENKINS_SHA}  /usr/share/jenkins/jenkins.war" | sha1sum -c -

ENV JENKINS_UC https://updates.jenkins.io
RUN chown -R ${user} "$JENKINS_HOME" /usr/share/jenkins/ref

# for main web interface:
EXPOSE 8080

# will be used by attached slave agents:
EXPOSE 50000

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

USER ${user}

COPY jenkins-support /usr/local/bin/jenkins-support
COPY jenkins.sh /usr/local/bin/jenkins.sh
ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/jenkins.sh"]

# from a derived Dockerfile, can use `RUN plugins.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY plugins.sh /usr/local/bin/plugins.sh
COPY install-plugins.sh /usr/local/bin/install-plugins.sh

FROM jenkins
RUN install-plugins.sh ace-editor:1.1 aws-java-sdk:1.11.37 bouncycastle-api:2.16.0 branch-api:1.11 cloudbees-folder:5.13 conditional-buildstep:1.3.5 copyartifact:1.38.1 credentials:2.1.8 display-url-api:0.5 durable-task:1.12 git:3.0.0 git-client:2.0.0 git-server:1.7 github:1.22.3 github-api:1.79 handlebars:1.1.1 icon-shim:2.0.3 jackson2-api:2.7.3 javadoc:1.4 job-dsl:1.52 jquery:1.11.2-0 jquery-detached:1.2.1 junit:1.19 mailer:1.18 matrix-auth:1.4 matrix-project:1.7.1 maven-plugin:2.14 momentjs:1.1.1 naginator:1.17.2 parameterized-trigger:2.32 pipeline-build-step:2.3 pipeline-graph-analysis:1.1 pipeline-input-step:2.3 pipeline-milestone-step:1.1 pipeline-rest-api:2.2 pipeline-stage-step:2.2 pipeline-stage-view:2.0 plain-credentials:1.3 run-condition:1.0 s3:0.10.10 scm-api:1.3 script-security:1.24 sonar:2.5 ssh-credentials:1.12 structs:1.5 token-macro:2.0 workflow-aggregator:2.4 workflow-api:2.5 workflow-basic-steps:2.3 workflow-cps:2.17 workflow-cps-global-lib:2.3 workflow-durable-task-step:2.5 workflow-job:2.8 workflow-multibranch:2.8 workflow-scm-step:2.2 workflow-step-api:2.5 workflow-support:2.10
