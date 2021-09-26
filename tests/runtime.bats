#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load test_helpers

IMAGE=${IMAGE:-debian_jdk17}
SUT_IMAGE=$(get_sut_image)
SUT_DESCRIPTION="${IMAGE}-runtime"

@test "[${SUT_DESCRIPTION}] test version in docker metadata" {
  local version=$(get_jenkins_version)
  assert "${version}" docker inspect --format '{{ index .Config.Labels "org.opencontainers.image.version"}}' $SUT_IMAGE
}

@test "[${SUT_DESCRIPTION}] test multiple JENKINS_OPTS" {
  local container_name version
  # running --help --version should return the version, not the help
  version=$(get_jenkins_version)
  container_name="$(get_sut_container_name)"
  cleanup "${container_name}"
  # need the last line of output
  assert "${version}" docker run --rm --env JENKINS_OPTS="--help --version" --name "${container_name}" -P $SUT_IMAGE | tail -n 1
}

@test "[${SUT_DESCRIPTION}] test jenkins arguments" {
  local container_name version
  # running --help --version should return the version, not the help
  version=$(get_jenkins_version)
  container_name="$(get_sut_container_name)"
  cleanup "${container_name}"
  # need the last line of output
  assert "${version}" docker run --rm --name "${container_name}" -P $SUT_IMAGE --help --version | tail -n 1
}

@test "[${SUT_DESCRIPTION}] timezones are handled correctly" {
  local timezone1 timezone2 container_name
  container_name="$(get_sut_container_name)"
  cleanup "${container_name}"

  run docker run --rm --name "${container_name}" $SUT_IMAGE bash -c "date +'%Z %z'"
  timezone1="${output}"
  assert_equal "${timezone1}" "UTC +0000"

  run docker run --rm --name "${container_name}" --env "TZ=Europe/Luxembourg" $SUT_IMAGE bash -c "date +'%Z %z'"
  timezone1="${output}"
  run docker run --rm --name "${container_name}" --env "TZ=Australia/Sydney" $SUT_IMAGE bash -c "date +'%Z %z'"
  timezone2="${output}"

  refute [ "${timezone1}" = "${timezone2}" ]
}

@test "[${SUT_DESCRIPTION}] has utf-8 locale" {
  if [[ "${SUT_IMAGE}" == *"alpine"*  ]]; then
    run docker run --rm "${SUT_IMAGE}" /usr/glibc-compat/bin/locale charmap
  else
    run docker run --rm "${SUT_IMAGE}" locale charmap
  fi
  assert_equal "${output}" "UTF-8"
}

@test "[${SUT_DESCRIPTION}] create test container with Jenkins initialize and JAVA_OPTS are set" {
  local container_name
  container_name="$(get_sut_container_name)"
  cleanup "${container_name}"

  run docker run --detach --name "${container_name}" --publish-all \
    --env JAVA_OPTS="-Duser.timezone=Europe/Madrid -Dhudson.model.DirectoryBrowserSupport.CSP=\"default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';\"" \
    $SUT_IMAGE
  assert_success

  # Container is running
  sleep 1  # give time to eventually fail to initialize
  retry 3 1 assert "true" docker inspect -f '{{.State.Running}}' "${container_name}"

  # Jenkins is initialized
  retry 30 5 test_url /api/json

  # JAVA_OPTS are set
  local sed_expr='s/<wbr>//g;s/<td class="pane">.*<\/td><td class.*normal">//g;s/<t.>//g;s/<\/t.>//g'
  assert 'default-src &#039;self&#039;; script-src &#039;self&#039; &#039;unsafe-inline&#039; &#039;unsafe-eval&#039;; style-src &#039;self&#039; &#039;unsafe-inline&#039;;' \
    bash -c "curl -fsSL --user \"admin:$(get_jenkins_password)\" $(get_jenkins_url)/systemInfo | sed 's/<\/tr>/<\/tr>\'$'\n/g' | grep '<td class=\"pane\">hudson.model.DirectoryBrowserSupport.CSP</td>' | sed -e '${sed_expr}'"
  assert 'Europe/Madrid' \
    bash -c "curl -fsSL --user \"admin:$(get_jenkins_password)\" $(get_jenkins_url)/systemInfo | sed 's/<\/tr>/<\/tr>\'$'\n/g' | grep '<td class=\"pane\">user.timezone</td>' | sed -e '${sed_expr}'"
}
