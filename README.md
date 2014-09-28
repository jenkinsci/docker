# Official Jenkins Docker image

The Jenkins Continuous Integration and Delivery server.

This is a fully functional Jenkins server, based on the Long Term Support release
http://jenkins-ci.org/


<img src="http://jenkins-ci.org/sites/default/files/jenkins_logo.png"/>


# Usage

```
docker run -p 8080:8080 jenkins
```

This will store the workspace in /var/jenkins_home. All Jenkins data lives in there - including plugins and configuration.
You will probably want to make that a persistent volume (recommended):

```
docker run -p 8080:8080 -v /your/home:/var/jenkins_home jenkins
```

This will store the jenkins data in /your/home on the host.
Ensure that /your/home is accessible by the jenkins user in container (jenkins user - uid 102 normally - or use -u root).


You can also use a volume container:

```
docker run --name myjenkins -p 8080:8080 -v /var/jenkins_home jenkins
```

Then myjenkins container has the volume (please do read about docker volume handling to find out more).

## Backing up data

If you bind mount in a volume - you can simply back up that directory
(which is jenkins_home) at any time.

This is highly recommended. Treat the jenkins_home directory as you would a database - in Docker you would generally put a database on a volume.

If your volume is inside a container - you can use ```docker cp $ID:/var/jenkins_home``` command to extract the data.
Note that some symlinks on some OSes may be converted to copies (this can confuse jenkins with lastStableBuild links etc)

# Attaching build executors

You can run builds on the master (out of the box) buf if you want to attach build slave servers: make sure you map the port: ```-p 50000:50000``` - which will be used when you connect a slave agent.

<a href="https://registry.hub.docker.com/u/maestrodev/build-agent/">Here</a> is an example docker container you can use as a build server with lots of good tools installed - which is well worth trying.

# Installing more tools

You can run your container as root - and unstall via apt-get, install as part of build steps via jenkins tool installers, or you can create your own Dockerfile to customise, for example: 

```
FROM jenkins
USER root # if we want to install via apt
RUN apt-get install -y ruby make more-thing-here
USER jenkins # drop back to the regular jenkins user - good practice

```
# Upgrading

All the data needed is in the /var/jenkins_home directory - so depending on how you manage that - depends on how you upgrade. Generally - you can copy it out - and then "docker pull" the image again - and you will have the latest LTS - you can then start up with -v pointing to that data (/var/jenkins_home) and everything will be as you left it.

As always - please ensure that you know how to drive docker - especially volume handling!

# Questions?

Jump on irc.freenode.net and the #jenkins room. Ask!
