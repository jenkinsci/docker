# Jenkins on Docker

![](https://libs.websoft9.com/common/websott9-cloud-installer.png) 

## Introduction

[English](/README.md) | [简体中文](/README-zh.md)  

This repository is an **Cloud Native solution** powered by [Websoft9](https://www.websoft9.com), it simplifies the complicated installation and initialization process.  

<<<<<<< HEAD
## System Requirements

The following are the minimal [recommended requirements](https://www.jenkins.io/doc/book/installing/docker/):

* **OS**: Red Hat, CentOS, Debian, Ubuntu or other's Linux OS
* **Public Cloud**: More than 20+ major Cloud such as AWS, Azure, Google Cloud, Alibaba Cloud, HUAWEIClOUD, Tencent Cloud
* **Private Cloud**: KVM, VMware, VirtualBox, OpenStack
* **ARCH**:  Linux x86-64, ARM 32/64, Windows x86-64, IBM POWER8, x86/i686
* **RAM**: 1 GB or more
* **CPU**: 1 cores or higher
* **HDD**: at least 1 GB of free space
* **Swap file**: at least  GB
* **bandwidth**: more fluent experience over 100M  
=======
# Usage

```
docker run -p 8080:8080 -p 50000:50000 jenkins/jenkins:lts-jdk11
```

NOTE: read the section [_Connecting agents_](#connecting-agents) below for the role of the `50000` port mapping.

This will store the workspace in `/var/jenkins_home`.
All Jenkins data lives in there - including plugins and configuration.
You will probably want to make that an explicit volume so you can manage it and attach to another container for upgrades :

```
docker run -p 8080:8080 -p 50000:50000 -v jenkins_home:/var/jenkins_home jenkins/jenkins:lts-jdk11
```

This will automatically create a 'jenkins_home' [docker volume](https://docs.docker.com/storage/volumes/) on the host machine.
Docker volumes retain their content even when the container is stopped, started, or deleted.

NOTE: Avoid using a [bind mount](https://docs.docker.com/storage/bind-mounts/) from a folder on the host machine into `/var/jenkins_home`, as this might result in file permission issues (the user used inside the container might not have rights to the folder on the host machine).
If you _really_ need to bind mount jenkins_home, ensure that the directory on the host is accessible by the jenkins user inside the container (jenkins user - uid 1000) or use `-u some_other_user` parameter with `docker run`.

```
docker run -d -v jenkins_home:/var/jenkins_home -p 8080:8080 -p 50000:50000 jenkins/jenkins:lts-jdk11
```

this will run Jenkins in detached mode with port forwarding and volume added. You can access logs with command 'docker logs CONTAINER_ID' in order to check first login token. ID of container will be returned from output of command above.

## Backing up data

If you bind mount in a volume - you can simply back up that directory
(which is jenkins_home) at any time.

This is highly recommended. Treat the jenkins_home directory as you would a database - in Docker you would generally put a database on a volume.

If your volume is inside a container - you can use `docker cp $ID:/var/jenkins_home` command to extract the data, or other options to find where the volume data is.
Note that some symlinks on some OSes may be converted to copies (this can confuse jenkins with lastStableBuild links etc)

For more info check Docker docs section on [Use volumes](https://docs.docker.com/storage/volumes/)

# Setting the number of executors

You can define the number of executors on the Jenkins built-in node using a groovy script.
By default it is set to 2 executors, but you can extend the image and change it to your desired number of executors (recommended 0 executors on the built-in node) :

`executors.groovy`
```
import jenkins.model.*
Jenkins.instance.setNumExecutors(0) // Recommended to not run builds on the built-in node
```

and `Dockerfile`

```
FROM jenkins/jenkins:lts
COPY --chown=jenkins:jenkins executors.groovy /usr/share/jenkins/ref/init.groovy.d/executors.groovy
```

# Connecting agents

You can run builds on the controller out of the box.
The Jenkins project recommends that no executors be enabled on the controller.

In order to connect agents **through an inbound TCP connection**, map the port: `-p 50000:50000`.
That port will be used when you connect agents to the controller.

If you are only using [SSH (outbound) build agents](https://plugins.jenkins.io/ssh-slaves/), this port is not required, as connections are established from the controller.
If you connect agents using web sockets (since Jenkins 2.217), the TCP agent port is not used either.

# Passing JVM parameters

You might need to customize the JVM running Jenkins, typically to adjust [system properties](https://www.jenkins.io/doc/book/managing/system-properties/) or tweak heap memory settings.
Use the `JAVA_OPTS` environment variable for this purpose :

```
docker run --name myjenkins -p 8080:8080 -p 50000:50000 --env JAVA_OPTS=-Dhudson.footerURL=http://mycompany.com jenkins/jenkins:lts-jdk11
```

# Configuring logging

Jenkins logging can be configured through a properties file and `java.util.logging.config.file` Java property.
For example:

```
mkdir data
cat > data/log.properties <<EOF
handlers=java.util.logging.ConsoleHandler
jenkins.level=FINEST
java.util.logging.ConsoleHandler.level=FINEST
EOF
docker run --name myjenkins -p 8080:8080 -p 50000:50000 --env JAVA_OPTS="-Djava.util.logging.config.file=/var/jenkins_home/log.properties" -v `pwd`/data:/var/jenkins_home jenkins/jenkins:lts-jdk11
```

# Configuring reverse proxy
If you want to install Jenkins behind a reverse proxy with prefix, example: mysite.com/jenkins, you need to add environment variable `JENKINS_OPTS="--prefix=/jenkins"` and then follow the below procedures to configure your reverse proxy, which will depend if you have Apache or Nginx:
- [Apache](https://www.jenkins.io/doc/book/system-administration/reverse-proxy-configuration-apache/)
- [Nginx](https://www.jenkins.io/doc/book/system-administration/reverse-proxy-configuration-nginx/)

# Passing Jenkins launcher parameters

Arguments you pass to docker running the Jenkins image are passed to jenkins launcher, so for example you can run:
```
docker run jenkins/jenkins:lts-jdk11 --version
```
This will show the Jenkins version, the same as when you run Jenkins from an executable war.
>>>>>>> 5c5a80d26c251a87c0f897778a9886ca477d1ca4

## QuickStart

<<<<<<< HEAD
### All-in-one Installer

Use SSH to connect your instance and run the automatic installation script below

```
sudo wget -N https://raw.githubusercontent.com/Websoft9/docker-template/main/docker-installer.sh; sudo bash docker-installer.sh -r jenkins
```
### package install
=======
```
FROM jenkins/jenkins:lts-jdk11

COPY --chown=jenkins:jenkins https.pem /var/lib/jenkins/cert
COPY --chown=jenkins:jenkins https.key /var/lib/jenkins/pk
ENV JENKINS_OPTS --httpPort=-1 --httpsPort=8083 --httpsCertificate=/var/lib/jenkins/cert --httpsPrivateKey=/var/lib/jenkins/pk
EXPOSE 8083
```

You can also change the default agent port for Jenkins by defining `JENKINS_SLAVE_AGENT_PORT` in a sample Dockerfile.

```
FROM jenkins/jenkins:lts-jdk11
ENV JENKINS_SLAVE_AGENT_PORT 50001
```
or as a parameter to docker,
```
docker run --name myjenkins -p 8080:8080 -p 50001:50001 --env JENKINS_SLAVE_AGENT_PORT=50001 jenkins/jenkins:lts-jdk11
```

**Note**: This environment variable will be used to set the port adding the
[system property][https://www.jenkins.io/doc/book/managing/system-properties/] `jenkins.model.Jenkins.slaveAgentPort` to **JAVA_OPTS**.

> If this property is already set in **JAVA_OPTS**, then the value of
`JENKINS_SLAVE_AGENT_PORT` will be ignored.

# Installing more tools

You can run your container as root - and install via apt-get, install as part of build steps via jenkins tool installers, or you can create your own Dockerfile to customise, for example:
>>>>>>> 5c5a80d26c251a87c0f897778a9886ca477d1ca4

1.Make package
You can get the  package as following script
```
<<<<<<< HEAD
sudo wget -N https://raw.githubusercontent.com/Websoft9/docker-template/main/docker-installer.sh; sudo bash docker-installer.sh -r jenkins -p
=======
FROM jenkins/jenkins:lts-jdk11
# if we want to install via apt
USER root
RUN apt-get update && apt-get install -y ruby make more-thing-here
# drop back to the regular jenkins user - good practice
USER jenkins
>>>>>>> 5c5a80d26c251a87c0f897778a9886ca477d1ca4
```

2.Install by package
Copy package to your server, Use SSH to connect your instance and run the automatic installation script below
```
<<<<<<< HEAD
sudo bash install-jenkins
=======
FROM jenkins/jenkins:lts-jdk11
COPY --chown=jenkins:jenkins custom.groovy /usr/share/jenkins/ref/init.groovy.d/custom.groovy
>>>>>>> 5c5a80d26c251a87c0f897778a9886ca477d1ca4
```

### Manual Installation

#### Preparation

<<<<<<< HEAD
If you have not install Docker and Docker-Compose, refer to the following commands to install it:
=======
During the download, the script will use update centers defined by the following environment variables:

* `JENKINS_UC` - Main update center.
  This update center may offer plugin versions depending on the Jenkins LTS Core versions.
  Default value: https://updates.jenkins.io
* `JENKINS_UC_EXPERIMENTAL` - [Experimental Update Center](https://jenkins.io/blog/2013/09/23/experimental-plugins-update-center/).
  This center offers Alpha and Beta versions of plugins.
  Default value: https://updates.jenkins.io/experimental
* `JENKINS_INCREMENTALS_REPO_MIRROR` -
  Defines Maven mirror to be used to download plugins from the
  [Incrementals repo](https://jenkins.io/blog/2018/05/15/incremental-deployment/).
  Default value: https://repo.jenkins-ci.org/incrementals
* `JENKINS_UC_DOWNLOAD` - Download url of the Update Center.
  Default value: `$JENKINS_UC/download`

It is possible to override the environment variables in images.

:exclamation: Note that changing update center variables **will not** change the Update Center being used by Jenkins runtime.

### Plugin installation manager CLI (Preview)

You can also use the `jenkins-plugin-cli` tool to install plugins.
This CLI will perform downloads from update centers, and internet access is required for the default update centers.

See the CLI's [documentation](https://github.com/jenkinsci/plugin-installation-manager-tool) for more information,
or run `jenkins-plugin-cli --help` to see the available options.

### Installing Custom Plugins

Installing prebuilt, custom plugins can be accomplished by copying the plugin HPI file into `/usr/share/jenkins/ref/plugins/` within the `Dockerfile`:
>>>>>>> 5c5a80d26c251a87c0f897778a9886ca477d1ca4

```
curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh
curl -L "https://github.com/docker/compose/releases/download/1.29.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose  /usr/bin
sudo systemctl start docker
```
<<<<<<< HEAD
=======

### Usage
>>>>>>> 5c5a80d26c251a87c0f897778a9886ca477d1ca4

#### Install Jenkins

<<<<<<< HEAD
We assume that you are already familiar with Docker, and you can modify [docker-compose file](docker-compose-production.yml) by yourself

```
git clone --depth=1 https://github.com/Websoft9/docker-jenkins
cd docker-jenkins
docker-compose -f docker-compose-production.yml  --env-file  .env_all up -d
```

### FAQ
=======
#### Plugin installation manager CLI

```Dockerfile
FROM jenkins/jenkins:lts-jdk11
RUN jenkins-plugin-cli --plugins pipeline-model-definition github-branch-source:1.8
```

Furthermore it is possible to pass a file that contains this set of plugins (with or without line breaks).

#### install-plugins script (Deprecated)

```Dockerfile
FROM jenkins/jenkins:lts-jdk11
RUN /usr/local/bin/install-plugins.sh pipeline-model-definition github-branch-source:1.8
```

#### install-plugins script

```Dockerfile
FROM jenkins/jenkins:lts-jdk11
COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN /usr/local/bin/install-plugins.sh < /usr/share/jenkins/ref/plugins.txt
```

#### Plugin installation manager CLI (Preview)

```Dockerfile
FROM jenkins/jenkins:lts-jdk11
COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli -f /usr/share/jenkins/ref/plugins.txt
```

When jenkins container starts, it will check `JENKINS_HOME` has this reference content, and copy them
there if required. It will not override such files, so if you upgraded some plugins from UI they won't
be reverted on next start.

In case you *do* want to override, append '.override' to the name of the reference file. E.g. a file named
`/usr/share/jenkins/ref/config.xml.override` will overwrite an existing `config.xml` file in JENKINS_HOME.

Also see [JENKINS-24986](https://issues.jenkins.io/browse/JENKINS-24986)

Here is an example to get the list of plugins from an existing server:

```
JENKINS_HOST=username:password@myhost.com:port
curl -sSL "http://$JENKINS_HOST/pluginManager/api/xml?depth=1&xpath=/*/*/shortName|/*/*/version&wrapper=plugins" | perl -pe 's/.*?<shortName>([\w-]+).*?<version>([^<]+)()(<\/\w+>)+/\1 \2\n/g'|sed 's/ /:/'
```

Example Output:

```
cucumber-testresult-plugin:0.8.2
pam-auth:1.1
matrix-project:1.4.1
script-security:1.13
...
```

For 2.x-derived images, you may also want to

    RUN echo 2.0 > /usr/share/jenkins/ref/jenkins.install.UpgradeWizard.state

to indicate that this Jenkins installation is fully configured.
Otherwise a banner will appear prompting the user to install additional plugins,
which may be inappropriate.

### Updating plugins file (Preview)

The [plugin-installation-manager-tool](https://github.com/jenkinsci/plugin-installation-manager-tool) supports updating the plugin file for you.

Example command:

```command
JENKINS_IMAGE=jenkins/jenkins:lts-jdk11
docker run -it ${JENKINS_IMAGE} bash -c "stty -onlcr && jenkins-plugin-cli -f /usr/share/jenkins/ref/plugins.txt --available-updates --output txt" >  plugins2.txt
mv plugins2.txt plugins.txt
```
>>>>>>> 5c5a80d26c251a87c0f897778a9886ca477d1ca4

#### Do I need to change the password before docker-compose up?
Yes, you should modify all database password and application password at docker-compose file for production

<<<<<<< HEAD
#### Docker runing failed for the reason that port conflict?
You should modify ports at [docker-compose file](docker-compose-production.yml) and docker-compose again
=======
All the data needed is in the /var/jenkins_home directory - so depending on how you manage that - depends on how you upgrade.
Generally - you can copy it out - and then "docker pull" the image again - and you will have the latest LTS - you can then start up with -v pointing to that data (/var/jenkins_home) and everything will be as you left it.
>>>>>>> 5c5a80d26c251a87c0f897778a9886ca477d1ca4

### Usage instructions

You can point your browser to: *`http://Instance's Internet IP:9001`*  

<<<<<<< HEAD
The following is the information that may be needed during use
=======
By default, plugins will be upgraded if they haven't been upgraded manually and if the version from the docker image is newer than the version in the container.
Versions installed by the docker image are tracked through a marker file.
>>>>>>> 5c5a80d26c251a87c0f897778a9886ca477d1ca4

#### Services and Ports

<<<<<<< HEAD
| Service | Port | Use |  Necessity |
| --- | --- | --- | --- |
| jenkins | 9001 | access Jenkins by browse | Y |
## Documentation
=======
The default behaviour when upgrading from a docker image that didn't write marker files is to leave existing plugins in place.
If you want to upgrade existing plugins without marker you may run the docker image with `-e TRY_UPGRADE_IF_NO_MARKER=true`.
Then plugins will be upgraded if the version provided by the docker image is newer.
>>>>>>> 5c5a80d26c251a87c0f897778a9886ca477d1ca4

[Jenkins Administrator Guide](https://support.websoft9.com/docs/jenkins)

## Enterprise Support

If you want to get our Enterprise Support to ensure high availability of applications, you can subscribe our [Jenkins Enterprise Support](https://apps.websoft9.com/jenkins) 

<<<<<<< HEAD
What you get with a Enterprise Support subscription?

* Knowledge: Answers and guidance from product experts
* Support: Everything you need for technical support, e.g Enable HTTPS, Upgrade guide
* Security: Security services and tools to protect your software
=======
We're on Gitter, https://gitter.im/jenkinsci/docker
>>>>>>> 5c5a80d26c251a87c0f897778a9886ca477d1ca4
