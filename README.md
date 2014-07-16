# This is a WIP

The Jenkins Continuous Integration and Continuous Delivery server. 

This is a fully functional Jenkins server. 

Note you can run builds on the master (out of the box) buf if you want to attach build slave servers: make sure you map the port: ```-p 50000:50000```. 

To run: 

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



