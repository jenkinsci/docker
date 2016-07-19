#!/usr/bin/env bats

SUT_IMAGE=bats-jenkins
SUT_CONTAINER=bats-jenkins

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load test_helpers

@test "build image" {
  cd $BATS_TEST_DIRNAME/..
  docker build -t $SUT_IMAGE .
}

@test "clean test containers" {
    cleanup $SUT_CONTAINER
}

@test "test multiple JENKINS_OPTS" {
  # running --help --version should return the version, not the help
  local version=$(grep 'ENV JENKINS_VERSION' Dockerfile | sed -e 's/.*:-\(.*\)}/\1/')
  # need the last line of output
  assert "${version}" docker run --rm -ti -e JENKINS_OPTS="--help --version" --name $SUT_CONTAINER -P $SUT_IMAGE | tail -n 1
}

@test "test jenkins arguments" {
  # running --help --version should return the version, not the help
  local version=$(grep 'ENV JENKINS_VERSION' Dockerfile | sed -e 's/.*:-\(.*\)}/\1/')
  # need the last line of output
  assert "${version}" docker run --rm -ti --name $SUT_CONTAINER -P $SUT_IMAGE --help --version | tail -n 1
}

@test "create test container" {
    docker run -d -e JAVA_OPTS="-Duser.timezone=Europe/Madrid -Dhudson.model.DirectoryBrowserSupport.CSP=\"default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';\"" --name $SUT_CONTAINER -P $SUT_IMAGE
}

@test "test container is running" {
  sleep 1  # give time to eventually fail to initialize
  retry 3 1 assert "true" docker inspect -f {{.State.Running}} $SUT_CONTAINER
}

@test "Jenkins is initialized" {
    retry 30 5 test_url /api/json
}

@test "JAVA_OPTS are set" {
    local sed_expr='s/<wbr>//g;s/<td class="pane">.*<\/td><td class.*normal">//g;s/<t.>//g;s/<\/t.>//g'
    assert 'default-src &#039;self&#039;; script-src &#039;self&#039; &#039;unsafe-inline&#039; &#039;unsafe-eval&#039;; style-src &#039;self&#039; &#039;unsafe-inline&#039;;' \
      bash -c "curl -fsSL --user \"admin:$(get_jenkins_password)\" $(get_jenkins_url)/systemInfo | sed 's/<\/tr>/<\/tr>\'$'\n/g' | grep '<td class=\"pane\">hudson.model.DirectoryBrowserSupport.CSP</td>' | sed -e '${sed_expr}'"
    assert 'Europe/Madrid' \
      bash -c "curl -fsSL --user \"admin:$(get_jenkins_password)\" $(get_jenkins_url)/systemInfo | sed 's/<\/tr>/<\/tr>\'$'\n/g' | grep '<td class=\"pane\">user.timezone</td>' | sed -e '${sed_expr}'"
}

@test "plugins are installed with plugins.sh" {
  run docker build -t $SUT_IMAGE-plugins $BATS_TEST_DIRNAME/plugins
  assert_success
  # replace DOS line endings \r\n
  run bash -c "docker run -ti --rm $SUT_IMAGE-plugins ls --color=never -1 /var/jenkins_home/plugins | tr -d '\r'"
  assert_success
  refute_line 'maven-plugin.jpi'
  refute_line 'maven-plugin.jpi.pinned'
  assert_line 'ant.jpi'
  assert_line 'ant.jpi.pinned'
}

@test "plugins are installed with install-plugins.sh" {
  run docker build -t $SUT_IMAGE-install-plugins $BATS_TEST_DIRNAME/install-plugins
  assert_success
  # replace DOS line endings \r\n
  run bash -c "docker run -ti --rm $SUT_IMAGE-install-plugins ls --color=never -1 /var/jenkins_home/plugins | tr -d '\r'"
  assert_success
  assert_line 'maven-plugin.jpi'
  assert_line 'maven-plugin.jpi.pinned'
  assert_line 'ant.jpi'
  assert_line 'ant.jpi.pinned'
  assert_line 'credentials.jpi'
  assert_line 'credentials.jpi.pinned'
  assert_line 'mesos.jpi'
  assert_line 'mesos.jpi.pinned'
  refute_line 'metrics.jpi'
  refute_line 'metrics.jpi.pinned'
}

