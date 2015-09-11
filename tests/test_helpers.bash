
# check dependencies
(
    type docker &>/dev/null || ( echo "docker is not available"; exit 1 )
    type curl &>/dev/null || ( echo "curl is not available"; exit 1 )
)>&2

# Assert that $1 is the outputof a command $2
function assert {
    local expected_output=$1
    shift
    actual_output=$("$@")
    if ! [ "$actual_output" = "$expected_output" ]; then
        echo "expected: \"$expected_output\", actual: \"$actual_output\""
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
        if [ "$status" -eq 0 ]; then
            return 0
        fi
        sleep $delay
    done

    echo "Command \"$@\" failed $attempts times. Status: $status. Output: $output" >&2
    false
}

function get_jenkins_url {
    if [ -z $DOCKER_HOST]; then
        DOCKER_IP=localhost
    else
        DOCKER_IP=$(echo $DOCKER_HOST | sed -e 's|tcp://\(.*\):[0-9]*|\1|')
    fi
    echo "http://$DOCKER_IP:$(docker port $SUT_CONTAINER 8080 | cut -d: -f2)"
}

function test_url {
    run curl --output /dev/null --silent --head --fail --connect-timeout 30 --max-time 60 $(get_jenkins_url)$1
    if [ "$status" -eq 0 ]; then
        true
    else
        echo "URL $(get_jenkins_url)$1 failed" >&2
        echo "output: $output" >&2
        false
    fi
}
