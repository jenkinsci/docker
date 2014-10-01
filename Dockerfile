#FROM java:openjdk-7u65-jdk
FROM java:7u65

RUN apt-get update && apt-get install -y wget git curl zip && rm -rf /var/lib/apt/lists/*

# gpg: key D50582E6: public key "Kohsuke Kawaguchi <kk@kohsuke.org>" imported
# see also http://pkg.jenkins-ci.org/debian-stable/jenkins-ci.org.key
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 150FDE3F7787E7D11EF4E12A9B7D32F2D50582E6
# from: curl -sSL 'http://pkg.jenkins-ci.org/debian-stable/jenkins-ci.org.key' | docker run -i --rm debian bash -c 'gpg --import && gpg --fingerprint'

RUN echo deb http://pkg.jenkins-ci.org/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list

ENV JENKINS_VERSION 1.565.2

RUN apt-get update && apt-get install -y jenkins="${JENKINS_VERSION}" && rm -rf /var/lib/apt/lists/*

ENV JENKINS_HOME /var/jenkins_home
RUN usermod -m -d "$JENKINS_HOME" jenkins && chown -R jenkins "$JENKINS_HOME"
VOLUME /var/jenkins_home

COPY init.groovy /tmp/WEB-INF/init.groovy
RUN cd /tmp && zip -g /usr/share/jenkins/jenkins.war WEB-INF/init.groovy && rm -rf /tmp/WEB-INF

# define url prefix for running jenkins behind Apache (https://wiki.jenkins-ci.org/display/JENKINS/Running+Jenkins+behind+Apache)
ENV JENKINS_PREFIX /

# for main web interface:
EXPOSE 8080

# will be used by attached slave agents:
EXPOSE 50000

COPY ./jenkins.sh /usr/local/bin/jenkins.sh
USER jenkins
CMD ["/usr/local/bin/jenkins.sh"]
