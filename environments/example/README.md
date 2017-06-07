A demo on how to organize multiple jenkins, where each environment can

 * specify its own FROM jenkins base image for a particular revision
 * modify its own list of plugins.txt to install on top of that image
 * customize its own groovy script to invoke on startup for a container of that image
 * maintain docker-compose.yml to represent the docker run parameters to supply representing the relationship between master and slave(s)

### Setup
```
cp -R ./environments/example ./environments/&lt;your machine&gt;
vi ./environments/&lt;your machine&gt;/docker-compose.yml
vi ./environments/&lt;your machine&gt;/Dockerfile
vi ./environments/&lt;your machine&gt;/plugins.txt
vi ./environments/&lt;your machine&gt;/*.groovy
```

### Build / Run
```
ssh &lt;your machine&gt;
git clone https://github.com/jenkinsci/docker; cd docker
cd ./environments/&lt;your machine&gt;
docker-compose build [--no-cache]
docker-compose up [-d]
```
