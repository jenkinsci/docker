docker-login() {
    if [ -z "$DOCKER_CONFIG" ]; then
      # Making use of the credentials stored in `config.json`
      docker login
    else
      # Using username and password variables
      docker login --username ${DOCKERHUB_USERNAME} --password ${DOCKERHUB_PASSWORD}
    fi
    echo "Docker logged in successfully"
}

docker-enable-experimental() {
    # Enables experimental to utilize `docker manifest` command
    echo "Enabling Docker experimental...."
    export DOCKER_CLI_EXPERIMENTAL="enabled"
}
