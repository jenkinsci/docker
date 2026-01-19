#!/usr/bin/env bats

# bats file_tags=test-suite:plugin-cli

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load test_helpers

SUT_IMAGE=$(get_sut_image)
SUT_DESCRIPTION="${IMAGE}-plugins-cli"

teardown() {
  clean_work_directory "${BATS_TEST_DIRNAME}" "${SUT_IMAGE}"
}

@test "[${SUT_DESCRIPTION}] plugins are installed with jenkins-plugin-cli" {
  local custom_sut_image
  custom_sut_image="$(get_test_image)"
  run docker_build_child "${SUT_IMAGE}" "${custom_sut_image}" "${BATS_TEST_DIRNAME}/plugins-cli"
  assert_success
  refute_line --partial 'Skipping already installed dependency'

  run docker run --rm "${custom_sut_image}" ls --color=never -1 /var/jenkins_home/plugins
  assert_success
  assert_line 'junit.jpi'
  assert_line 'junit.jpi.pinned'
  assert_line 'ant.jpi'
  assert_line 'ant.jpi.pinned'
  assert_line 'credentials.jpi'
  assert_line 'credentials.jpi.pinned'
  assert_line 'mesos.jpi'
  assert_line 'mesos.jpi.pinned'
  # optional dependencies
  refute_line 'metrics.jpi'
  refute_line 'metrics.jpi.pinned'
  # plugins bundled but under detached-plugins, so need to be installed
  assert_line 'mailer.jpi'
  assert_line 'mailer.jpi.pinned'
  assert_line 'git.jpi'
  assert_line 'git.jpi.pinned'
  assert_line 'filesystem_scm.jpi'
  assert_line 'filesystem_scm.jpi.pinned'
  assert_line 'docker-plugin.jpi'
  assert_line 'docker-plugin.jpi.pinned'
}

@test "[${SUT_DESCRIPTION}] plugins are installed with jenkins-plugin-cli with non-default REF" {
  local custom_sut_image custom_ref
  custom_sut_image="$(get_test_image)"
  custom_ref=/var/lib/jenkins/ref

  # Build a custom image to validate the build time behavior
  run docker_build_child "${SUT_IMAGE}" "${custom_sut_image}" "${BATS_TEST_DIRNAME}/plugins-cli/ref" --build-arg REF="${custom_ref}"
  assert_success
  refute_line --partial 'Skipping already installed dependency'

  volume_name="$(docker volume create)"
  # Start an image with the default entrypoint to test the runtime behavior
  run docker run --volume "${volume_name}:/var/jenkins_home" --rm "${custom_sut_image}" true
  assert_success

  # Check the content of the resulting data volume (expecting installed plugins as present and pinned)
  run bash -c "docker run --rm --volume ${volume_name}:/var/jenkins_home ${custom_sut_image} ls --color=never -1 /var/jenkins_home/plugins \
    | tr -d '\r' `# replace DOS line endings \r\n`"
  assert_success
  assert_line 'junit.jpi'
  assert_line 'junit.jpi.pinned'
  assert_line 'ant.jpi'
  assert_line 'ant.jpi.pinned'
}

@test "[${SUT_DESCRIPTION}] plugins are installed with jenkins-plugin-cli from a plugins file" {
  local custom_sut_image
  custom_sut_image="$(get_test_image)"

  # Then proceed with child
  run docker_build_child "${SUT_IMAGE}" "${custom_sut_image}" "${BATS_TEST_DIRNAME}/plugins-cli/pluginsfile"
  assert_success
  refute_line --partial 'Skipping already installed dependency'
  # replace DOS line endings \r\n
  run bash -c "docker run --rm ${custom_sut_image} ls --color=never -1 /var/jenkins_home/plugins | tr -d '\r'"
  assert_success
  assert_line 'junit.jpi'
  assert_line 'junit.jpi.pinned'
  assert_line 'ant.jpi'
  assert_line 'ant.jpi.pinned'
  assert_line 'credentials.jpi'
  assert_line 'credentials.jpi.pinned'
  assert_line 'mesos.jpi'
  assert_line 'mesos.jpi.pinned'
  # optional dependencies
  refute_line 'metrics.jpi'
  refute_line 'metrics.jpi.pinned'
  # plugins bundled but under detached-plugins, so need to be installed
  assert_line 'mailer.jpi'
  assert_line 'mailer.jpi.pinned'
  assert_line 'git.jpi'
  assert_line 'git.jpi.pinned'
  assert_line 'filesystem_scm.jpi'
  assert_line 'filesystem_scm.jpi.pinned'
}

@test "[${SUT_DESCRIPTION}] plugins are getting upgraded but not downgraded" {
  local custom_sut_image_first custom_sut_image_second
  custom_sut_image_first="$(get_test_image)"
  custom_sut_image_second="${custom_sut_image_first}-2"

  # Build first image with junit 1.6 and ant-plugin 1.3
  run docker_build_child "${SUT_IMAGE}" "${custom_sut_image_first}" "${BATS_TEST_DIRNAME}/plugins-cli"
  assert_success

  local volume_name
  volume_name="$(docker volume create)"

  # Generates a jenkins home (in the volume) with the plugins junit 1.6 and ant-plugin 1.3 from first image's reference
  run docker run --volume "$volume_name:/var/jenkins_home" --rm "${custom_sut_image_first}" true
  assert_success
  run unzip_manifest junit.jpi "$volume_name"
  assert_line 'Plugin-Version: 1.6'
  run unzip_manifest ant.jpi "$volume_name"
  assert_line 'Plugin-Version: 1.3'

  # Build second image with junit 1.28 and ant 1.2
  run docker_build_child "${SUT_IMAGE}" "${custom_sut_image_second}" "${BATS_TEST_DIRNAME}/upgrade-plugins"
  assert_success

  # Execute the second image with the existing jenkins volume: junit plugin should be updated, and ant should NOT be downgraded
  run docker run --volume "$volume_name:/var/jenkins_home" --rm "${custom_sut_image_second}" true
  assert_success
  run unzip_manifest junit.jpi "$volume_name"
  assert_success
  # Should be updated
  assert_line 'Plugin-Version: 1.28'
  run unzip_manifest ant.jpi "$volume_name"
  # 1.2 is older than the existing 1.3, so keep 1.3
  assert_line 'Plugin-Version: 1.3'
}

