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
  ## https://github.com/jenkinsci/docker/issues/2328
  ## Reverse-direction cases: image is the 4-part backport / maintenance release, installed is the 3-part normal release.
  ## copy_reference_file() calls versionLT(image, container) at this site, so the workaround has to handle both argument orders.
  # workflow-cps-plugin, reverse-direction
  run docker run --rm $SUT_IMAGE bash -c "source /usr/local/bin/jenkins-support && versionLT 3894.3896.vca_2c931e7935 3894.vd0f0248b_a_fc4"
  assert_failure
  # github-branch-source-plugin, 1967.x security maintenance branch
  run docker run --rm $SUT_IMAGE bash -c "source /usr/local/bin/jenkins-support && versionLT 1967.1969.v205fd594c821 1967.vdea_d580c1a_b_a_"
  assert_failure
  # workflow-job-plugin, same shape
  run docker run --rm $SUT_IMAGE bash -c "source /usr/local/bin/jenkins-support && versionLT 1571.1580.v18e46842c125 1571.vb_423c255d6d9"
  assert_failure
  # role-strategy-plugin, reverse-direction
  run docker run --rm $SUT_IMAGE bash -c "source /usr/local/bin/jenkins-support && versionLT 587.588.v850a_20a_30162 587.v2872c41fa_e51"
  assert_failure
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

@test "[${SUT_DESCRIPTION}] substitute_env_vars replaces variable with env value" {
  local volume_name
  volume_name="subst_replace_${BATS_TEST_NUMBER}"
  run bash -c "docker volume rm -f ${volume_name}; docker volume create ${volume_name}"
  run docker run --rm \
    -e JENKINS_ENABLE_ENV_SUBST=true \
    -e JENKINS_URL=http://prod.example.com \
    --volume "${volume_name}:/var/jenkins_home" \
    "${SUT_IMAGE}" bash -c "
      mkdir -p /usr/share/jenkins/ref
      echo '<jenkinsUrl>\${JENKINS_URL:-http://localhost:8080/}</jenkinsUrl>' > /usr/share/jenkins/ref/test.xml
      source /usr/local/bin/jenkins-support
      copy_reference_file /usr/share/jenkins/ref/test.xml
      cat /var/jenkins_home/test.xml
    "
  assert_success
  assert_output '<jenkinsUrl>http://prod.example.com</jenkinsUrl>'
  run docker volume rm "${volume_name}"
}

@test "[${SUT_DESCRIPTION}] substitute_env_vars preserves ampersands in env values" {
  local volume_name
  volume_name="subst_ampersand_${BATS_TEST_NUMBER}"
  run bash -c "docker volume rm -f ${volume_name}; docker volume create ${volume_name}"
  run docker run --rm \
    -e JENKINS_ENABLE_ENV_SUBST=true \
    -e 'JENKINS_URL=https://prod.example.com/?a=1&amp;b=2' \
    --volume "${volume_name}:/var/jenkins_home" \
    "${SUT_IMAGE}" bash -c "
      mkdir -p /usr/share/jenkins/ref
      echo '<jenkinsUrl>\${JENKINS_URL}</jenkinsUrl>' > /usr/share/jenkins/ref/test.xml
      source /usr/local/bin/jenkins-support
      copy_reference_file /usr/share/jenkins/ref/test.xml
      cat /var/jenkins_home/test.xml
    "
  assert_success
  assert_output '<jenkinsUrl>https://prod.example.com/?a=1&amp;b=2</jenkinsUrl>'
  run docker volume rm "${volume_name}"
}

