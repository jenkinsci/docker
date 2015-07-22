FROM registry.hub.docker.com/java:8

RUN curl -L https://github.com/docker/compose/releases/download/1.3.2/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose && \
	chmod +x /usr/local/bin/docker-compose

ADD slave.sh /tmp/slave.sh

CMD /tmp/slave.sh
