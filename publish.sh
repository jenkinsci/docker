#!/bin/bash -eu

# Publish any versions of the docker image not yet pushed to jenkinsci/jenkins

set -o pipefail

sort-versions() {
    if [ "$(uname)" == 'Darwin' ]; then
        gsort --version-sort
    else
        sort --version-sort
    fi
}

# Try tagging with and without -f to support all versions of docker
docker-tag() {
    local from="jenkinsci/jenkins:$1"
    local to="jenkinsci/jenkins:$2"
    local out
    if out=$(docker tag -f "$from" "$to" 2>&1); then
        echo "$out"
    else
        docker tag "$from" "$to"
    fi
}

get-published-versions() {
    curl -q -fsSL https://registry.hub.docker.com/v1/repositories/jenkinsci/jenkins/tags | egrep -o '"name": "[0-9\.]+"' | egrep -o '[0-9\.]+'
}

get-latest-versions() {
    curl -q -fsSL https://api.github.com/repos/jenkinsci/jenkins/tags?per_page=20 | grep '"name": "jenkins-' | egrep -o '[0-9]+(\.[0-9]+)+' | sort-versions | uniq
}

publish() {
    local version=$1
    local sha
    local build_opts="--no-cache --pull"

    sha=$(curl -q -fsSL "http://repo.jenkins-ci.org/simple/releases/org/jenkins-ci/main/jenkins-war/${version}/jenkins-war-${version}.war.sha1")

    docker build --build-arg "JENKINS_VERSION=$version" \
                 --build-arg "JENKINS_SHA=$sha" \
                 --tag "jenkinsci/jenkins:$version" ${build_opts} .

    docker-tag $version latest

    docker push "jenkinsci/jenkins:$version"
    docker push "jenkinsci/jenkins:latest"

    # Update lts tag
    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Updating lts tag to $version"
        docker-tag $version lts
        docker push "jenkinsci/jenkins:lts"
    fi
}

published_versions="$(get-published-versions)"

for version in $(get-latest-versions); do
    if echo "${published_versions}" | grep -q "^${version}$"; then
        echo "Version is already published: $version"
    else
        echo "Publishing version: $version"
        publish $version
    fi
done


