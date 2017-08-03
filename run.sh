#!/bin/bash

docker build -t bf-jeckins:alpine .

docker rm -f bf-jeckins-alpine

export jenkins_home='/var/jenkins_home'

mkdir -p $jenkins_home

chown -R 1000:1000 $jenkins_home

docker run -itd --name bf-jeckins-alpine \
--restart always \
-p 3721:8080 -p 3824:50000 \
-v $jenkins_home:/var/jenkins_home -e JAVA_OPTS=-Duser.timezone=Asia/Shanghai \
bf-jeckins:alpine

docker restart bf-jeckins-alpine
