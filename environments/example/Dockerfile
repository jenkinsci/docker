FROM jenkins:1.609.3

# root is required to modify uid
USER root

ENV JENKINS_USER jenkins

###########################################################
# $ docker run --name jenkins -d jenkins:1.609.3; docker exec -it jenkins id -a; docker stop jenkins; docker rm -vf jenkins
# uid=1000(jenkins) gid=1000(jenkins) groups=1000(jenkins)
#RUN usermod --uid xxx --login $JENKINS_USER jenkins
###########################################################

# insure VOLUME is mountable now by above changes
RUN chown -R $JENKINS_USER "$JENKINS_HOME" /usr/share/jenkins/ref

# restore ENTRYPOINT to startup as jenkins user
USER $JENKINS_USER

# list of jenkins plugins to install
COPY plugins.txt /usr/share/jenkins/ref/

# download jenkins plugins from JENKINS_UC
RUN /usr/local/bin/plugins.sh /usr/share/jenkins/ref/plugins.txt

# uncomment to local plugin file(s) into docker image
#ADD *.?pi /usr/share/jenkins/ref/plugins/

# additional groovy scripts to be executed on startup
COPY *.groovy /usr/share/jenkins/ref/init.groovy.d/
