#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load test_helpers

SUT_IMAGE=$(sut_image)

. $BATS_TEST_DIRNAME/../jenkins-support

@test "build image" {
  cd $BATS_TEST_DIRNAME/..
  docker_build -t $SUT_IMAGE .
}

@test "versionLT" {
  run docker run --rm $SUT_IMAGE bash -c "source /usr/local/bin/jenkins-support && versionLT 1.0 1.0"
  assert_failure
  run docker run --rm $SUT_IMAGE bash -c "source /usr/local/bin/jenkins-support && versionLT 1.0 1.1"
  assert_success
  run docker run --rm $SUT_IMAGE bash -c "source /usr/local/bin/jenkins-support && versionLT 1.1 1.0"
  assert_failure
  run docker run --rm $SUT_IMAGE bash -c "source /usr/local/bin/jenkins-support && versionLT 1.0-beta-1 1.0"
  assert_success
  run docker run --rm $SUT_IMAGE bash -c "source /usr/local/bin/jenkins-support && versionLT 1.0 1.0-beta-1"
  assert_failure
  run docker run --rm $SUT_IMAGE bash -c "source /usr/local/bin/jenkins-support && versionLT 1.0-alpha-1 1.0-beta-1"
  assert_success
  run docker run --rm $SUT_IMAGE bash -c "source /usr/local/bin/jenkins-support && versionLT 1.0-beta-1 1.0-alpha-1"
  assert_failure
}

@test "permissions are propagated from override file" {
  run docker_build_child $SUT_IMAGE-functions $BATS_TEST_DIRNAME/functions
  assert_success

  # replace DOS line endings \r\n
  run bash -c "docker run -v $BATS_TEST_DIRNAME/functions:/var/jenkins_home --rm $SUT_IMAGE-functions stat -c '%a' /var/jenkins_home/.ssh/config"
  assert_success
  assert_line '600'
}