@test "[${SUT_DESCRIPTION}] do not upgrade if plugin has been manually updated" {
  local custom_sut_image_first custom_sut_image_second
  custom_sut_image_first="$(get_test_image)"
  custom_sut_image_second="${custom_sut_image_first}-2"

  ## Generates an image with the plugin junit 1.6
  run docker_build_child "${SUT_IMAGE}" "${custom_sut_image_first}" "${BATS_TEST_DIRNAME}/plugins-cli"
  assert_success

  ## Image contains junit 1.6, which is manually upgraded to 1.8
  local volume_name
  volume_name="$(docker volume create)"
  run docker run --volume "${volume_name}:/var/jenkins_home" --rm "${custom_sut_image_first}" \
    curl --connect-timeout 20 --retry 5 --retry-delay 0 --retry-max-time 60 --silent \
      --fail --location https://updates.jenkins.io/download/plugins/junit/1.8/junit.hpi \
      --output /var/jenkins_home/plugins/junit.jpi
  assert_success
  run unzip_manifest junit.jpi "$volume_name"
  assert_line 'Plugin-Version: 1.8'

  ## Generates an image with the plugin junit 1.28 (upgraded)
  run docker_build_child "${SUT_IMAGE}" "${custom_sut_image_second}" "${BATS_TEST_DIRNAME}/upgrade-plugins"
  assert_success

  # The image with junit 1.28 should not upgrade the version 1.8 in the volume (jenkins_home)
  run docker run --volume "${volume_name}:/var/jenkins_home" --rm ${custom_sut_image_second} true
  assert_success
  # junit shouldn't be upgraded
  run unzip_manifest junit.jpi "$volume_name"
  assert_success
  assert_line 'Plugin-Version: 1.8'
  refute_line 'Plugin-Version: 1.28'
}

@test "[${SUT_DESCRIPTION}] upgrade plugin even if it has been manually updated when PLUGINS_FORCE_UPGRADE=true" {
  local custom_sut_image_first custom_sut_image_second
  custom_sut_image_first="$(get_test_image)"
  custom_sut_image_second="${custom_sut_image_first}-2"

  ## Generates an image with the plugin junit 1.6
  run docker_build_child "${SUT_IMAGE}" "${custom_sut_image_first}" "${BATS_TEST_DIRNAME}/plugins-cli"
  assert_success

  ## Image contains junit 1.6, which is manually upgraded to 1.8
  local volume_name
  volume_name="$(docker volume create)"
  run docker run --volume "${volume_name}:/var/jenkins_home" --rm "${custom_sut_image_first}" \
    curl --connect-timeout 20 --retry 5 --retry-delay 0 --retry-max-time 60 --silent \
      --fail --location https://updates.jenkins.io/download/plugins/junit/1.8/junit.hpi \
      --output /var/jenkins_home/plugins/junit.jpi
  assert_success
  run unzip_manifest junit.jpi "$volume_name"
  assert_line 'Plugin-Version: 1.8'

  ## Generates an image with the plugin junit 1.28 (upgraded)
  run docker_build_child "${SUT_IMAGE}" "${custom_sut_image_second}" "${BATS_TEST_DIRNAME}/upgrade-plugins"
  assert_success

  # The image with junit 1.28 should force-upgrade junit in the volume (jenkins_home)
  run docker run --volume "${volume_name}:/var/jenkins_home" --env PLUGINS_FORCE_UPGRADE=true --rm ${custom_sut_image_second} true
  assert_success
  # junit shouldn't be upgraded
  run unzip_manifest junit.jpi "$volume_name"
  assert_success
  refute_line 'Plugin-Version: 1.8'
  assert_line 'Plugin-Version: 1.28'
}


@test "[${SUT_DESCRIPTION}] plugins are installed with jenkins-plugin-cli and no war" {
  local custom_sut_image
  custom_sut_image="$(get_test_image)"
  run docker_build_child "${SUT_IMAGE}" "${custom_sut_image}" "${BATS_TEST_DIRNAME}/plugins-cli/no-war"
  assert_success
}

@test "[${SUT_DESCRIPTION}] Use a custom jenkins.war" {
  local custom_sut_image
  custom_sut_image="$(get_test_image)"
  # Build the image using the right Dockerfile setting a new war with JENKINS_WAR env and with a weird plugin inside
  run docker_build_child "${SUT_IMAGE}" "${custom_sut_image}" "${BATS_TEST_DIRNAME}/plugins-cli/custom-war"
  assert_success
}

@test "[${SUT_DESCRIPTION}] JAVA_OPTS environment variable is used with jenkins-plugin-cli" {
  local custom_sut_image
  custom_sut_image="$(get_test_image)"
  run docker_build_child "${SUT_IMAGE}" "${custom_sut_image}" "${BATS_TEST_DIRNAME}/plugins-cli/java-opts"
  assert_success
  # Assert JAVA_OPTS has been used and 'java.opts.test' has been set to JVM
  assert_line --regexp 'java.opts.test.*=.*true'
}
