#!/usr/bin/env bats

SUT_IMAGE=bats-jenkins
SUT_CONTAINER=bats-jenkins

load test_helpers

@test "build image" {
  cd $BATS_TEST_DIRNAME/..
  docker build -t $SUT_IMAGE .
}

@test "clean test containers" {
    cleanup $SUT_CONTAINER
}

@test "test multiple JENKINS_OPTS" {
  # running --help --version should return the version, not the help
  local version=$(grep 'ENV JENKINS_VERSION' Dockerfile | sed -e 's/.*:-\(.*\)}/\1/')
  # need the last line of output, removing the last char
  local actual_version=$(docker run --rm -ti -e JENKINS_OPTS="--help --version" --name $SUT_CONTAINER -P $SUT_IMAGE | tail -n 1)
  assert "${version}" echo "${actual_version::-1}"
}

@test "test jenkins arguments" {
  # running --help --version should return the version, not the help
  local version=$(grep 'ENV JENKINS_VERSION' Dockerfile | sed -e 's/.*:-\(.*\)}/\1/')
  # need the last line of output, removing the last char
  local actual_version=$(docker run --rm -ti --name $SUT_CONTAINER -P $SUT_IMAGE --help --version | tail -n 1)
  assert "${version}" echo "${actual_version::-1}"
}

@test "test Xmx with unlimited memory" {
  local total_memory=$(docker run --rm -ti --name $SUT_CONTAINER -P $SUT_IMAGE awk '/MemTotal/ {printf("%d\n", $2/1024)}' /proc/meminfo)
  local actual_java_options=$(docker run --rm -ti --name $SUT_CONTAINER -P $SUT_IMAGE bash -c 'echo ${_JAVA_OPTIONS}')
  local expected_memory=$(awk '{printf("%d",$1/2)}' <<<" ${total_memory} ")
  assert "-Xmx${expected_memory}m" echo "${actual_java_options::-1}"
}

@test "test Xmx with memory limit" {
  local actual_java_options=$(docker run --rm -ti -m 256m --name $SUT_CONTAINER -P $SUT_IMAGE bash -c 'echo ${_JAVA_OPTIONS}')
  assert "-Xmx128m" echo "${actual_java_options::-1}"
}

@test "test Xmx with memory limit and custom JVM_HEAP_RATIO" {
  local actual_java_options=$(docker run --rm -ti -e JVM_HEAP_RATIO=0.75 -m 256m --name $SUT_CONTAINER -P $SUT_IMAGE bash -c 'echo ${_JAVA_OPTIONS}')
  assert "-Xmx192m" echo "${actual_java_options::-1}"
}

@test "create test container" {
    docker run -d -e JAVA_OPTS="-Duser.timezone=Europe/Madrid -Dhudson.model.DirectoryBrowserSupport.CSP=\"default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';\"" --name $SUT_CONTAINER -P $SUT_IMAGE
}

@test "test container is running" {
  sleep 1  # give time to eventually fail to initialize
  retry 3 1 assert "true" docker inspect -f {{.State.Running}} $SUT_CONTAINER
}

@test "Jenkins is initialized" {
    retry 30 5 test_url /api/json
}

@test "JAVA_OPTS are set" {
    local sed_expr='s/<wbr>//g;s/<td class="pane">.*<\/td><td class.*normal">//g;s/<t.>//g;s/<\/t.>//g'
    assert 'default-src &#039;self&#039;; script-src &#039;self&#039; &#039;unsafe-inline&#039; &#039;unsafe-eval&#039;; style-src &#039;self&#039; &#039;unsafe-inline&#039;;' \
      bash -c "curl -fsSL $(get_jenkins_url)/systemInfo | sed 's/<\/tr>/<\/tr>\'$'\n/g' | grep '<td class=\"pane\">hudson.model.DirectoryBrowserSupport.CSP</td>' | sed -e '${sed_expr}'"
    assert 'Europe/Madrid' \
      bash -c "curl -fsSL $(get_jenkins_url)/systemInfo | sed 's/<\/tr>/<\/tr>\'$'\n/g' | grep '<td class=\"pane\">user.timezone</td>' | sed -e '${sed_expr}'"
}

@test "clean test containers" {
    cleanup $SUT_CONTAINER
}
