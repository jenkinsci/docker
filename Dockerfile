FROM centos:centos7
# description: https://github.com/jenkinsci/docker modified for centos7, oracle jdk-8u45

RUN yum install -y wget git curl tar createrepo && yum clean all

RUN cd /var/tmp \
  && curl --fail --location --retry 3 -O \
  --header "Cookie: oraclelicense=accept-securebackup-cookie; " \
  http://download.oracle.com/otn-pub/java/jdk/8u45-b14/jdk-8u45-linux-x64.rpm \
  && rpm -Ui jdk-8u45-linux-x64.rpm \
  && rm -rf jdk-8u45-linux-x64.rpm

ENV JENKINS_HOME /var/jenkins_home

# Jenkins is ran with user `jenkins`, uid = 1000
# If you bind mount a volume from host/vloume from a data container, 
# ensure you use same uid
RUN useradd -d "$JENKINS_HOME" -u 1000 -m -s /bin/bash jenkins

# Jenkins home directoy is a volume, so configuration and build history 
# can be persisted and survive image upgrades
VOLUME /var/jenkins_home

# `/usr/share/jenkins/ref/` contains all reference configuration we want 
# to set on a fresh new installation. Use it to bundle additional plugins 
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

# Use tini as subreaper in Docker container to adopt zombie processes 
RUN curl -fL https://github.com/krallin/tini/releases/download/v0.5.0/tini-static -o /bin/tini && chmod +x /bin/tini

ENV JENKINS_VERSION 1.596.3
ENV JENKINS_SHA bbfe03f35aad4e76ab744543587a04de0c7fe766

# could use ADD but this one does not check Last-Modified header 
# see https://github.com/docker/docker/issues/8331
RUN curl -fL http://mirrors.jenkins-ci.org/war-stable/$JENKINS_VERSION/jenkins.war -o /usr/share/jenkins/jenkins.war \
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
ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/jenkins.sh"]

# from a derived Dockerfile, can use `RUN plugin.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY plugins.sh /usr/local/bin/plugins.sh

# install dotci plugins
COPY plugins.dotci $JENKINS_HOME/plugins.dotci
RUN /usr/local/bin/plugins.sh $JENKINS_HOME/plugins.dotci

# uncomment to provide list of additional jenkins plugins to download/install
#COPY plugins.download $JENKINS_HOME/plugins.download
#RUN /usr/local/bin/plugins.sh $JENKINS_HOME/plugins.download

# uncomment to install additional jenkins plugins locally avaiable in repo
#COPY plugins.local /usr/share/jenkins/ref/plugins

# modify these scripts to configure your jenkins/DotCi
COPY init.groovy.d /usr/share/jenkins/ref/init.groovy.d
