#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load test_helpers

. $BATS_TEST_DIRNAME/../jenkins-support

@test "versionLT" {
  run versionLT 1.0 1.0
  assert_failure
  run versionLT 1.0 1.1
  assert_success
  run versionLT 1.1 1.0
  assert_failure
  run versionLT 1.0-beta-1 1.0
  assert_success
  run versionLT 1.0 1.0-beta-1
  assert_failure
  run versionLT 1.0-alpha-1 1.0-beta-1
  assert_success
  run versionLT 1.0-beta-1 1.0-alpha-1
  assert_failure
}
