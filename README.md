# Official Jenkins Docker image

The Jenkins Continuous Integration and Delivery server. 

This is a fully functional Jenkins server, based on the Long Term Support release
http://jenkins-ci.org/


<img src="http://jenkins-ci.org/sites/default/files/jenkins_logo.png"/>


# Usage

```
docker run -p 8080:8080 jenkins
```

This will store the workspace in /var/jenkins_home. All Jenkins data lives in there - including plugins and configuration. You will probably want to make that a persistent volume:

```
docker run --name myjenkins -p 8080:8080 -v /var/jenkins_home jenkins
```

The volume for the "myjenkins" named container will then be persistent.

You can also bind mount in a volume from the host: 

First, ensure that /your/home is accessible by the jenkins user in container (jenkins user - uid 102 normally - or use -u root), then: 

```
docker run -p 8080:8080 -v /your/home:/var/jenkins_home jenkins
```

## Backing up data

If you bind mount in a volume - you can simply back up that directory (which is jenkins_home) at any time. 

If your volume is inside a container - you can use ```docker cp $ID:/var/jenkins_home``` command to extract the data. 

# Attaching build executors 

You can run builds on the master (out of the box) buf if you want to attach build slave servers: make sure you map the port: ```-p 50000:50000``` - which will be used when you connect a slave agent.


# Upgrading

All the data needed is in the /var/jenkins_home directory - so depending on how you manage that - depends on how you upgrade. Generally - you can copy it out - and then "docker pull" the image again - and you will have the latest LTS - you can then start up with -v pointing to that data (/var/jenkins_home) and everything will be as you left it. 



