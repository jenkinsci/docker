#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load test_helpers

SUT_IMAGE="$(get_sut_image)"
SUT_DESCRIPTION="${IMAGE}-install-plugins"

teardown() {
  clean_work_directory "${BATS_TEST_DIRNAME}" "${SUT_IMAGE}"
}

@test "[${SUT_DESCRIPTION}] plugins are installed with install-plugins.sh but with a depreciation warning message" {
  local curl_options='--verbose --location --silent --show-error --fail'
  if docker run --rm "${SUT_IMAGE}" curl --http1.1 -sSLf https://updates.jenkins.io 2>/dev/null >/dev/null
  then
    # Force HTTP/1.1 is available (avoid HTTP/2.0)
    curl_options="${curl_options} --http1.1"
  fi
  run docker run --rm -e CURL_OPTIONS="${curl_options}" "${SUT_IMAGE}" bash -c 'install-plugins.sh junit:1.6 && ls --color=never -1 /usr/share/jenkins/ref/plugins/'
  assert_success
  assert_line --partial 'WARN: install-plugins.sh is deprecated, please switch to jenkins-plugin-cli'
  refute_line --partial 'Skipping already installed dependency'
  assert_line 'junit.jpi'
}
