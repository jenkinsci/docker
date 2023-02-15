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

is-published() {
    local JENKINS_VERSION="$1"
    local LATEST_WEEKLY=$2
    local LATEST_LTS=$3
    local docker_bake_version_config

    ## Export values for docker bake (through the `make <target>` commands)
    export JENKINS_VERSION JENKINS_SHA LATEST_WEEKLY LATEST_LTS

    ## A given jenkins version is considered publish if, and only if, all the images associated with this tag, are published with the correct manifest.
    ## By "all images", we mean all the declinations but also all the CPU architectures.
    docker_bake_version_config="$(make --silent show)"

    for docker_bake_target in $(echo "${docker_bake_version_config}" | jq -r '.target | keys | .[]')
    do
        ## Count how much platforms are expected for this "target" (e.g. image)
        local platform_amount
        platform_amount="$(echo "${docker_bake_version_config}" | jq -r '.target.'"${docker_bake_target}"'.platforms | length')"
        if test "${platform_amount}" -lt 1
        then
            echo "ERROR: could not get platforms for the docker bake target ${docker_bake_target}."
            echo "  (For debugging purposes) docker_bake_version_config=${docker_bake_version_config}"
            exit 1
        fi

        ## Check all the tags of each docker target.
        for docker_image_fullname in $(echo "${docker_bake_version_config}" | jq -r '.target.'"${docker_bake_target}"'.tags | .[]')
        do
            local tag_to_check manifest published_platforms

            # Extract the tag, e.g. "Remove all the characters on the left of the ':' character" - https://tldp.org/LDP/abs/html/string-manipulation.html#SubstringRemoval
            tag_to_check="${docker_image_fullname##*:}"

            set +e
            manifest="$(docker buildx imagetools inspect --raw "${JENKINS_REPO}":"${tag_to_check}")"
            published_platforms="$(echo "${manifest}" | jq -r '[.manifests[].platform | select(.architecture != "unknown")] | length')"
            set -e

            test -n "${manifest}" || return 1
            test -n "${published_platforms}" || return 1
            test "${published_platforms}" -eq "${platform_amount}" || return 1
        done
    done

    return 0
}

get-latest-versions() {
    # Check the past 2 weekly versions
    curl --disable --fail --silent --show-error --location \
        https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/maven-metadata.xml \
    | grep '<version>.*</version>' | grep -E -o '[0-9]\.[0-9]+' | sort-versions | uniq | tail -n 2 \
    > weekly-versions.txt

    # Check only the 2 latest LTS versions
    curl --disable --fail --silent --show-error --location \
        https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/maven-metadata.xml \
    | grep '<version>.*</version>' | grep -E -o '[0-9]\.[0-9]+\.[0-9]' | sort-versions | uniq | tail -n 2 \
    > lts-version.txt

    cat weekly-versions.txt lts-version.txt
    rm -f weekly-versions.txt lts-version.txt
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
        echo "ERROR: Unknown option: $key"
        exit 1
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

# The regexp '[0-9]\.[0-9]+\.[0-9]' captures only the LTS version (e.g. "3 numbers" such as 2.375.3 for instance).
# Weekly versions are all the non-LTS versions
latest_lts_version=$(echo "${versions}" | grep -E '[0-9]\.[0-9]+\.[0-9]' | tail -n 1 || echo "No LTS versions")
latest_weekly_version=$(echo "${versions}" | grep -v -E '[0-9]\.[0-9]+\.[0-9]' | tail -n 1)

for version in ${versions}
do
    if [[ "${version}" == "${latest_weekly_version}" ]]
    then
        latest_weekly="true"
    else
        latest_weekly="false"
    fi

    if [[ "${version}" == "${latest_lts_version}" ]]
    then
        latest_lts="true"
    else
        latest_lts="false"
    fi

    if is-published "${version}" "${latest_weekly}" "${latest_lts}"
    then
        echo "Tag is already published: ${version}"
    else
        echo "$version not published yet"

        if versionLT "${start_after}" "${version}" # if start_after < version
        then
            echo "Version $version higher than ${start_after}: publishing ${version} latest_weekly:${latest_weekly} latest_lts:${latest_lts}"
            publish "${version}" "${latest_weekly}" "${latest_lts}"
        else
            echo "Version ${version} lower or equal to ${start_after}, no publishing."
        fi
    fi
done
