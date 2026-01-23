#!/usr/bin/env bats

# bats file_tags=test-suite:bake
# bats file_tags=test-type:golden-file

load test_helpers

SUT_DESCRIPTION="docker bake"
LTS_JENKINS_VERSION="2.541.1"

@test "[${SUT_DESCRIPTION}: tags] Default tags unchanged" {
  assert_matches_golden expected_tags make --silent tags
}
@test "[${SUT_DESCRIPTION}: tags] Latest weekly tags unchanged" {
  assert_matches_golden expected_tags_latest_weekly make --silent tags LATEST_WEEKLY=true
}
@test "[${SUT_DESCRIPTION}: tags] Latest LTS tags unchanged" {
  assert_matches_golden expected_tags_latest_lts make --silent tags LATEST_LTS=true JENKINS_VERSION="${LTS_JENKINS_VERSION}"
}

@test "[${SUT_DESCRIPTION}: platforms] Platforms per target unchanged" {
  assert_matches_golden expected_platforms make --silent platforms
}