@test "[${SUT_DESCRIPTION}] substitute_env_vars uses default when variable unset" {
  local volume_name
  volume_name="subst_default_${BATS_TEST_NUMBER}"
  run bash -c "docker volume rm -f ${volume_name}; docker volume create ${volume_name}"
  run docker run --rm \
    -e JENKINS_ENABLE_ENV_SUBST=true \
    --volume "${volume_name}:/var/jenkins_home" \
    "${SUT_IMAGE}" bash -c "
      mkdir -p /usr/share/jenkins/ref
      echo '<jenkinsUrl>\${JENKINS_URL:-http://localhost:8080/}</jenkinsUrl>' > /usr/share/jenkins/ref/test.xml
      source /usr/local/bin/jenkins-support
      copy_reference_file /usr/share/jenkins/ref/test.xml
      cat /var/jenkins_home/test.xml
    "
  assert_success
  assert_output '<jenkinsUrl>http://localhost:8080/</jenkinsUrl>'
  run docker volume rm "${volume_name}"
}

@test "[${SUT_DESCRIPTION}] copy_reference_file skips substitution when JENKINS_ENABLE_ENV_SUBST is unset" {
  local volume_name
  volume_name="subst_skip_${BATS_TEST_NUMBER}"
  run bash -c "docker volume rm -f ${volume_name}; docker volume create ${volume_name}"
  run docker run --rm \
    -e JENKINS_ENABLE_ENV_SUBST=false \
    -e JENKINS_URL=http://prod.example.com \
    --volume "${volume_name}:/var/jenkins_home" \
    "${SUT_IMAGE}" bash -c "
      mkdir -p /usr/share/jenkins/ref
      echo '<jenkinsUrl>\${JENKINS_URL:-http://localhost:8080/}</jenkinsUrl>' > /usr/share/jenkins/ref/test.xml
      source /usr/local/bin/jenkins-support
      copy_reference_file /usr/share/jenkins/ref/test.xml
      cat /var/jenkins_home/test.xml
    "
  assert_success
  assert_output '<jenkinsUrl>${JENKINS_URL:-http://localhost:8080/}</jenkinsUrl>'
  run docker volume rm "${volume_name}"
}

@test "[${SUT_DESCRIPTION}] substitute_env_vars handles self-referencing env values without hanging" {
  local volume_name
  volume_name="subst_recursive_${BATS_TEST_NUMBER}"
  run bash -c "docker volume rm -f ${volume_name}; docker volume create ${volume_name}"
  run docker run --rm \
    --stop-timeout 5 \
    -e JENKINS_ENABLE_ENV_SUBST=true \
    -e 'RECURSIVE_URL=${RECURSIVE_URL}' \
    --volume "${volume_name}:/var/jenkins_home" \
    "${SUT_IMAGE}" timeout 5 bash -c "
      mkdir -p /usr/share/jenkins/ref
      echo '<jenkinsUrl>\${RECURSIVE_URL}</jenkinsUrl>' > /usr/share/jenkins/ref/test.xml
      source /usr/local/bin/jenkins-support
      copy_reference_file /usr/share/jenkins/ref/test.xml
      cat /var/jenkins_home/test.xml
    "
  assert_success
  assert_output '<jenkinsUrl>${RECURSIVE_URL}</jenkinsUrl>'
  run docker volume rm "${volume_name}"
}

@test "[${SUT_DESCRIPTION}] substitute_env_vars handles mutually referencing env values without hanging" {
  local volume_name
  volume_name="subst_mutual_${BATS_TEST_NUMBER}"
  run bash -c "docker volume rm -f ${volume_name}; docker volume create ${volume_name}"
  run docker run --rm \
    --stop-timeout 5 \
    -e JENKINS_ENABLE_ENV_SUBST=true \
    -e 'VAR_A=${VAR_B}' \
    -e 'VAR_B=${VAR_A}' \
    --volume "${volume_name}:/var/jenkins_home" \
    "${SUT_IMAGE}" timeout 5 bash -c "
      mkdir -p /usr/share/jenkins/ref
      echo '<props a=\"\${VAR_A}\" b=\"\${VAR_B}\"/>' > /usr/share/jenkins/ref/test.xml
      source /usr/local/bin/jenkins-support
      copy_reference_file /usr/share/jenkins/ref/test.xml
      cat /var/jenkins_home/test.xml
    "
  assert_success
  assert_output '<props a="${VAR_B}" b="${VAR_A}"/>'
  run docker volume rm "${volume_name}"
}