@test "clean test containers" {
    cleanup $SUT_CONTAINER
}

@test "plugins are getting upgraded but not downgraded" {
  run docker build -t $SUT_IMAGE-install-plugins $BATS_TEST_DIRNAME/install-plugins
  assert_success
  local work; work="$BATS_TEST_DIRNAME/upgrade-plugins/work"
  # Image contains maven-plugin 2.7.1 and ant-plugin 1.3
  run bash -c "docker run -ti -v $work:/var/jenkins_home --rm $SUT_IMAGE-install-plugins true"
  assert_success
  run bash -c "unzip -p $work/plugins/maven-plugin.jpi META-INF/MANIFEST.MF | tr -d '\r'"
  assert_line 'Plugin-Version: 2.7.1'
  run bash -c "unzip -p $work/plugins/ant.jpi META-INF/MANIFEST.MF | tr -d '\r'"
  assert_line 'Plugin-Version: 1.3'
  run docker build -t $SUT_IMAGE-upgrade-plugins $BATS_TEST_DIRNAME/upgrade-plugins
  assert_success
  # Images contains maven-plugin 2.13 and ant-plugin 1.2
  run bash -c "docker run -ti -v $work:/var/jenkins_home --rm $SUT_IMAGE-upgrade-plugins true"
  assert_success
  run bash -c "unzip -p $work/plugins/maven-plugin.jpi META-INF/MANIFEST.MF | tr -d '\r'"
  assert_success
  # Should be updated
  assert_line 'Plugin-Version: 2.13'
  run bash -c "unzip -p $work/plugins/ant.jpi META-INF/MANIFEST.MF | tr -d '\r'"
  # 1.2 is older than the existing 1.3, so keep 1.3
  assert_line 'Plugin-Version: 1.3'
}

@test "clean work directory" {
    run bash -c "rm -rf $BATS_TEST_DIRNAME/upgrade-plugins/work"
}

@test "do not upgrade if plugin has been manually updated" {
  run docker build -t $SUT_IMAGE-install-plugins $BATS_TEST_DIRNAME/install-plugins
  assert_success
  local work; work="$BATS_TEST_DIRNAME/upgrade-plugins/work"
  # Image contains maven-plugin 2.7.1 and ant-plugin 1.3
  run bash -c "docker run -ti -v $work:/var/jenkins_home --rm $SUT_IMAGE-install-plugins curl --connect-timeout 5 --retry 5 --retry-delay 0 --retry-max-time 60 -s -f -L https://updates.jenkins.io/download/plugins/maven-plugin/2.12.1/maven-plugin.hpi -o /var/jenkins_home/plugins/maven-plugin.jpi"
  assert_success
  run bash -c "unzip -p $work/plugins/maven-plugin.jpi META-INF/MANIFEST.MF | tr -d '\r'"
  assert_line 'Plugin-Version: 2.12.1'
  run docker build -t $SUT_IMAGE-upgrade-plugins $BATS_TEST_DIRNAME/upgrade-plugins
  assert_success
  # Images contains maven-plugin 2.13 and ant-plugin 1.2
  run bash -c "docker run -ti -v $work:/var/jenkins_home --rm $SUT_IMAGE-upgrade-plugins true"
  assert_success
  run bash -c "unzip -p $work/plugins/maven-plugin.jpi META-INF/MANIFEST.MF | tr -d '\r'"
  assert_success
  # Shouldn't be updated
  refute_line 'Plugin-Version: 2.13'
}

@test "clean work directory" {
    run bash -c "rm -rf $BATS_TEST_DIRNAME/upgrade-plugins/work"
}
