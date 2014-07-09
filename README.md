# This is a WIP

Will likely form the basis of the official jenkins-ci image. Still working on it. 

To run: 

```
docker run -it -p 8080:8080 jenkins
```

To use a persistent volume

```
docker run -it -p 8080:8080 -v /your/home:/var/jenkins_home
```

You can also specify that it will run under the jenkins user: 

```
docker run -it -u jenkins -p 8080:8080 -v /your/home:/var/lib/jenkins/home jenkins
```

Ensure that /your/home is accessible by the jenkins user in container (jenkins user - uid 102 normally)
