FROM bats-jenkins-8-alpine-hotspot
#bats-jenkins-install-plugins

ARG REF
ENV REF=${REF}
WORKDIR ${REF}

RUN /usr/local/bin/install-plugins.sh junit:1.28 ant:1.3
