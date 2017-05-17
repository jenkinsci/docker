FROM java:8-jdk

# https://urllib3.readthedocs.org/en/latest/security.html#pyopenssl
RUN apt-get update && apt-get install -y build-essential python-dev python-pip libffi-dev libssl-dev && rm -rf /var/lib/apt/lists/* && \
    pip install --upgrade pip && \
    pip install urllib3 pyOpenSSL ndg-httpsclient pyasn1 docker-compose

ADD jenkins-slave.sh /usr/local/bin/

ENTRYPOINT /usr/local/bin/jenkins-slave.sh
