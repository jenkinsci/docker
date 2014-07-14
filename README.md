# This is a WIP

Will likely form the basis of the official jenkins-ci image. Still working on it. 

To run: 

```
docker run -p 8080:8080 jenkins
```

To use a persistent volume

```
docker run --name myjenkins -p 8080:8080 -v /var/jenkins_home jenkins
```

The volume for the "myjenkins" named container will then be persistent.

You can also bind mount in a volume from the host: 


First, ensure that /your/home is accessible by the jenkins user in container (jenkins user - uid 102 normally - or use -u root), then: 

```
docker run -p 8080:8080 -v /your/home:/var/jenkins_home jenkins
```



