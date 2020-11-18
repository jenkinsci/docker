#!/bin/bash -eu
set -eou pipefail

source ./.ci/common-functions.sh > /dev/null 2>&1

get_docker_uri() {
    # Build image uri so it is compatible with dockerhub deployment  i.e. registry/namespace/image:tag-arch
    DOCKER_REPO=${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${DOCKER_IMAGE_NAME}
    DOCKER_BUILD_TAG=${DOCKER_BUILD_TAG}-${DOCKER_ARCH}
    DOCKER_URI="${DOCKER_REPO}:${DOCKER_BUILD_TAG}"

    DOCKER_URI=$(echo ${DOCKER_URI} | sed 's/^\/*//')  # strip off all leading '/' characters
    echo ${DOCKER_URI}
}

is-published() {
    local opts=""

    if [[ "$DEBUG" = true ]]; then
        opts="-v"
    fi

    local http_code;
    http_code=$(curl $opts -q -fsL -o /dev/null -w "%{http_code}" "https://hub.docker.com/v2/repositories/${DOCKER_NAMESPACE}/${DOCKER_IMAGE_NAME}/tags/${DOCKER_BUILD_TAG}-${DOCKER_ARCH}")

    if [[ "$http_code" -eq "404" ]]; then
        false
    elif [[ "$http_code" -eq "200" ]]; then
        true
    else
        echo "Received unexpected http code from Docker hub: $http_code"
        exit 1
    fi
}

publish-image() {
    if [[ "$DRY_RUN" = true ]]; then
        DOCKER_BUILD_OPTS=""
    fi

    if [[ -n ${DOCKER_BUILD_ARGS} ]]; then
        # the docker build args are set, expand the build args into docker command
        expanded_build_args=""
        for arg in ${DOCKER_BUILD_ARGS}
        do
            expanded_build_args="${expanded_build_args} --build-arg ${arg}"
        done
        DOCKER_BUILD_ARGS=${expanded_build_args}
    fi

    echo "Building $(get_docker_uri) using ${DOCKER_BUILD_PATH}/${DOCKERFILE}"
    echo "Issuing the following Docker command: docker build --pull ${DOCKER_BUILD_ARGS} ${DOCKER_BUILD_OPTS} -t $(get_docker_uri) -f ${DOCKERFILE} ."
    cd ${DOCKER_BUILD_PATH} && \
    docker build --pull ${DOCKER_BUILD_ARGS} ${DOCKER_BUILD_OPTS} -t $(get_docker_uri) -f ${DOCKERFILE} .

    if [[ ! "$DRY_RUN" = true ]]; then
        if [[ "$FORCE" = true ]]; then
            docker push $(get_docker_uri)
            echo "Successfully pushed $(get_docker_uri)"

            docker rmi $(get_docker_uri)
            echo "Removed $(get_docker_uri) from local disk"
        else
            if ! compare-digests $(get_docker_uri) $(get_docker_uri) "local" "remote"; then
                docker push $(get_docker_uri)
                echo "Successfully pushed $(get_docker_uri)"

                docker rmi $(get_docker_uri)
                echo "Removed $(get_docker_uri) from local disk"
            else
                echo "Not pushing $(get_docker_uri) because it already exist in ${DOCKER_REGISTRY} registry!"
            fi
        fi
    else
        echo "Dry Run enabled not pushing: $(get_docker_uri)"
    fi
}

DOCKER_REGISTRY=${DOCKER_REGISTRY:=docker.io} # Docker Registry to push the docker image and manifest to (defaults to docker.io)
DOCKER_NAMESPACE=${DOCKERHUB_ORGANISATION:=jenkins} # Docker namespace to push the docker image to (this is your username for DockerHub)
DOCKER_ARCH=$(docker-get-arch) # Will use Docker to get the correct architecture name
DOCKER_BUILD_TAG=""     # The variant of the docker image to use when tagging the image (i.e. 2.263-jdk8-hotspot-debian-buster)
DOCKER_BUILD_ARGS=""    # List of build-time variables and values separated by spaces (i.e. --build-args "JENKINS_VERSION=${VERSION} VAR=value")
DOCKER_BUILD_OPTS=""    # Options passed to "docker build" command separated by spaces (i.e. --build-opts "--no-cache --pull")
DOCKER_BUILD_PATH="."   # The docker build context to use when building the image
DRY_RUN=false           # Builds the images but does not push/publish them
DEBUG=false             # Turns on verbose output
FORCE=false             # Will push/publish images no matter what (Will override the dry run flag). Helpful when vulnerabilities are identified and need to push patches

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -f|--file)
    DOCKERFILE=$2
    shift
    ;;
    -i|--image)
    DOCKER_IMAGE_NAME=$2
    shift
    ;;
    -t|--tag)
    DOCKER_BUILD_TAG=$2
    shift
    ;;
    -a|--build-args)
    DOCKER_BUILD_ARGS=$2
    shift
    ;;
    -b|--build-opts)
    DOCKER_BUILD_OPTS=$2
    shift
    ;;
    -c|--context)
    DOCKER_BUILD_PATH=$2
    shift
    ;;
    -n|--dry-run)
    DRY_RUN=true
    ;;
    -d|--debug)
    DEBUG=true
    ;;
    --force)
    FORCE=true
    ;;
    *)
    echo "Unknown option: $key"
    return 1
    ;;
  esac
  shift
done


if [[ "$DRY_RUN" = true ]]; then
    echo "Dry run enabled, will not publish images"
fi

if [[ "$DEBUG" = true ]]; then
    set -x
fi

cat <<EOF
Docker repository in Use:
* JENKINS_REPO: $(echo ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE} | sed 's/^\/*//')
EOF

docker-enable-experimental
docker-login

if [[ "$FORCE" = true ]]; then
    echo "Force Processing Image: $(get_docker_uri)"
    publish-image
elif is-published; then
    echo "Image is already published: $(get_docker_uri)"
else
    echo "Processing Image: $(get_docker_uri)"
    publish-image
fi