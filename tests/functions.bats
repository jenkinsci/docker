#!/usr/bin/env bats

# bats file_tags=test-suite:functions

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load test_helpers

SUT_IMAGE=$(get_sut_image)
SUT_DESCRIPTION="${IMAGE}-functions"

. $BATS_TEST_DIRNAME/../jenkins-support

@test "[${SUT_DESCRIPTION}] versionLT" {
  run docker run --rm $SUT_IMAGE bash -c "source /usr/local/bin/jenkins-support && versionLT 1.0 1.0"
  assert_failure
  run docker run --rm $SUT_IMAGE bash -c "source /usr/local/bin/jenkins-support && versionLT 1.0 1.1"
  assert_success
  run docker run --rm $SUT_IMAGE bash -c "source /usr/local/bin/jenkins-support && versionLT 1.1 1.0"
  assert_failure
  ## Real world examples from https://github.com/jenkinsci/docker/issues/1456
  # commons-lang3-api-plugin/releases
  run docker run --rm $SUT_IMAGE bash -c "source /usr/local/bin/jenkins-support && versionLT 3.12.0.0 3.12.0-36.vd97de6465d5b_"
  assert_success
  # map-db-plugin
  run docker run --rm $SUT_IMAGE bash -c "source /usr/local/bin/jenkins-support && versionLT 1.0.9.0 1.0.9-28.vf251ce40855d"
  assert_success
  # role-strategy-plugin, security fix backport
  run docker run --rm $SUT_IMAGE bash -c "source /usr/local/bin/jenkins-support && versionLT 587.v2872c41fa_e51 587.588.v850a_20a_30162"
  assert_success
  # workflow-cps-plugin, security fix backport
  run docker run --rm $SUT_IMAGE bash -c "source /usr/local/bin/jenkins-support && versionLT 3894.vd0f0248b_a_fc4 3894.3896.vca_2c931e7935"
  assert_success
  # workflow-cps-plugin, security fix backport of an older release, published later than a newer normal release
  run docker run --rm $SUT_IMAGE bash -c "source /usr/local/bin/jenkins-support && versionLT 4106.4108.v841a_e1819d4d 4151.v5406e29e3c90"
  assert_success
}

@test "[${SUT_DESCRIPTION}] permissions are propagated from override file" {
  local sut_image="${SUT_IMAGE}-functions-${BATS_TEST_NUMBER}"
  run docker_build_child "${SUT_IMAGE}" "${sut_image}" $BATS_TEST_DIRNAME/functions
  assert_success
  # Create a predefined named volume and fill it with a file in an unexpected file mode
  local volume_name
  volume_name="functions_${BATS_TEST_NUMBER}"
  run bash -c "docker volume rm ${volume_name}; docker volume create ${volume_name}"
  run docker run --rm --volume "${volume_name}:/sut_data" --user=0 "${sut_image}" \
    bash -c "mkdir -p /sut_data/.ssh && touch /sut_data/.ssh/config && chmod 644 /sut_data/.ssh/config && chown -R 1000:1000 /sut_data"
  # replace DOS line endings \r\n
  run bash -c "docker run --rm --volume "${volume_name}:/var/jenkins_home:rw" "${sut_image}" stat -c '%a' /var/jenkins_home/.ssh/config"
  assert_success
  assert_line '600'
  # Cleanup
  run docker volume rm "${volume_name}"
}
