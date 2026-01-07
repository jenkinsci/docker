#!/usr/bin/env bats

# bats file_tags=test-suite:jenkinsfile

load test_helpers

SUT_DESCRIPTION="Jenkinsfile"

@test "[${SUT_DESCRIPTION}] Default (weekly) targets are taken in account in Jenkinsfile" {
  [ "$(get_default_weekly_targets)" == "$(get_targets_from_jenkinsfile)" ]
}