@test "[${SUT_DESCRIPTION}] substitute_env_vars preserves literal nested placeholders in env values" {
  local volume_name
  volume_name="subst_nested_${BATS_TEST_NUMBER}"
  run bash -c "docker volume rm -f ${volume_name}; docker volume create ${volume_name}"
  run docker run --rm \
    -e JENKINS_ENABLE_ENV_SUBST=true \
    -e 'API_ENDPOINT=https://api.example.com/${path}?id=${id}' \
    --volume "${volume_name}:/var/jenkins_home" \
    "${SUT_IMAGE}" bash -c "
      mkdir -p /usr/share/jenkins/ref
      echo '<apiEndpoint>\${API_ENDPOINT}</apiEndpoint>' > /usr/share/jenkins/ref/test.xml
      source /usr/local/bin/jenkins-support
      copy_reference_file /usr/share/jenkins/ref/test.xml
      cat /var/jenkins_home/test.xml
    "
  assert_success
  assert_output '<apiEndpoint>https://api.example.com/${path}?id=${id}</apiEndpoint>'
  run docker volume rm "${volume_name}"
}

@test "[${SUT_DESCRIPTION}] substitute_env_vars uses default when variable is empty" {
  local volume_name
  volume_name="subst_empty_def_${BATS_TEST_NUMBER}"
  run bash -c "docker volume rm -f ${volume_name}; docker volume create ${volume_name}"
  run docker run --rm \
    -e JENKINS_ENABLE_ENV_SUBST=true \
    -e JENKINS_URL= \
    --volume "${volume_name}:/var/jenkins_home" \
    "${SUT_IMAGE}" bash -c "
      mkdir -p /usr/share/jenkins/ref
      echo '<jenkinsUrl>\${JENKINS_URL:-http://localhost:8080/}</jenkinsUrl>' > /usr/share/jenkins/ref/test.xml
      source /usr/local/bin/jenkins-support
      copy_reference_file /usr/share/jenkins/ref/test.xml
      cat /var/jenkins_home/test.xml
    "
  assert_success
  assert_output '<jenkinsUrl>http://localhost:8080/</jenkinsUrl>'
  run docker volume rm "${volume_name}"
}

@test "[${SUT_DESCRIPTION}] substitute_env_vars handles empty default syntax" {
  local volume_name
  volume_name="subst_empty_default_syntax_${BATS_TEST_NUMBER}"
  run bash -c "docker volume rm -f ${volume_name}; docker volume create ${volume_name}"
  run docker run --rm \
    -e JENKINS_ENABLE_ENV_SUBST=true \
    -e FOO_SET=configured \
    --volume "${volume_name}:/var/jenkins_home" \
    "${SUT_IMAGE}" bash -c "
      mkdir -p /usr/share/jenkins/ref
      echo '<props unset=\"\${FOO_UNSET:-}\" set=\"\${FOO_SET:-}\"/>' > /usr/share/jenkins/ref/test.xml
      source /usr/local/bin/jenkins-support
      copy_reference_file /usr/share/jenkins/ref/test.xml
      cat /var/jenkins_home/test.xml
    "
  assert_success
  assert_output '<props unset="" set="configured"/>'
  run docker volume rm "${volume_name}"
}

@test "[${SUT_DESCRIPTION}] substitute_env_vars handles multiple, adjacent, and repeated variables" {
  local volume_name
  volume_name="subst_multi_${BATS_TEST_NUMBER}"
  run bash -c "docker volume rm -f ${volume_name}; docker volume create ${volume_name}"
  run docker run --rm \
    -e JENKINS_ENABLE_ENV_SUBST=true \
    -e FOO=alpha \
    -e BAR=beta \
    --volume "${volume_name}:/var/jenkins_home" \
    "${SUT_IMAGE}" bash -c "
      mkdir -p /usr/share/jenkins/ref
      echo '<props>\${FOO}\${BAR}_\${FOO}</props>' > /usr/share/jenkins/ref/test.xml
      source /usr/local/bin/jenkins-support
      copy_reference_file /usr/share/jenkins/ref/test.xml
      cat /var/jenkins_home/test.xml
    "
  assert_success
  assert_output '<props>alphabeta_alpha</props>'
  run docker volume rm "${volume_name}"
}

