# The supercharged Jenking Docker v2 image (not official - based on alpine)

(https://wiki.jenkins-ci.org/download/attachments/2916393/superhero.svg)

This is the supercharged Jenkins Continuous Integration and Delivery server based up on the official release. [http://jenkins-ci.org/](http://jenkins-ci.org/).

## Usage

### Docker Client
```
docker run -p 8080:8080 serverking/jenkins
```
### Docker Compose (http)

```
version: '2'

services:

  jenkins:
    image: serverking/jenkins:latest
    privileged: true
    network_mode: "bridge"
    environment:
      - JAVA_OPTS=-Duser.timezone=Europe/Zurich
      - EXECUTORS=7
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /data/jenkins_home/builds:/var/jenkins_home/builds
      - /data/jenkins_home/workspaces:/var/jenkins_home/workspaces
    ports:
        - "8080:8080"
    restart: always
```
### Docker Compose (https)

```
version: '2'

services:

  jenkins:
    image: serverking/jenkins:latest
    privileged: true
    network_mode: "bridge"
    environment:
      - JAVA_OPTS=-Duser.timezone=Europe/Zurich
      - EXECUTORS=7
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /data/jenkins_home/builds:/var/jenkins_home/builds
      - /data/jenkins_home/workspaces:/var/jenkins_home/workspaces
      - /data/jenkins_home/certs:/var/jenkins_home/certs
    ports:
        - "8443:8443"
    restart: always
```

### Volumes

This Jenkins Docker image  will store job workspaces, builds and plugins internally to cope with Docker immutable infrastructure concept. To survive updates, it's highly tecommeded to use persistent volumes on your host. 


### Persistance and Backup

Persistance of workspaces and builds is accomplished by binding volumes to the host - you can simply back up this directory. The default configuration comes with a slightly modified directory structure to better comply with persistance:
*/var/jenkins_home/builds
*/var/jenkins_home/workspaces

The sample docker compose excerpt above shows how to bind those volumes. A default groovy init script will seamless rebuild the nextbuild number symlinks.

Refer to the Docker docs section on [Managing data in containers](https://docs.docker.com/userguide/dockervolumes/)


### Upgrading

As all the data needed is in the /var/jenkins_home directory - so depending on how you manage that - depends on how you upgrade. If you bind external host volumes for builds and workspaces, your jobs will be updated with jenkins. 


### Executors

The number of build executors can simply be defined by setting an environment variable on your docker container. By default its set to 2 executors, but you can extend the image and change it to your desired number of executors. This can be done by eighter follow the sample docker compose excerpt above or passing parameters to the run command like below:

```
docker run --name myjenkins -p 8080:8080 -e EXECUTORS=7 serverking/jenkins
```

### Attaching build executors

You can run builds out of the box. If you want to attach non-docker build slaves **through JNLP (Java Web Start)**: make sure you map the port: ```-p 50000:50000``` - which will be used when you connect a slave agent. If you are only using [SSH slaves](https://wiki.jenkins-ci.org/display/JENKINS/SSH+Slaves+plugin), then you do **NOT** need to put that port mapping. If you use the Docker Cloud plugin its strongly recommended to use SSH slaves.
You can also change the default legacy JNLP slave agent port for jenkins by defining `JENKINS_SLAVE_AGENT_PORT` in a derived Dockerfile.

### Passing JVM parameters

You might need to customize the JVM running Jenkins, typically to pass system properties like time zone, or tweak heap memory settings. Use JAVA_OPTS environment
variable for this purpose :

```
docker run --name myjenkins -p 8080:8080 -e JAVA_OPTS=-Dhudson.footerURL=http://mycompany.com serverking/jenkins
```

### Certificates

You also can define jenkins arguments as `JENKINS_OPTS`. This is usefull to define a set of arguments to pass to jenkins launcher. The following sample Dockerfile uses this option to force use of HTTPS with a certificate. For security reasons the certificate will be stored on the host and mounted in to the container. This can be done by eighter follow the sample docker compose excerpt above or passing parameters to the run command like below:

```
docker run --name myjenkins -p 8443:8443 -e JENKINS_OPTS="--httpPort=-1 --httpsPort=8443 --httpsCertificate=/var/jenkins_home/certs/fullchain.pem --httpsPrivateKey=/var/jenkins_home/certs/fullchain.key" serverking/jenkins
```

### Installing tools

You can derive this Dockerfile if you need more tools installed. In such a derived image, you can customize your jenkins instance with hook scripts or additional plugins. When jenkins container starts, it will copy the 'src/var/jenkins_home' to the container. 

### Installing plugins

For your convenience, you also can use a plain text file to define plugins to be installed (using core-support plugin format). All plugins need to be listed in the form `pluginID:version` as there is no transitive dependency resolution.
```
credentials:1.18
maven-plugin:2.7.1
groovy:latest
...
```

## Todo's
- [x] JenkinsCI official refactoring
- [ ] DSL plugin bootstrap setup 
- [ ] DSL sample jobs

