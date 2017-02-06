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

get-variant() {
    local branch
    branch=$(git show-ref --heads | grep $(git rev-list -n 1 HEAD) | sed -e 's#.*/heads/##')
    if [ -z "$branch" ]; then
        >&2 echo "Could not get the current branch name for commit, not in a branch?: $(git rev-list -n 1 HEAD)"
        return 1
    fi
    case "$branch" in
        master) echo "" ;;
        *) echo "-${branch}" ;;
    esac
}

get-published-versions() {
    local regex="[0-9\.]+[a-z\-]*"
    curl -q -fsSL https://registry.hub.docker.com/v1/repositories/jenkinsci/jenkins/tags | egrep -o "\"name\": \"${regex}\"" | egrep -o "${regex}"
}

get-latest-versions() {
    curl -q -fsSL https://api.github.com/repos/jenkinsci/jenkins/tags?per_page=20 | grep '"name": "jenkins-' | egrep -o '[0-9]+(\.[0-9]+)+' | sort-versions | uniq
}

publish() {
    local version=$1
    local variant=$2
    local tag="${version}${variant}"
    local sha
    local build_opts="--no-cache --pull"

    sha=$(curl -q -fsSL "http://repo.jenkins-ci.org/simple/releases/org/jenkins-ci/main/jenkins-war/${version}/jenkins-war-${version}.war.sha1")

    docker build --build-arg "JENKINS_VERSION=$version" \
                 --build-arg "JENKINS_SHA=$sha" \
                 --tag "jenkinsci/jenkins:${tag}" ${build_opts} .

    docker-tag "${tag}" "latest${variant}"

    docker push "jenkinsci/jenkins:${tag}"
    docker push "jenkinsci/jenkins:latest${variant}"

    # Update lts tag
    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Updating lts${variant} tag to ${tag}"
        docker-tag "$version" "lts${variant}"
        docker push "jenkinsci/jenkins:lts${variant}"
    fi
}

variant=$(get-variant)

published_versions="$(get-published-versions)"

for version in $(get-latest-versions); do
    tag="${version}${variant}"
    if echo "${published_versions}" | grep -q "^${tag}$"; then
        echo "Tag is already published: $tag"
    else
        echo "Publishing tag: $tag"
        publish "$version" "$variant"
    fi
done


