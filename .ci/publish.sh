#!/bin/bash -eu

# Publish any versions of the docker image not yet pushed to ${JENKINS_REPO}
# Arguments:
#   -n dry run, do not build or publish images
#   -d debug

set -eu -o pipefail

. jenkins-support
source ./.ci/common-functions.sh > /dev/null 2>&1

: "${DOCKERHUB_ORGANISATION:=jenkins}"
: "${DOCKERHUB_REPO:=jenkins}"

export JENKINS_REPO="${DOCKERHUB_ORGANISATION}/${DOCKERHUB_REPO}"

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

login-token() {
    curl --disable --fail --silent --show-error --location "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${JENKINS_REPO}:pull" | jq -r '.token'
}

is-published() {
    local tag linux_cpu_archs
    tag="$1"

    ## A given tag is considered publish if, and only if, all the images associated with this tag, are published.
    ## By "all images", we mean all the declinations but also all the CPU architectures.
    linux_cpu_archs="$(make --silent show | jq -r '.target[].platforms' | jq -r '.[]' | sort | uniq)"

    for linux_cpu_arch in ${linux_cpu_archs}
    do
        local cpu_arch

        # Extract the cpu arch without the linux prefix, e.g. "Remove all the characters on the left of the '/' character" - https://tldp.org/LDP/abs/html/string-manipulation.html#SubstringRemoval
        cpu_arch="${linux_cpu_arch##*/}"

        for docker_image in $(JENKINS_VERSION="${tag}" make --silent show | jq -r '.target[] | select(.platforms[] | contains("'"${linux_cpu_arch}"'")) | .tags' | jq -r '.[]')
        do
            local tag_to_check manifest_url manifest

            # Extract the tag, e.g. "Remove all the characters on the left of the ':' character" - https://tldp.org/LDP/abs/html/string-manipulation.html#SubstringRemoval
            tag_to_check="${docker_image##*:}"
            manifest_url="https://index.docker.io/v2/${JENKINS_REPO}/manifests/$tag_to_check"
            manifest="$(curl --disable --fail --silent --show-error --location --header 'Accept: application/vnd.docker.distribution.manifest.list.v2+json' --header "Authorization: Bearer ${TOKEN}" "${manifest_url}")"

            if ! echo "${manifest}" | jq -e -r '.manifests[] | select(.platform.architecture == "'"${cpu_arch}"'")' 1>/dev/null 2>&1
            then
                return 1
            fi
        done
    done

    return 0
}

get-latest-versions() {
    curl --disable --fail --silent --show-error --location https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/maven-metadata.xml | grep '<version>.*</version>' | grep -E -o '[0-9]+(\.[0-9]+)+' | sort-versions | uniq | tail -n 30
}

publish() {
    local version=$1
    local latest_weekly=$2
    local latest_lts=$3
    local sha
    local build_opts=(--pull --push)

    if [ "$dry_run" = true ]; then
        build_opts=()
    fi

    sha="$(curl --disable --fail --silent --show-error --location "https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/${version}/jenkins-war-${version}.war.sha256")"

    JENKINS_VERSION=$version
    JENKINS_SHA=$sha
    LATEST_WEEKLY=$latest_weekly
    LATEST_LTS=$latest_lts
    COMMIT_SHA=$(git rev-parse HEAD)
    export COMMIT_SHA JENKINS_VERSION JENKINS_SHA LATEST_WEEKLY LATEST_LTS

    docker buildx bake --file docker-bake.hcl "${build_opts[@]+"${build_opts[@]}"}" linux
}

# Process arguments

dry_run=false
debug=false
start_after="1.0" # By default, we will publish anything missing (only the last 30 actually)

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -n)
        dry_run=true
        ;;
        -d)
        debug=true
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


if [ "$debug" = true ]; then
    echo "Debug mode enabled"
    set -x
fi

if [ "$dry_run" = true ]; then
    echo "Dry run, will not publish images"
fi

versions=$(get-latest-versions)
latest_weekly_version=$(echo "${versions}" | tail -n 1)

latest_lts_version=$(echo "${versions}" | grep -E '[0-9]\.[0-9]+\.[0-9]' | tail -n 1 || echo "No LTS versions")

for version in $versions; do
    TOKEN=$(login-token)
    if is-published "$version"; then
        echo "Tag is already published: $version"
    else
        echo "$version not published yet"

        if [[ $version == "${latest_weekly_version}" ]]; then
            latest_weekly="true"
        else
            latest_weekly="false"
        fi

        if [[ $version == "${latest_lts_version}" ]]; then
            latest_lts="true"
        else
            latest_lts="false"
        fi

        if versionLT "$start_after" "$version"; then # if start_after < version
            echo "Version $version higher than $start_after: publishing $version latest_weekly:${latest_weekly} latest_lts:${latest_lts}"
            publish "$version" "${latest_weekly}" "${latest_lts}"
        else
            echo "Version $version lower or equal to $start_after, no publishing."
        fi
    fi
done
