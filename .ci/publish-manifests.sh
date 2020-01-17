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
}

docker-enable-experimental() {
    echo '{"experimental": "enabled"}' > ~/.docker/config.json
}

sort-versions() {
    if [[ "$(uname)" == 'Darwin' ]]; then
        gsort --version-sort
    else
        sort --version-sort
    fi
}

get-latest-versions() {
    curl -q -fsSL https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/maven-metadata.xml | grep '<version>.*</version>' | grep -E -o '[0-9]+(\.[0-9]+)+' | sort-versions | uniq | tail -n 5
}

docker-pull() {
    local variant=$1
    local archs=$2

    for arch in ${archs}; do
        docker pull ${JENKINS_REPO}:${variant}-${arch}
    done
}

publish-variant() {
    local variant=$1
    local archs=$2

    # Pull down all images need for manifest
    docker-pull "${variant}" "${archs}"

    docker_manifest="docker manifest create ${JENKINS_REPO}:${variant}"

    for arch in ${archs}; do
        docker_manifest="${docker_manifest} \ \n${JENKINS_REPO}:${variant}-${arch}"
    done

    if [[ "$debug" = true ]]; then
        echo "DEBUG: Docker Manifest command for ${variant}: \n ${docker_manifest}"
    fi

    # Run the docker_manifest string
    eval "${docker_manifest}"

    # Annotate the manifest
    for arch in ${archs}; do
        docker manifest annotate ${JENKINS_REPO}:${variant} ${JENKINS_REPO}:${variant}-${arch} --arch ${arch}
    done

    # Push the manifest
    docker manifest push ${JENKINS_REPO}:${variant}
}

publish-alpine() {
    local archs="arm64 s390x ppc64le amd64"
    publish-variant "alpine"  "${archs}"
}

publish-slim() {
    local archs="arm64 s390x ppc64le amd64"
    publish-variant "slim"  "${archs}"
}

publish-debian() {
    local archs="arm64 s390x ppc64le amd64"
    publish-variant "debian"  "${archs}"
}

publish-lts-alpine() {
    local archs="arm64 s390x ppc64le amd64"
    publish-variant "lts-alpine"  "${archs}"
}

publish-lts-slim() {
    local archs="arm64 s390x ppc64le amd64"
    publish-variant "lts-slim"  "${archs}"
}

publish-lts-debian() {
    local archs="arm64 s390x ppc64le amd64"
    publish-variant "lts-debian"  "${archs}"

    # Default LTS
    publish-variant "lts"  "${archs}"
}

publish-latest() {
    local archs="arm64 s390x ppc64le amd64"
    publish-variant "latest"  "${archs}"
}

publish-versions() {
    local version=$1
    echo "Test ${version}"
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
        variant="-"$2
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

docker-login
docker-enable-experimental

# Parse variant options
if [[ ${variant} == alpine ]]; then
    publish-alpine
elif [[ ${variant} == slim ]]; then
    publish-slim
elif [[ ${variant} == debian ]]; then
        publish-debian
elif [[ ${variant} == lts-alpine ]]; then
    if [[ -z ${lts_version} ]]; then
        echo "No LTS Version to process!"
    else
        publish-lts-alpine
    fi
elif [[ ${variant} == lts-slim ]]; then
    if [[ -z ${lts_version} ]]; then
        echo "No LTS Version to process!"
    else
        publish-lts-slim
    fi
elif [[ ${variant} == lts-debian ]]; then
    if [[ -z ${lts_version} ]]; then
        echo "No LTS Version to process!"
    else
        publish-lts-debian
    fi
elif [[ ${variant} == latest ]]; then
    publish-latest
elif [[ ${variant} == versions ]]; then
    for version in $(get-latest-versions); do
        publish-versions ${version}
        if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            lts_version="${version}"
        fi
    done
fi