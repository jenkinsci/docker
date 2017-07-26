#!/bin/bash -eu

# Publish any versions of the docker image not yet pushed to jenkins/jenkins
# Arguments:
#   -n dry run, do not build or publish images
#   -d debug

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
    local from="jenkins/jenkins:$1"
    local to="$2/jenkins:$3"
    local out

    docker pull "$from"
    if out=$(docker tag -f "$from" "$to" 2>&1); then
        echo "$out"
    else
        docker tag "$from" "$to"
    fi
}

login-token() {
    # could use jq .token
    curl -q -sSL "https://auth.docker.io/token?service=registry.docker.io&scope=repository:jenkins/jenkins:pull" | grep -o '"token":"[^"]*"' | cut -d':' -f 2 | xargs echo
}

is-published() {
    get-manifest "$1" &> /dev/null
}

get-manifest() {
    local tag=$1
    local opts=""
    if [ "$debug" = true ]; then
        opts="-v"
    fi
    curl $opts -q -fsSL -H "Accept: application/vnd.docker.distribution.manifest.v2+json" -H "Authorization: Bearer $TOKEN" "https://index.docker.io/v2/jenkinsci/jenkins/manifests/$tag"
}

get-digest() {
    local manifest
    manifest=$(get-manifest "$1")
    #get-manifest "$1" | jq .config.digest
    if [ "$debug" = true ]; then
        >&2 echo "DEBUG: Manifest for $1: $manifest"
    fi
    echo "$manifest" | grep -A 10 -o '"config".*' | grep digest | head -1 | cut -d':' -f 2,3 | xargs echo
}

get-latest-versions() {
    curl -q -fsSL https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/maven-metadata.xml | grep '<version>.*</version>' | grep -E -o '[0-9]+(\.[0-9]+)+' | sort-versions | uniq | tail -n 20
}

publish() {
    local version=$1
    local variant=$2
    local tag="${version}${variant}"
    local sha
    local build_opts=(--no-cache --pull)

    if [ "$dry_run" = true ]; then
        build_opts=()
    fi

    local dir=war
    # lts is in a different dir
    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        dir=war-stable
    fi
    sha=$(curl -q -fsSL "http://mirrors.jenkins.io/${dir}/${version}/jenkins.war.sha256" | cut -d' ' -f 1)

    docker build --file "Dockerfile$variant" \
                 --build-arg "JENKINS_VERSION=$version" \
                 --build-arg "JENKINS_SHA=$sha" \
                 --tag "jenkins/jenkins:${tag}" \
                 --tag "jenkinsci/jenkins:${tag}" \
                 "${build_opts[@]}" .

    if [ ! "$dry_run" = true ]; then
        docker push "jenkins/jenkins:${tag}"
        docker push "jenkinsci/jenkins:${tag}"        
    fi
}

tag-and-push() {
    local source=$1
    local target=$2
    local digest_source
    local digest_target

    if [ "$debug" = true ]; then
        >&2 echo "DEBUG: Getting digest for ${source}"
    fi
    # if tag doesn't exist yet, ie. dry run
    if ! digest_source=$(get-digest "${source}"); then
        echo "Unable to get digest for ${source} ${digest_source}"
        digest_source=""
    fi

    if [ "$debug" = true ]; then
        >&2 echo "DEBUG: Getting digest for ${target}"
    fi
    if ! digest_target=$(get-digest "${target}"); then
        echo "Unable to get digest for ${target} ${digest_target}"
        digest_target=""
    fi

    if [ "$digest_source" == "$digest_target" ] && [ -n "${digest_target}" ]; then
        echo "Images ${source} [$digest_source] and ${target} [$digest_target] are already the same, not updating tags"
    else
        echo "Creating tag ${target} pointing to ${source}"
        docker-tag "${source}" "jenkins" "${target}"
        docker-tag "${source}" "jenkinsci" "${target}"
        if [ ! "$dry_run" = true ]; then
            echo "Pushing jenkins/jenkins:${target}"
            docker push "jenkins/jenkins:${target}"
            docker push "jenkinsci/jenkins:${target}"
        else
            echo "Would push jenkins/jenkins:${target}"
        fi
    fi
}

publish-latest() {
    local version=$1
    local variant=$2

    # push latest (for master) or the name of the branch (for other branches)
    if [ -z "${variant}" ]; then
        tag-and-push "${version}${variant}" "latest"
    else
        tag-and-push "${version}${variant}" "${variant#-}"
    fi
}

publish-lts() {
    local version=$1
    local variant=$2
    tag-and-push "${version}${variant}" "lts${variant}"
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

TOKEN=$(login-token)

lts_version=""
version=""
for version in $(get-latest-versions); do
    if is-published "$version$variant"; then
        echo "Tag is already published: $version$variant"
    else
        echo "Publishing version: $version$variant"
        publish "$version" "$variant"
    fi

    # Update lts tag
    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        lts_version="${version}"
    fi
done

publish-latest "${version}" "${variant}"
if [ -n "${lts_version}" ]; then
    publish-lts "${lts_version}" "${variant}"
fi
