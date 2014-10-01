FROM java:7u65

# Avoid debconf and initrd
ENV DEBIAN_FRONTEND noninteractive
ENV INITRD No

# Replace sh with bash
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Jenkins settings
ENV JENKINS_VERSION 1.565.3

# user id to be invoked as (otherwise will run as root; not wise!)
ENV JENKINS_USER jenkins

ENV JENKINS_WAR /usr/share/jenkins/jenkins.war
ENV JENKINS_HOME /var/lib/jenkins

# log location. This may be a syslog facility.priority
ENV JENKINS_LOG $JENKINS_HOME/log/$JENKINS_USER.log

# define url prefix for running jenkins behind reverse proxy
ENV JENKINS_PREFIX /

ENV JENKINS_MAXOPENFILES 8192
ENV JENKINS_ARGS --webroot=/var/cache/jenkins/war --httpPort=8080 --httpListenAddress=0.0.0.0 --ajp13Port=-1 --prefix=$JENKINS_PREFIX --sessionTimeout=10080

ENV JAVA /usr/bin/java
ENV JAVA_ARGS -Djava.awt.headless=true -Xms256m -Xmx512m -XX:PermSize=128m -XX:MaxPermSize=256m

ENV TZ UTC

# Installing all required packages
RUN apt-get update && apt-get install -y wget git curl zip && rm -rf /var/lib/apt/lists/*

# gpg: key D50582E6: public key "Kohsuke Kawaguchi <kk@kohsuke.org>" imported
# see also http://pkg.jenkins-ci.org/debian-stable/jenkins-ci.org.key
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 150FDE3F7787E7D11EF4E12A9B7D32F2D50582E6
# from: curl -sSL 'http://pkg.jenkins-ci.org/debian-stable/jenkins-ci.org.key' | docker run -i --rm debian bash -c 'gpg --import && gpg --fingerprint'

RUN echo deb http://pkg.jenkins-ci.org/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list

RUN apt-get update && apt-get install -y jenkins="${JENKINS_VERSION}" && rm -rf /var/lib/apt/lists/*

RUN usermod -m -d "$JENKINS_HOME" "$JENKINS_USER" && chown -R "$JENKINS_USER" "$JENKINS_HOME"

# Cannot use $JENKINS_USER as reference, see issue:
# https://github.com/docker/docker/issues/4909
VOLUME /var/lib/jenkins

COPY init.groovy /tmp/WEB-INF/init.groovy
RUN cd /tmp && zip -g $JENKINS_WAR WEB-INF/init.groovy && rm -rf /tmp/WEB-INF

# for main web interface:
EXPOSE 8080

# will be used by attached slave agents:
EXPOSE 50000

COPY ./jenkins.sh /usr/local/bin/jenkins.sh

# Download & installing plugins
RUN mkdir -p /plugins
RUN chown -R $JENKINS_USER /plugins
COPY ./jenkins_plugins.sh /jenkins_plugins.sh
RUN chmod +x /jenkins_plugins.sh

# Only installing plugins when downstream image used this as a base image
ONBUILD ADD ./plugins.txt /plugins.txt
ONBUILD RUN /jenkins_plugins.sh

# Cannot use symlink, need to actually replace all the plugins at all time to
# ensure they are actually at the same version.
ONBUILD RUN rm -rf $JENKINS_HOME/plugins

# Cannot use $JENKINS_USER as reference, see issue:
# https://github.com/docker/docker/issues/4909
USER jenkins

CMD ["/usr/local/bin/jenkins.sh"]
