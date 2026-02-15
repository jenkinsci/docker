#!/bin/bash -eu

# Publish any versions of the docker image not yet pushed to ${JENKINS_REPO}
# Arguments:
#   -n dry run, do not build or publish images
#   -d debug

: "${JENKINS_VERSION:?Variable \$JENKINS_VERSION not set or empty.}"

set -eu -o pipefail

: "${DOCKERHUB_ORGANISATION:=jenkins}"
: "${DOCKERHUB_REPO:=jenkins}"
: "${BAKE_TARGET:=linux}"

export JENKINS_REPO="${DOCKERHUB_ORGANISATION}/${DOCKERHUB_REPO}"

function sort-versions() {
    if [ "$(uname)" == 'Darwin' ]; then
        gsort --version-sort
    else
        sort --version-sort
    fi
}

# Process arguments
dry_run=false
debug=false

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -n)
        dry_run=true
        ;;
        -d)
        debug=true
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

# Retrieve all the Jenkins versions from Artifactory
all_jenkins_versions="$(curl --disable --fail --silent --show-error --location \
        https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/maven-metadata.xml \
    | grep '<version>.*</version>')"

latest_lts_version="$(echo "${all_jenkins_versions}" | grep -E -o '[0-9]\.[0-9]+\.[0-9]' | sort-versions | tail -n1)"
latest_weekly_version="$(echo "${all_jenkins_versions}" | grep -E -o '[0-9]\.[0-9]+' | sort-versions | tail -n 1)"

if [[ "${JENKINS_VERSION}" == "${latest_weekly_version}" ]]
then
    LATEST_WEEKLY="true"
else
    LATEST_WEEKLY="false"
fi

if [[ "${JENKINS_VERSION}" == "${latest_lts_version}" ]]
then
    LATEST_LTS="true"
else
    LATEST_LTS="false"
fi

build_opts=("--pull")
metadata_suffix="publish"
if test "${dry_run}" == "true"; then
    build_opts+=("--set=*.output=type=cacheonly")
    metadata_suffix="dry-run"
else
    build_opts+=("--push")
fi

# Save build result metadata
mkdir -p target
BUILD_METADATA_PATH="target/build-result-metadata_${BAKE_TARGET}_${metadata_suffix}.json"
build_opts+=("--metadata-file=${BUILD_METADATA_PATH}")

COMMIT_SHA=$(git rev-parse HEAD)
export COMMIT_SHA JENKINS_VERSION LATEST_WEEKLY LATEST_LTS BUILD_METADATA_PATH

cat <<EOF
Using the following settings:
* JENKINS_REPO: ${JENKINS_REPO}
* JENKINS_VERSION: ${JENKINS_VERSION}
* COMMIT_SHA: ${COMMIT_SHA}
* LATEST_WEEKLY: ${LATEST_WEEKLY}
* LATEST_LTS: ${LATEST_LTS}
* BUILD_METADATA_PATH: ${BUILD_METADATA_PATH}
* BAKE_TARGET: ${BAKE_TARGET}
* BAKE OPTIONS:
$(printf '  %s\n' "${build_opts[@]}")

* RESOLVED BAKE CONFIG:
$(docker buildx bake --file docker-bake.hcl --print "${BAKE_TARGET}")
EOF

docker buildx bake --file docker-bake.hcl "${build_opts[@]}" "${BAKE_TARGET}"
