#!/bin/bash -eu

# Publish any versions of the docker image not yet pushed to jenkinsci/jenkins
# Arguments:
#   -n dry run, do not build or publish images

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
    branch=$(git show-ref | grep $(git rev-list -n 1 HEAD) | tail -1 | rev | cut -d/ -f 1 | rev)
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
    curl -q -fsSL https://registry.hub.docker.com/v2/repositories/jenkinsci/jenkins/tags?page_size=30 | egrep -o "\"name\": \"${regex}\"" | egrep -o "${regex}"
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

    docker push "jenkinsci/jenkins:${tag}"
}

publish-latest() {
    local tag=$1
    local variant=$2

    # push latest (for master) or the name of the branch (for other branches)
    if [ -z "${variant}" ]; then
        echo "Updating latest tag to ${tag}"
        if [ ! "$dry_run" = true ]; then
            docker-tag "${tag}" "latest"
            docker push "jenkinsci/jenkins:latest"
        fi
    else
        echo "Updating ${variant#-} tag to ${tag}"
        if [ ! "$dry_run" = true ]; then
            docker-tag "${tag}" "${variant#-}"
            docker push "jenkinsci/jenkins:${variant#-}"
        fi
    fi
}

publish-lts() {
    local tag=$1
    local variant=$2
    echo "Updating lts${variant} tag to ${lts_tag}"
    if [ ! "$dry_run" = true ]; then
        docker-tag "${lts_tag}" "lts${variant}"
        docker push "jenkinsci/jenkins:lts${variant}"
    fi
}

dry_run=false
if [ "-n" == "${1:-}" ]; then
    dry_run=true
fi
if [ "$dry_run" = true ]; then
    echo "Dry run, will not build or publish images"
fi

variant=$(get-variant)

published_versions="$(get-published-versions)"

lts_tag=""
tag=""
for version in $(get-latest-versions); do
    tag="${version}${variant}"
    if echo "${published_versions}" | grep -q "^${tag}$"; then
        echo "Tag is already published: $tag"
    else
        echo "Publishing tag: $tag"
        if [ ! "$dry_run" = true ]; then
            publish "$version" "$variant"
        fi
    fi

    # Update lts tag
    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        lts_tag="${tag}"
    fi
done

publish-latest "${tag}" "${variant}"
if [ -n "${lts_tag}" ]; then
    publish-lts "${tag}" "${variant}"
fi
