#!/bin/bash -eu

# Publish any versions of the docker image not yet pushed to jenkins/jenkins
# Arguments:
#   -n dry run, do not build or publish images
#   -d debug

set -eou pipefail

. jenkins-support

: "${DOCKERHUB_ORGANISATION:=jenkins4eval}"
: "${DOCKERHUB_REPO:=jenkins}"

JENKINS_REPO="${DOCKERHUB_ORGANISATION}/${DOCKERHUB_REPO}"

cat <<EOF
Docker repository in Use:
* JENKINS_REPO: ${JENKINS_REPO}
EOF

#This is precautionary step to avoid accidental push to offical jenkins image
if [[ "$DOCKERHUB_ORGANISATION" == "jenkins" ]]; then
    echo "Experimental docker image should not published to jenkins organization , hence exiting with failure";
    exit 1;
fi

docker-login() {
    docker login --username ${DOCKERHUB_USERNAME} --password ${DOCKERHUB_PASSWORD}
    echo "Docker logged in successfully"
}

docker-enable-experimental() {
    mkdir -p $HOME/.docker;
    echo '{"experimental": "enabled"}' > $HOME/.docker/config.json;
    echo "Docker experimental enabled successfully"
}

sort-versions() {
    if [[ "$(uname)" == 'Darwin' ]]; then
        gsort --version-sort
    else
        sort --version-sort
    fi
}

get-latest-versions() {
    curl -q -fsSL https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/maven-metadata.xml | grep '<version>.*</version>' | grep -E -o '[0-9]+(\.[0-9]+)+' | sort-versions | uniq | tail -n 30
}

get-latest-lts-version() {
    local lts_version=""

    for version in $(get-latest-versions); do
        if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            lts_version="${version}"
        fi
    done
    echo "${lts_version}"
}

docker-pull() {
    local tag=$1
    local archs=$2

    for arch in ${archs}; do
        docker pull ${JENKINS_REPO}:${tag}-${arch}
        echo "Pulled ${JENKINS_REPO}:${tag}-${arch}"
    done
}

publish-variant() {
    local tag=$1
    local archs=$2
    local manifest_tag=$3

    # Pull down all images need for manifest
    docker-pull "${tag}" "${archs}"

    docker_manifest="docker manifest create ${JENKINS_REPO}:${manifest_tag}"

    for arch in ${archs}; do
        docker_manifest="${docker_manifest} ${JENKINS_REPO}:${tag}-${arch}"
    done

    if [[ "$debug" = true ]]; then
        echo "DEBUG: Docker Manifest command for ${manifest_tag}: ${docker_manifest}"
    fi

    # Run the docker_manifest string
    eval "${docker_manifest}"
    echo "Docker Manifest for ${JENKINS_REPO}:${manifest_tag} created"

    # Annotate the manifest
    for arch in ${archs}; do
        # Change nice arch name to Docker Official arch names
        tag_arch=${arch}
        if [[ $arch == arm64 ]]; then
            tag_arch="arm64v8"
        fi

        docker manifest annotate ${JENKINS_REPO}:${manifest_tag} ${JENKINS_REPO}:${tag}-${arch} --arch ${tag_arch}
        echo "Annotated ${JENKINS_REPO}:${manifest_tag}: ${JENKINS_REPO}:${tag}-${arch} to be ${tag_arch} for manifest"
    done

    # Push the manifest
    docker manifest push ${JENKINS_REPO}:${manifest_tag}
    echo "Pushed ${JENKINS_REPO}:${manifest_tag}"

    for arch in ${archs}; do
        docker rmi "${JENKINS_REPO}:${tag}-${arch}"
        echo "Removed  from ${JENKINS_REPO}:${tag}-${arch} local disk"
    done
}

publish-alpine() {
    local archs="arm64 s390x ppc64le amd64"
    publish-variant "alpine"  "${archs}"  "alpine"
}

publish-slim() {
    local archs="arm64 s390x ppc64le amd64"
    publish-variant "slim"  "${archs}"  "slim"
}

publish-debian() {
    local archs="arm64 s390x ppc64le amd64"
    publish-variant "debian"  "${archs}"  "debian"
}

publish-lts-alpine() {
    local archs="arm64 s390x ppc64le amd64"
    publish-variant "lts-alpine"  "${archs}"  "lts-alpine"
}

publish-lts-slim() {
    local archs="arm64 s390x ppc64le amd64"
    publish-variant "lts-slim"  "${archs}"  "lts-slim"
}

publish-lts-debian() {
    local archs="arm64 s390x ppc64le amd64"
    publish-variant "lts-debian"  "${archs}"  "lts-debian"

    # Default LTS
    publish-variant "lts"  "${archs}"  "lts"
}

publish-latest() {
    local archs="arm64 s390x ppc64le amd64"
    publish-variant "latest"  "${archs}"  "latest"
}

publish-versions-alpine() {
    for version in $(get-latest-versions); do
        local archs="arm64 s390x ppc64le amd64"
        publish-variant "${version}-alpine"  "${archs}"  "${version}-alpine"
    done
}

publish-versions-slim() {
    for version in $(get-latest-versions); do
        local archs="arm64 s390x ppc64le amd64"
        publish-variant "${version}-slim"  "${archs}"  "${version}-slim"
    done
}

publish-versions-debian() {
    for version in $(get-latest-versions); do
        local archs="arm64 s390x ppc64le amd64"
        publish-variant "${version}-debian"  "${archs}"  "${version}-debian"
        publish-variant "${version}-debian"  "${archs}"  "${version}"
    done
}

# Process arguments
dry_run=false
debug=false
variant=""

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -n)
        dry_run=true
        ;;
        -d)
        debug=true
        ;;
        -v|--variant)
        variant=$2
        shift
        ;;
        *)
        echo "Unknown option: $key"
        return 1
        ;;
    esac
    shift
done


if [ "$dry_run" = true ]; then
    echo "Dry run, will not publish images"
fi

if [ "$debug" = true ]; then
    set -x
fi

docker-enable-experimental
docker-login

# Parse variant options
echo "Processing manifest for ${variant}"
if [[ ${variant} == alpine ]]; then
    publish-alpine
elif [[ ${variant} == slim ]]; then
    publish-slim
elif [[ ${variant} == debian ]]; then
    publish-debian
elif [[ ${variant} == lts-alpine ]]; then
    lts_version=$(get-latest-lts-version)
    if [[ -z ${lts_version} ]]; then
        echo "No LTS Version to process!"
    else
        publish-lts-alpine
    fi
elif [[ ${variant} == lts-slim ]]; then
    lts_version=$(get-latest-lts-version)
    if [[ -z ${lts_version} ]]; then
        echo "No LTS Version to process!"
    else
        publish-lts-slim
    fi
elif [[ ${variant} == lts-debian ]]; then
    lts_version=$(get-latest-lts-version)
    if [[ -z ${lts_version} ]]; then
        echo "No LTS Version to process!"
    else
        publish-lts-debian
    fi
elif [[ ${variant} == latest ]]; then
    publish-latest
elif [[ ${variant} == versions-alpine ]]; then
    publish-versions-alpine
elif [[ ${variant} == versions-debian ]]; then
    publish-versions-debian
elif [[ ${variant} == versions-slim ]]; then
    publish-versions-slim
fi