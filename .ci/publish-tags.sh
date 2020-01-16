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
    docker login --username ${DOCKER_USERNAME} --password ${DOCKER_PASSWORD}
}

# Try tagging with and without -f to support all versions of docker
docker-tag() {
    local from="$1"
    local to="$2"
    local out

    if out=$(docker tag -f "$from" "$to" 2>&1); then
        echo "$out"
    else
        docker tag "$from" "$to"
    fi
}

sort-versions() {
    if [ "$(uname)" == 'Darwin' ]; then
        gsort --version-sort
    else
        sort --version-sort
    fi
}

get-latest-versions() {
    curl -q -fsSL https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/maven-metadata.xml | grep '<version>.*</version>' | grep -E -o '[0-9]+(\.[0-9]+)+' | sort-versions | uniq | tail -n 5
}

publish-variant() {
    local version=$1
    local variant=$2
    local archs=$3
	echo "publishing ${variant} tag to point to ${version}"
	echo "${archs}"

    for arch in ${archs}; do
        echo "Pulling ${version}-${variant}-${arch}"
        # Pull down images to be re-tagged
        docker pull "${JENKINS_REPO}:${version}-${variant}-${arch}"

        echo "Re-tagging Image from ${version}-${variant}-${arch} to ${JENKINS_REPO}:${variant}-${arch}"
        docker-tag "${JENKINS_REPO}:${version}-${variant}-${arch}" "${JENKINS_REPO}:${variant}-${arch}"
        docker push "${JENKINS_REPO}:${variant}-${arch}"
    done
}

publish-lts-variant() {
    local version=$1
    local variant=$2
    local archs=$3
    local base_image=$4
	echo "publishing lts ${variant} tag to point to ${version}"

    for arch in ${archs}; do
        # Pull down images to be re-tagged
        docker pull "${JENKINS_REPO}:${version}-${variant}-${arch}"

        docker-tag "${JENKINS_REPO}:${version}-${variant}-${arch}" "${JENKINS_REPO}:lts-${variant}-${arch}"
        docker push "${JENKINS_REPO}:lts-${variant}-${arch}"

        # Will push the LTS tag without variant aka default image
        if [[ -z "$base_image" ]]; then
            docker-tag "${JENKINS_REPO}:${version}-${variant}-${arch}" "${JENKINS_REPO}:lts-${arch}"
            docker push "${JENKINS_REPO}:lts-${arch}"
        fi
    done
}

publish-alpine() {
    local version=$1
    local archs="arm64 s390x ppc64le amd64"
    publish-variant "${version}"  "alpine"  "${archs}"
}

publish-slim() {
    local version=$1
    local archs="arm64 s390x ppc64le amd64"
    publish-variant "${version}"  "slim"  "${archs}"
}

publish-debian() {
    local version=$1
    local archs="arm64 s390x ppc64le amd64"
    publish-variant "${version}"  "debian"  "${archs}"
}

publish-lts-alpine() {
    local version=$1
    local archs="arm64 s390x ppc64le amd64"
    publish-lts-variant "${version}"  "alpine"  "${archs}"  ""
}

publish-lts-slim() {
    local version=$1
    local archs="arm64 s390x ppc64le amd64"
    publish-lts-variant "${version}"  "slim"  "${archs}"  ""
}

publish-lts-debian() {
    local version=$1
    local archs="arm64 s390x ppc64le amd64"
    publish-lts-variant "${version}"  "debian"  "${archs}"  "true"
}

publish-latest() {
    local version=$1
    local variant=$2
    local archs=$3
	echo "publishing latest tag to point to ${version} for ${variant}"

    for arch in ${archs[*]}; do
        # Pull down images to be re-tagged
        docker pull "${JENKINS_REPO}:${version}-${variant}-${arch}"

        docker-tag "${JENKINS_REPO}:${version}-${variant}-${arch}" "${JENKINS_REPO}:latest-${arch}"
        docker push "${JENKINS_REPO}:latest-${arch}"
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
        -t|--tag)
        tag=$2
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

# Get LTS and Latest Version of Jenkins
lts_version=""
version=""
for version in $(get-latest-versions); do
    # Update lts tag
    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        lts_version="${version}"
    fi
done

echo "Latest Version of Jenkins: ${version}"
echo "Latest LTS Version of Jenkins: ${lts_version}"

# Parse tag options
if [[ $tag == alpine ]]; then
    publish-alpine "${version}"
elif [[ $tag == slim ]]; then
    publish-slim "${version}"
elif [[ $tag == debian ]]; then
    publish-debian "${version}"
elif [[ $tag == lts-alpine ]]; then
    if [[ -z ${lts_version} ]]; then
        echo "No LTS Version to process!"
    else
        publish-lts-alpine "${lts_version}"
    fi
elif [[ $tag == lts-slim ]]; then
    if [[ -z ${lts_version} ]]; then
        echo "No LTS Version to process!"
    else
        publish-lts-slim "${lts_version}"
    fi
elif [[ $tag == lts-debian ]]; then
    if [[ -z ${lts_version} ]]; then
        echo "No LTS Version to process!"
    else
        publish-lts-debian "${lts_version}"
    fi
elif [[ $tag == latest ]]; then
    publish-latest "${version}"  "debian"  "arm64 s390x ppc64le amd64"
fi