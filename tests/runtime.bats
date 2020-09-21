#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load test_helpers

SUT_IMAGE=$(sut_image)
SUT_CONTAINER=$(sut_image)
SUT_DESCRIPTION=$(echo $SUT_IMAGE | sed -e 's/bats-jenkins-//g')

@test "[${SUT_DESCRIPTION}] build image" {
  cd $BATS_TEST_DIRNAME/..
  docker_build -t $SUT_IMAGE .
}

@test "[${SUT_DESCRIPTION}] clean test containers" {
    cleanup $SUT_CONTAINER
}

@test "[${SUT_DESCRIPTION}] test multiple JENKINS_OPTS" {
  # running --help --version should return the version, not the help
  local version=$(grep 'ENV JENKINS_VERSION' Dockerfile | sed -e 's/.*:-\(.*\)}/\1/')
  # need the last line of output
  assert "${version}" docker run --rm -e JENKINS_OPTS="--help --version" --name $SUT_CONTAINER -P $SUT_IMAGE | tail -n 1
}

@test "[${SUT_DESCRIPTION}] test jenkins arguments" {
  # running --help --version should return the version, not the help
  local version=$(grep 'ENV JENKINS_VERSION' Dockerfile | sed -e 's/.*:-\(.*\)}/\1/')
  # need the last line of output
  assert "${version}" docker run --rm --name $SUT_CONTAINER -P $SUT_IMAGE --help --version | tail -n 1
}

@test "[${SUT_DESCRIPTION}] timezones are handled correctly" {
    local timezone1
    local timezone2

    run docker run --rm --name $SUT_CONTAINER  $SUT_IMAGE bash -c "date +'%Z %z'"
    timezone1="${output}"
    assert_equal "${timezone1}" "UTC +0000"

    run docker run --rm --name $SUT_CONTAINER -e "TZ=Europe/Luxembourg" $SUT_IMAGE bash -c "date +'%Z %z'"
    timezone1="${output}"
    run docker run --rm --name $SUT_CONTAINER -e "TZ=Australia/Sydney" $SUT_IMAGE bash -c "date +'%Z %z'"
    timezone2="${output}"

    refute [ "${timezone1}" = "${timezone2}" ]
}

@test "[${SUT_DESCRIPTION}] create test container" {
    docker run -d -e JAVA_OPTS="-Duser.timezone=Europe/Madrid -Dhudson.model.DirectoryBrowserSupport.CSP=\"default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';\"" --name $SUT_CONTAINER -P $SUT_IMAGE
}

@test "[${SUT_DESCRIPTION}] test container is running" {
  sleep 1  # give time to eventually fail to initialize
  retry 3 1 assert "true" docker inspect -f {{.State.Running}} $SUT_CONTAINER
}

@test "[${SUT_DESCRIPTION}] Jenkins is initialized" {
    retry 30 5 test_url /api/json
}

@test "[${SUT_DESCRIPTION}] JAVA_OPTS are set" {
    local sed_expr='s/<wbr>//g;s/<td class="pane">.*<\/td><td class.*normal">//g;s/<t.>//g;s/<\/t.>//g'
    assert 'default-src &#039;self&#039;; script-src &#039;self&#039; &#039;unsafe-inline&#039; &#039;unsafe-eval&#039;; style-src &#039;self&#039; &#039;unsafe-inline&#039;;' \
      bash -c "curl -fsSL --user \"admin:$(get_jenkins_password)\" $(get_jenkins_url)/systemInfo | sed 's/<\/tr>/<\/tr>\'$'\n/g' | grep '<td class=\"pane\">hudson.model.DirectoryBrowserSupport.CSP</td>' | sed -e '${sed_expr}'"
    assert 'Europe/Madrid' \
      bash -c "curl -fsSL --user \"admin:$(get_jenkins_password)\" $(get_jenkins_url)/systemInfo | sed 's/<\/tr>/<\/tr>\'$'\n/g' | grep '<td class=\"pane\">user.timezone</td>' | sed -e '${sed_expr}'"
}

@test "[${SUT_DESCRIPTION}] clean test containers" {
    cleanup $SUT_CONTAINER
}
