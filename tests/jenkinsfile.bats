#!/usr/bin/env bats

# bats file_tags=test-suite:jenkinsfile

load test_helpers

SUT_DESCRIPTION="Jenkinsfile"

@test "[${SUT_DESCRIPTION}] Default (weekly) Linux targets from docker bake are taken in account in Jenkinsfile" {
  [ "$(get_default_docker_bake_linux_targets)" == "$(get_targets_from_jenkinsfile)" ]
}
