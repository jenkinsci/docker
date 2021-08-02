#!/bin/bash -eu

# Publish any versions of the docker image not yet pushed to ${JENKINS_REPO}
# Arguments:
#   -n dry run, do not build or publish images
#   -d debug

set -o pipefail

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
    curl -q -sSL "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${JENKINS_REPO}:pull" | jq -r '.token'
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

get-latest-versions() {
    curl -q -fsSL https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/maven-metadata.xml | grep '<version>.*</version>' | grep -E -o '[0-9]+(\.[0-9]+)+' | sort-versions | uniq | tail -n 30
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

    sha=$(curl -q -fsSL "https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/${version}/jenkins-war-${version}.war.sha256" )

    export JENKINS_VERSION=$version
    export JENKINS_SHA=$sha
    export LATEST_WEEKLY=$latest_weekly
    export LATEST_LTS=$latest_lts
    set -x
    docker buildx bake --file docker-bake.hcl \
                 "${build_opts[@]+"${build_opts[@]}"}" linux
    set +x
    if [ "$dry_run" = true ]; then
        echo "Dry run mode: no docker push"
    fi

}

# Process arguments

dry_run=false
debug=false
variant=""
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

versions=$(get-latest-versions)
latest_weekly_version=$(echo "${versions}" | tail -n 1)

latest_lts_version=$(echo "${versions}" | grep -E '[0-9]\.[0-9]+\.[0-9]' | tail -n 1 || echo "No LTS versions")

for version in $versions; do
    TOKEN=$(login-token)
    if is-published "$version$variant"; then
        echo "Tag is already published: $version$variant"
    else
        echo "$version$variant not published yet"

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
