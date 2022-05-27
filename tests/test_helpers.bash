#!/bin/bash

# Assert that $1 is the outputof a command $2
function assert {
    local expected_output=$1
    shift
    local actual_output
    actual_output=$("$@")
    actual_output="${actual_output//[$'\t\r\n']}" # remove newlines
    if ! [ "$actual_output" = "$expected_output" ]; then
        echo "expected: \"$expected_output\""
        echo "actual:   \"$actual_output\""
        false
    fi
}

# Retry a command $1 times until it succeeds. Wait $2 seconds between retries.
function retry {
    local attempts=$1
    shift
    local delay=$1
    shift
    local i

    for ((i=0; i < attempts; i++)); do
        run "$@"
        # shellcheck disable=SC2154
        if [ "$status" -eq 0 ]; then
            return 0
        fi
        sleep "${delay}"
    done

    # shellcheck disable=SC2154
    echo "Command \"$*\" failed $attempts times. Status: $status. Output: $output" >&2
    false
}

function get_sut_image {
    test -n "${IMAGE:?"[sut_image] Please set the variable 'IMAGE' to the name of the image to test in 'docker-bake.hcl'."}"
    ## Retrieve the SUT image name from buildx
    # Option --print for 'docker buildx bake' prints the JSON configuration on the stdout
    # Option --silent for 'make' suppresses the echoing of command so the output is valid JSON
    # The image name is the 1st of the "tags" array, on the first "image" found
    make --silent show | jq -r ".target.${IMAGE}.tags[0]"
}

function get_jenkins_version() {
  test -n "${IMAGE:?"[sut_image] Please set the variable 'IMAGE' to the name of the image to test in 'docker-bake.hcl'."}"

  make --silent show | jq -r ".target.${IMAGE}.args.JENKINS_VERSION"
}

function get_commit_sha() {
  test -n "${IMAGE:?"[sut_image] Please set the variable 'IMAGE' to the name of the image to test in 'docker-bake.hcl'."}"

  make --silent show | jq -r ".target.${IMAGE}.args.COMMIT_SHA"
}

function get_test_image {
    test -n "${BATS_TEST_NUMBER:?"[get_test_image] Please set the variable BATS_TEST_NUMBER."}"
    test -n "${SUT_DESCRIPTION:?"[get_test_image] Please set the variable SUT_DESCRIPTION."}"
    echo "${SUT_DESCRIPTION}-${BATS_TEST_NUMBER}"
}

function get_sut_container_name {
    echo "$(get_test_image)-container"
}

function docker_build_child {
    local parent=$1; shift
    local tag=$1; shift
    local dir=$1; shift
    local build_opts=("$@")
    local tmp
    tmp=$(mktemp "$dir/Dockerfile.XXXXXX")
    sed -e "s#FROM bats-jenkins.*#FROM ${parent}#g" "$dir/Dockerfile" > "$tmp"
    docker build --tag "$tag" "${build_opts[@]}" --file "${tmp}" "${dir}" 2>&1
    rm "$tmp"
}

function get_jenkins_url {
    if [ -z "${DOCKER_HOST}" ]; then
        DOCKER_IP=localhost
    else
        # shellcheck disable=SC2001
        DOCKER_IP=$(echo "$DOCKER_HOST" | sed -e 's|tcp://\(.*\):[0-9]*|\1|')
    fi
    echo "http://$DOCKER_IP:$(docker port "$(get_sut_container_name)" 8080 | cut -d: -f2)"
}

function get_jenkins_password {
    docker logs "$(get_sut_container_name)" 2>&1 | grep -A 2 "Please use the following password to proceed to installation" | tail -n 1
}

function test_url {
    run curl --user "admin:$(get_jenkins_password)" --output /dev/null --silent --head --fail --connect-timeout 30 --max-time 60 "$(get_jenkins_url)$1"
    if [ "$status" -eq 0 ]; then
        true
    else
        echo "URL $(get_jenkins_url)$1 failed" >&2
        echo "output: $output" >&2
        false
    fi
}

function cleanup {
    docker kill "$1" &>/dev/null ||:
    docker rm -fv "$1" &>/dev/null ||:
}

function unzip_manifest {
    local plugin=$1
    local volume_name=$2
    export SUT_IMAGE
    docker run --rm --volume "${volume_name}:/var/jenkins_home" --entrypoint unzip "${SUT_IMAGE}" \
        -p "/var/jenkins_home/plugins/${plugin}" META-INF/MANIFEST.MF | tr -d '\r'
}

function clean_work_directory {
    local workdir=$1
    local sut_image=$2
    rm -rf "${workdir}/upgrade-plugins/work-${sut_image}"
}
