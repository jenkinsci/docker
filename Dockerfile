FROM alpine:latest

ADD src /

ENV JAVA_HOME /usr/lib/jvm/java-1.7-openjdk/jre
ENV JENKINS_HOME /var/jenkins_home
ENV JENKINS_SLAVE_AGENT_PORT 50000
ENV JENKINS_VERSION 2.0

# Packages
RUN apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/main && \
    apk add --no-cache --repository  http://dl-cdn.alpinelinux.org/alpine/edge/community && \
    apk update && \
    apk upgrade && \
    apk add ca-certificates supervisor openjdk7-jre-base java-common bash git curl zip wget docker ttf-dejavu && \
    rm -rf /var/cache/apk/*

# Docker compose
RUN echo "Installing docker-compose" && \
    curl -sSL --create-dirs --retry 1 https://github.com/docker/compose/releases/download/1.6.2/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose

# Jenkins
RUN echo "Installing jenkins ${JENKINS_VERSION}" && \
    curl -sSL --create-dirs --retry 1 http://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war -o /usr/share/jenkins/jenkins.war

# Jenkins plugins from plugins.txt
RUN while read plugin; do \
    echo "Downloading ${plugin}" && \
    curl -sSL --create-dirs --retry 1 https://updates.jenkins-ci.org/download/plugins/${plugin%:*}/${plugin#*:}/${plugin%:*}.hpi -o /var/jenkins_home/plugins/${plugin%:*}.jpi && \
    touch /var/jenkins_home/plugins/${plugin%:*}.jpi.pinned; \
    done < /var/jenkins_home/plugins.txt

EXPOSE 8080
EXPOSE 8443
EXPOSE 50000

ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
