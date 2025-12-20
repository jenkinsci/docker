#!/usr/bin/env bats

load test_helpers

SUT_DESCRIPTION="tags"

@test "[${SUT_DESCRIPTION}] Default tags unchanged" {
  assert_matches_golden expected_tags make tags
}

@test "[${SUT_DESCRIPTION}] Latest weekly tags unchanged" {
  assert_matches_golden expected_tags_latest_weekly make tags LATEST_WEEKLY=true
}

@test "[${SUT_DESCRIPTION}] Latest LTS tags unchanged" {
  assert_matches_golden expected_tags_latest_lts make tags LATEST_LTS=true
}
