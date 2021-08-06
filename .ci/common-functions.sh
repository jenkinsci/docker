docker-login() {
    if [ -n "$DOCKER_CONFIG" ]; then
      # Making use of the credentials stored in `config.json`
      echo "Using config.json"
      docker login
    else
      # Using username and password variables
      echo "Using username/password"
      docker login --username ${DOCKERHUB_USERNAME} --password ${DOCKERHUB_PASSWORD}
    fi
    echo "Docker logged in successfully"
}
