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
ARCHS=(arm arm64 s390x ppc64le amd64)


cat <<EOF
Docker repository in Use:
* JENKINS_REPO: ${JENKINS_REPO}
EOF

#This is precautionary step to avoid accidental push to offical jenkins image
if [[ "$DOCKERHUB_ORGANISATION" == "jenkins" ]]; then
    echo "Experimental docker image should not published to jenkins organization , hence exiting with failure";
    exit 1;
fi

#ARCHS=(arm arm64 s390x ppc64le amd64)
BASEIMAGE=

login-token() {
    # could use jq .token
    curl -q -sSL "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${JENKINS_REPO}:pull" | grep -o '"token":"[^"]*"' | cut -d':' -f 2 | xargs echo
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


# Make a list of platforms for manifest-tool to publish
parse-manifest-platforms() {
    local platforms=()
    for arch in ${ARCHS[*]}; do
        platforms+=("linux/$arch")
    done
    IFS=,;printf "%s" "${platforms[*]}"
}

# Try tagging with and without -f to support all versions of docker
docker-tag() {
    local from="${JENKINS_REPO}:$1"
    local to="$2/${DOCKERHUB_REPO}:$3"
    local out

    docker pull "$from"
    if out=$(docker tag -f "$from" "$to" 2>&1); then
        echo "$out"
    else
        docker tag "$from" "$to"
    fi
}

get-manifest() {
    local tag=$1
    local opts=""
    if [ "$debug" = true ]; then
        opts="-v"
    fi
    curl $opts -q -fsSL -H "Accept: application/vnd.docker.distribution.manifest.v2+json" -H "Authorization: Bearer $TOKEN" "https://index.docker.io/v2/${JENKINS_REPO}/manifests/$tag"
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

tag-and-push() {
    local source=$1
    local target=$2
    local arch=$3
    local digest_source
    local digest_target

    if [ "$debug" = true ]; then
        >&2 echo "DEBUG: Getting digest for ${source}-${arch}"
    fi

    # if tag doesn't exist yet, ie. dry run
    if ! digest_source=$(get-digest "${source}-${arch}"); then
        echo "Unable to get source digest for ${source}-${arch} ${digest_source}"
        digest_source=""
    fi

    if [ "$debug" = true ]; then
        >&2 echo "DEBUG: Getting digest for ${target}-${arch}"
    fi
    if ! digest_target=$(get-digest "${target}-${arch}"); then
        echo "Unable to get target digest for ${target}-${arch} ${digest_target}"
        digest_target=""
    fi

    if [ "$digest_source" == "$digest_target" ] && [ -n "${digest_target}" ]; then
        echo "Images ${source}-${arch} [$digest_source] and ${target}-${arch} [$digest_target] are already the same, not updating tags"
    else
        echo "Creating tag ${target}-${arch} pointing to ${source}-${arch}"
        docker-tag "${source}-${arch}" "${DOCKERHUB_ORGANISATION}" "${target}-${arch}"

        if [ ! "$dry_run" = true ]; then
            echo "Pushing ${JENKINS_REPO}:${target}-${arch}"
            docker push "${JENKINS_REPO}:${target}-${arch}"
        else
            echo "Would push ${JENKINS_REPO}:${target}-${arch}"
        fi
    fi
}

publish-variant() {
    local version=$1
    local variant=$2

    for arch in ${ARCHS[*]}; do
        if [[ "$variant" =~ slim ]]; then
            tag-and-push "${version}${variant}" "slim" "${arch}"
        elif [[ "$variant" =~ alpine ]]; then
            tag-and-push "${version}${variant}" "alpine" "${arch}"
        fi
    done

    if [[ "$variant" =~ slim ]]; then
        push-manifest "slim" ""
    elif [[ "$variant" =~ alpine ]]; then
        push-manifest "alpine" ""
    fi
}

publish-latest() {
    local version=$1
    local variant=$2
	echo "publishing latest: $version$variant"
	
    for arch in ${ARCHS[*]}; do
        # push latest (for master) or the name of the branch (for other branches)
        if [ -z "$variant" ]; then
            tag-and-push "${version}${variant}" "latest" "${arch}"
        fi
    done

    # Only push latest when there is no variant
    if [[ -z "$variant" ]]; then
        push-manifest "latest" ""
    fi
}

publish-lts() {
    local version=$1
    local variant=$2
    for arch in ${ARCHS[*]}; do
        tag-and-push "${version}${variant}" "lts${variant}" "${arch}"
    done
    push-manifest "lts" "${variant}"
}

push-manifest() {
    local version=$1
    local variant=$2
    local archs=$3
    local manifest_tag=$4
    local tag="${version}${variant}"

    for arch in ${archs}; do
        docker pull "${JENKINS_REPO}:${tag}-${arch}"
    done

    docker manifest create ${JENKINS_REPO}:${manifest_tag} \
    $DOCKER_REGISTRY/$DOCKER_IMAGE-s390x:$DOCKER_TAG \
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


#TOKEN=$(login-token)

lts_version=""
version=""
for version in $(get-latest-versions); do
    # Update lts tag
    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        lts_version="${version}"
    fi
done
