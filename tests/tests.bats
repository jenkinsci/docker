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
  local version=$(grep 'ENV JENKINS_VERSION' Dockerfile | sed -e 's/ENV JENKINS_VERSION //')
  # need the last line of output, removing the last char
  local actual_version=$(docker run --rm -ti -e JENKINS_OPTS="--help --version" --name $SUT_CONTAINER -P $SUT_IMAGE | tail -n 1)
  assert "${version}" echo ${actual_version::-1}
}

@test "test jenkins arguments" {
  # running --help --version should return the version, not the help
  local version=$(grep 'ENV JENKINS_VERSION' Dockerfile | sed -e 's/ENV JENKINS_VERSION //')
  # need the last line of output, removing the last char
  local actual_version=$(docker run --rm -ti --name $SUT_CONTAINER -P $SUT_IMAGE --help --version | tail -n 1)
  assert "${version}" echo ${actual_version::-1}
}

@test "create test container" {
    docker run -d --name $SUT_CONTAINER -P $SUT_IMAGE
}

@test "test container is running" {
  sleep 1  # give time to eventually fail to initialize
  retry 3 1 assert "true" docker inspect -f {{.State.Running}} $SUT_CONTAINER
}

@test "Jenkins is initialized" {
    retry 30 5 test_url /api/json
}

@test "clean test containers" {
    cleanup $SUT_CONTAINER
}
