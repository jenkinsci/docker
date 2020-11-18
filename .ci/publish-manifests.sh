#!/bin/bash -eu
set -eou pipefail

source ./.ci/common-functions.sh > /dev/null 2>&1

publish-manifest() {
    # Construct needed uris for the manifest process
    manifest_uri=$(echo ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${MANIFEST_NAME} | sed 's/^\/*//')  # strip off all leading '/' characters
    image_uri=$(echo ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${IMAGE_NAME} | sed 's/^\/*//')  # strip off all leading '/' characters

    # Pull each of our docker images on the supported architectures
    echo "Pulling needed images to build ${manifest_uri} manifest"
    for ARCH in ${ARCHITECTURES}; do
        echo "Pulling ${image_uri}-${ARCH}....."
        docker pull ${image_uri}-${ARCH}
        echo "Successfully pulled image!"
    done

    # Build the manifest
    docker_manifest_command="docker manifest create ${manifest_uri}"
    for ARCH in ${ARCHITECTURES}; do
        docker_manifest_command="${docker_manifest_command} ${image_uri}-${ARCH}"
    done

    echo "Issuing the following command to build manifest: ${docker_manifest_command}"
    if [[ ! "$DRY_RUN" = true ]]; then
        eval "${docker_manifest_command}"
    fi

    # Annotate the built manifest with arch information
    for ARCH in ${ARCHITECTURES}; do
        echo "Issuing the following command to annotate the manifest: docker manifest annotate ${manifest_uri} ${image_uri}-${ARCH} --arch ${ARCH}"
        if [[ ! "$DRY_RUN" = true ]]; then
            docker manifest annotate ${manifest_uri} ${image_uri}-${ARCH} --arch ${ARCH}
        fi
    done

    # Push the annotated manifest
    echo "Issuing the following command to push the annotated manifest: docker manifest push --purge ${manifest_uri}"
    if [[ ! "$DRY_RUN" = true ]]; then
        docker manifest push --purge ${manifest_uri}
    fi

    # Removing the images pulled down for manifest
    echo "Removing images from local disk....."
    for ARCH in ${ARCHITECTURES}; do
        echo "Removing ${image_uri}-${ARCH}....."
        docker rmi ${image_uri}-${ARCH}
        echo "Successfully removed image!"
    done
}

DOCKER_REGISTRY=${DOCKER_REGISTRY:=docker.io} # Docker Registry to push the docker image and manifest to (defaults to docker.io)
DOCKER_NAMESPACE=${DOCKERHUB_ORGANISATION:=jenkins} # Docker namespace to push the docker image to (this is your username for DockerHub)
MANIFEST_NAME=""        # The name of the image that will be used for the manifest
IMAGE_NAME=""           # The name of the image that will be used for the creation of the manifest, without arch at the end
ARCHITECTURES=""        # The list of architectures you want to build the manifest for
DRY_RUN=false           # Builds the images but does not push/publish them
DEBUG=false             # Turns on verbose output

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -m|--manifest-name)
        MANIFEST_NAME=$2
        shift
        ;;
        -i|--image-name)
        IMAGE_NAME=$2
        shift
        ;;
         -a|--archs)
        ARCHITECTURES=$2
        shift
        ;;
        -n|--dry-run)
        DRY_RUN=true
        ;;
        -d|--debug)
        DEBUG=true
        ;;
        *)
        echo "Unknown option: $key"
        return 1
        ;;
    esac
    shift
done

if [[ "$DRY_RUN" = true ]]; then
    echo "Dry run enabled, will not publish manifest"
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

publish-manifest