@test "[${SUT_DESCRIPTION}] substitute_env_vars handles defaults containing glob metacharacters" {
  local volume_name
  volume_name="subst_glob_def_${BATS_TEST_NUMBER}"
  run bash -c "docker volume rm -f ${volume_name}; docker volume create ${volume_name}"
  run docker run --rm \
    -e JENKINS_ENABLE_ENV_SUBST=true \
    --volume "${volume_name}:/var/jenkins_home" \
    "${SUT_IMAGE}" bash -c "
      mkdir -p /usr/share/jenkins/ref
      echo '<network host=\"\${HOST:-[::1]}\" filter=\"\${FILTER:-*.log}\" match=\"\${MATCH:-file?.txt}\"/>' > /usr/share/jenkins/ref/test.xml
      source /usr/local/bin/jenkins-support
      copy_reference_file /usr/share/jenkins/ref/test.xml
      cat /var/jenkins_home/test.xml
    "
  assert_success
  assert_output '<network host="[::1]" filter="*.log" match="file?.txt"/>'
  run docker volume rm "${volume_name}"
}

@test "[${SUT_DESCRIPTION}] substitute_env_vars preserves trailing newline behavior and empty files" {
  local volume_name
  volume_name="subst_nl_${BATS_TEST_NUMBER}"
  run bash -c "docker volume rm -f ${volume_name}; docker volume create ${volume_name}"
  run docker run --rm \
    -e JENKINS_ENABLE_ENV_SUBST=true \
    -e FOO=bar \
    --volume "${volume_name}:/var/jenkins_home" \
    "${SUT_IMAGE}" bash -c "
      mkdir -p /usr/share/jenkins/ref /tmp/expected
      touch /usr/share/jenkins/ref/empty.xml
      touch /tmp/expected/empty.xml

      printf 'no_newline=\${FOO}' > /usr/share/jenkins/ref/nonewline.properties
      printf 'no_newline=bar' > /tmp/expected/nonewline.properties

      printf 'one_newline=\${FOO}\n' > /usr/share/jenkins/ref/onenewline.properties
      printf 'one_newline=bar\n' > /tmp/expected/onenewline.properties

      printf 'two_newlines=\${FOO}\n\n' > /usr/share/jenkins/ref/twonewlines.properties
      printf 'two_newlines=bar\n\n' > /tmp/expected/twonewlines.properties

      source /usr/local/bin/jenkins-support
      copy_reference_file /usr/share/jenkins/ref/empty.xml
      copy_reference_file /usr/share/jenkins/ref/nonewline.properties
      copy_reference_file /usr/share/jenkins/ref/onenewline.properties
      copy_reference_file /usr/share/jenkins/ref/twonewlines.properties

      [ -f /var/jenkins_home/empty.xml ] && \
      [ \"\$(od -v -An -tx1 /tmp/expected/empty.xml)\" = \"\$(od -v -An -tx1 /var/jenkins_home/empty.xml)\" ] && \
      [ \"\$(od -v -An -tx1 /tmp/expected/nonewline.properties)\" = \"\$(od -v -An -tx1 /var/jenkins_home/nonewline.properties)\" ] && \
      [ \"\$(od -v -An -tx1 /tmp/expected/onenewline.properties)\" = \"\$(od -v -An -tx1 /var/jenkins_home/onenewline.properties)\" ] && \
      [ \"\$(od -v -An -tx1 /tmp/expected/twonewlines.properties)\" = \"\$(od -v -An -tx1 /var/jenkins_home/twonewlines.properties)\" ]
    "
  assert_success
  run docker volume rm "${volume_name}"
}
