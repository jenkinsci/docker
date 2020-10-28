#!/bin/bash -eu

# Publish any versions of the docker image not yet pushed to ${JENKINS_REPO}
# Arguments:
#   -n dry run, do not build or publish images
#   -d debug

set -o pipefail

. jenkins-support

: "${DOCKERHUB_ORGANISATION:=jenkins}"
: "${DOCKERHUB_REPO:=jenkins}"

JENKINS_REPO="${DOCKERHUB_ORGANISATION}/${DOCKERHUB_REPO}"

cat <<EOF
Docker repository in Use:
* JENKINS_REPO: ${JENKINS_REPO}
EOF

sort-versions() {
    if [ "$(uname)" == 'Darwin' ]; then
        gsort --version-sort
    else
        sort --version-sort
    fi
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

login-token() {
    # could use jq .token
    curl -q -sSL "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${JENKINS_REPO}:pull" | grep -o '"token":"[^"]*"' | cut -d':' -f 2 | xargs echo
}

is-published() {
    local tag=$1
    local opts=""
    if [ "$debug" = true ]; then
        opts="-v"
    fi
    local http_code;
    http_code=$(curl $opts -q -fsL -o /dev/null -w "%{http_code}" -H "Accept: application/vnd.docker.distribution.manifest.v2+json" -H "Authorization: Bearer $TOKEN" "https://index.docker.io/v2/${JENKINS_REPO}/manifests/$tag")
    if [ "$http_code" -eq "404" ]; then
        false
    elif [ "$http_code" -eq "200" ]; then
        true
    else
        echo "Received unexpected http code from Docker hub: $http_code"
        exit 1
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

get-latest-versions() {
    curl -q -fsSL https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/maven-metadata.xml | grep '<version>.*</version>' | grep -E -o '[0-9]+(\.[0-9]+)+' | sort-versions | uniq | tail -n 30
}

publish() {
    local version=$1
    local variant=$2
    local tag="${version}${variant}"
    local sha
    local build_opts=(--no-cache --pull)
    local dockerfile="./8/debian/stretch/hotspot/Dockerfile"

    if [ "$dry_run" = true ]; then
        build_opts=()
    fi

    if [ "$variant" == "-alpine" ] ; then
	dockerfile="./8/alpine/hotspot/Dockerfile"
    elif [ "$variant" == "-slim" ] ; then
	dockerfile="./8/debian/buster-slim/hotspot/Dockerfile"
    elif [ "$variant" == "-jdk11" ] ; then
	dockerfile="./11/debian/buster/hotspot/Dockerfile"
    elif [ "$variant" == "-centos" ] ; then
	dockerfile="./8/centos/centos8/hotspot/Dockerfile"
    elif [ "$variant" == "-centos7" ] ; then
	dockerfile="./8/centos/centos7/hotspot/Dockerfile"
    fi

    sha=$(curl -q -fsSL "https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/${version}/jenkins-war-${version}.war.sha256" )

    docker build --file "${dockerfile}" \
                 --build-arg "JENKINS_VERSION=$version" \
                 --build-arg "JENKINS_SHA=$sha" \
                 --tag "${JENKINS_REPO}:${tag}" \
                 "${build_opts[@]+"${build_opts[@]}"}" .

    # " line to fix syntax highlightning
    if [ ! "$dry_run" = true ]; then
        docker push "${JENKINS_REPO}:${tag}"
    else
        echo "Dry run mode: no docker push"
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
        echo "Unable to get source digest for '${source} ${digest_source}'"
        digest_source=""
    fi

    if [ "$debug" = true ]; then
        >&2 echo "DEBUG: Getting digest for ${target}"
    fi
    if ! digest_target=$(get-digest "${target}"); then
        echo "Unable to get target digest for '${target} ${digest_target}'"
        digest_target=""
    fi

    if [ "$digest_source" == "$digest_target" ] && [ -n "${digest_target}" ]; then
        echo "Images ${source} [$digest_source] and ${target} [$digest_target] are already the same, not updating tags"
    else
        echo "Creating tag ${target} pointing to ${source}"
        docker-tag "${source}" "${DOCKERHUB_ORGANISATION}" "${target}"
        destination="${REPO:-${JENKINS_REPO}}:${target}"
        if [ ! "$dry_run" = true ]; then
            echo "Pushing ${destination}"
            docker push "${destination}"
        else
            echo "Would push ${destination}"
        fi
    fi
}

publish-latest() {
    local version=$1
    local variant=$2
    echo "publishing latest: $version$variant"

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
    tag-and-push "${version}${variant}" "${version}-lts${variant}"
}

# Process arguments

dry_run=false
debug=false
variant=""
start_after="1.0" # By default, we will publish anything missing (only the last 20 actually)

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
        --start-after)
        start_after=$2
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
        echo "$version$variant not published yet"
        if versionLT "$start_after" "$version"; then # if start_after < version
            echo "Version $version higher than $start_after: publishing $version$variant"
            publish "$version" "$variant"
        else
            echo "Version $version lower or equal to $start_after, no publishing (variant=$variant)."
        fi
    fi

    # Update lts tag (if we have an LTS version depending on $start_after)
    if versionLT "$start_after" "$version" && [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        lts_version="${version}"
    fi
done

publish-latest "${version}" "${variant}"

if [ -n "${lts_version}" ]; then
    publish-lts "${lts_version}" "${variant}"
else
    echo "No LTS publishing"
fi
