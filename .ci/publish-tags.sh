#!/bin/bash -eu
set -eou pipefail

source ./.ci/common-functions.sh > /dev/null 2>&1

docker-tag() {
    # Try tagging with and without -f to support all versions of docker
    local from="$1"
    local to="$2"
    local out

    if out=$(docker tag -f "$from" "$to" 2>&1); then
        echo "$out"
    else
        docker tag "$from" "$to"
    fi
}

publish-tags() {
    # split the IMAGE into DOCKER_IMAGE_NAME DOCKER_TAG based on the delimiter, ':'
    IFS=":" read -r -a image_info <<< "$IMAGE"
    DOCKER_IMAGE_NAME=${image_info[0]}
    DOCKER_TAG=${image_info[1]}

    # Pull the latest image that was uploaded
    DOCKER_REPO=${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${DOCKER_IMAGE_NAME}
    DOCKER_PULL_TAG=${DOCKER_TAG}-${DOCKER_ARCH}  # pull registry/namespace/image:tag-arch

    DOCKER_REPO=$(echo ${DOCKER_REPO} | sed 's/^\/*//')  # strip off all leading '/' characters

    echo "Pulling ${DOCKER_REPO}:${DOCKER_PULL_TAG}"
    docker pull ${DOCKER_REPO}:${DOCKER_PULL_TAG}

    for TAG in ${TAGS}; do
        # build for regular user like format  i.e. registry/namespace/image:tag-arch
        DOCKER_REPO=${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${DOCKER_IMAGE_NAME}
        DOCKER_PULL_TAG=${DOCKER_TAG}-${DOCKER_ARCH}
        original_docker_image=${DOCKER_REPO}:${DOCKER_PULL_TAG} # already pushed (pulled earlier)
        tagged_docker_image=${DOCKER_REPO}:${TAG}-${DOCKER_ARCH} # tag and push

        # strip off all leading '/' characters to account for Registry and Namespaces
        original_docker_image=$(echo ${original_docker_image} | sed 's/^\/*//')
        tagged_docker_image=$(echo ${tagged_docker_image} | sed 's/^\/*//')

        echo "Tagging ${original_docker_image} as ${tagged_docker_image}"
        docker-tag "${original_docker_image}" "${tagged_docker_image}"

        if [[ ! "$DRY_RUN" = true ]]; then
            if [[ "$FORCE" = true ]]; then
                echo "Force publishing of the tags is enabled! Pushing the tag....."
                docker push "${tagged_docker_image}"
                echo "Successfully pushed ${tagged_docker_image}"

                docker rmi "${tagged_docker_image}"
                echo "Removed tagged image from local disk"
            elif ! compare-digests "${tagged_docker_image}" "${tagged_docker_image}" "local" "remote"; then
                echo "Remote and local digests for ${tagged_docker_image} are different. Pushing new tag....."
                docker push "${tagged_docker_image}"
                echo "Successfully pushed ${tagged_docker_image}"

                docker rmi "${tagged_docker_image}"
                echo "Removed tagged image from local disk"
            else
                echo "Image ${original_docker_image} and ${tagged_docker_image} are already the same, not updating tags"
                docker rmi "${tagged_docker_image}"
                echo "Removed tagged image from local disk"
            fi
        else
            echo "Dry Run enabled not pushing: ${tagged_docker_image}"
        fi
    done

    echo "Done publishing additional tags for ${DOCKER_REPO}:${DOCKER_PULL_TAG}"

    # Remove the original docker image if DRY_RUN is false
    if [[ ! "$DRY_RUN" = true ]]; then
        docker rmi ${DOCKER_REPO}:${DOCKER_PULL_TAG}
        echo "Removed original image from local disk"
    fi
}

DOCKER_REGISTRY=${DOCKER_REGISTRY:=docker.io} # Docker Registry to push the docker image and manifest to (defaults to docker.io)
DOCKER_NAMESPACE=${DOCKERHUB_ORGANISATION:=jenkins} # Docker namespace to push the docker image to (this is your username for DockerHub)
DOCKER_ARCH=$(docker-get-arch) # Will use Docker to get the correct architecture name
IMAGE=""                # The docker image (including root tag) to use when making a new tag (image:tag)
TAGS=""                 # A list of new tags that the image will become i.e. "tag1 tag2 ... tagN"
DRY_RUN=false           # Builds the images but does not push/publish them
DEBUG=false             # Turns on verbose output
FORCE=false             # Will push/publish images no matter what (Will override the dry run flag). Helpful when vulnerabilities are identified and need to push patches

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -i|--image)
    IMAGE=$2
    shift
    ;;
    -t|--tags)
    TAGS=$2
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
    echo "Dry run enabled, will not publish tags"
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

publish-tags