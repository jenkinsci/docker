#!/bin/bash -eu

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

    ./manifest-tool push from-args \
        --platforms "$(parse-manifest-platforms)" \
        --template "${JENKINS_REPO}:${version}${variant}-ARCH" \
        --target "${JENKINS_REPO}:${version}${variant}"
}