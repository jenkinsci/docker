## Usage

Start Jenkins in a Docker container:

```bash
docker run -p 8080:8080 -p 50000:50000 \
  --restart=on-failure \
  jenkins/jenkins:lts-jdk21
```

### Persist Jenkins Data

To keep your Jenkins configuration, plugins, and jobs when the container is removed, use a named Docker volume:

```bash
docker run -p 8080:8080 -p 50000:50000 \
  --restart=on-failure \
  -v jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts-jdk21
```

### Access Jenkins

1. Open your web browser.
2. Visit http://localhost:8080.
3. Follow the Jenkins setup wizard.

### Retrieve the Initial Admin Password

To display the initial administrator password, run:

```bash
docker exec <container_name> \
  cat /var/jenkins_home/secrets/initialAdminPassword
```

Replace `<container_name>` with your Jenkins container's name or ID.
