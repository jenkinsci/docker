#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load test_helpers

SUT_IMAGE=$(sut_image)
SUT_DESCRIPTION=$(echo $SUT_IMAGE | sed -e 's/bats-jenkins-//g')

@test "[${SUT_DESCRIPTION}] build image" {
  cd $BATS_TEST_DIRNAME/..
  docker_build -t $SUT_IMAGE .
}

@test "[${SUT_DESCRIPTION}] plugins are installed with jenkins-plugin-cli" {
  run docker_build_child $SUT_IMAGE-plugins-cli $BATS_TEST_DIRNAME/plugins-cli
  assert_success
  refute_line --partial 'Skipping already installed dependency'
  # replace DOS line endings \r\n
  run bash -c "docker run --rm $SUT_IMAGE-plugins-cli ls --color=never -1 /var/jenkins_home/plugins | tr -d '\r'"
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
  run docker_build_child $SUT_IMAGE-plugins-cli-ref $BATS_TEST_DIRNAME/plugins-cli/ref
  assert_success
  refute_line --partial 'Skipping already installed dependency'
  docker run --rm $SUT_IMAGE-plugins-cli-ref -e REF=/var/lib/jenkins/ref ls --color=never -1 /var/lib/jenkins/ref | tr -d '\r'

  # replace DOS line endings \r\n
  run bash -c "docker run --rm $SUT_IMAGE-plugins-cli ls --color=never -1 /var/jenkins_home/plugins | tr -d '\r'"
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

@test "[${SUT_DESCRIPTION}] plugins are installed with jenkins-plugin-cli from a plugins file" {
  run docker_build_child $SUT_IMAGE-plugins-cli $BATS_TEST_DIRNAME/plugins-cli
  assert_success
  run docker_build_child $SUT_IMAGE-plugins-cli-pluginsfile $BATS_TEST_DIRNAME/plugins-cli/pluginsfile
  assert_success
  refute_line --partial 'Skipping already installed dependency'
  # replace DOS line endings \r\n
  run bash -c "docker run --rm $SUT_IMAGE-plugins-cli ls --color=never -1 /var/jenkins_home/plugins | tr -d '\r'"
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

@test "[${SUT_DESCRIPTION}] plugins are installed with jenkins-plugin-cli even when already exist" {
  run docker_build_child $SUT_IMAGE-plugins-cli $BATS_TEST_DIRNAME/plugins-cli
  assert_success
  run docker_build_child $SUT_IMAGE-plugins-cli-update $BATS_TEST_DIRNAME/plugins-cli/update --no-cache
  assert_success
  # replace DOS line endings \r\n
  run bash -c "docker run --rm $SUT_IMAGE-plugins-cli-update unzip -p /var/jenkins_home/plugins/junit.jpi META-INF/MANIFEST.MF | tr -d '\r'"
  assert_success
  assert_line 'Plugin-Version: 1.28'
}

@test "[${SUT_DESCRIPTION}] clean work directory" {
  run bash -c "ls -la $BATS_TEST_DIRNAME/upgrade-plugins ; rm -rf $BATS_TEST_DIRNAME/upgrade-plugins/work-${SUT_IMAGE}"
  assert_success
}

@test "[${SUT_DESCRIPTION}] plugins are getting upgraded but not downgraded" {
  # Initial execution
  run docker_build_child $SUT_IMAGE-plugins-cli $BATS_TEST_DIRNAME/plugins-cli
  assert_success
  local work; work="$BATS_TEST_DIRNAME/upgrade-plugins/work-${SUT_IMAGE}"
  mkdir -p $work
  # Image contains junit 1.6 and ant-plugin 1.3
  run bash -c "docker run -u $UID -v $work:/var/jenkins_home --rm $SUT_IMAGE-plugins-cli true"
  assert_success
  run unzip_manifest junit.jpi $work
  assert_line 'Plugin-Version: 1.6'
  run unzip_manifest ant.jpi $work
  assert_line 'Plugin-Version: 1.3'

  # Upgrade to new image with different plugins
  run docker_build_child $SUT_IMAGE-upgrade-plugins $BATS_TEST_DIRNAME/upgrade-plugins
  assert_success
  # Images contains junit 1.28 and ant-plugin 1.2
  run bash -c "docker run -u $UID -v $work:/var/jenkins_home --rm $SUT_IMAGE-upgrade-plugins true"
  assert_success
  run unzip_manifest junit.jpi $work
  assert_success
  # Should be updated
  assert_line 'Plugin-Version: 1.28'
  run unzip_manifest ant.jpi $work
  # 1.2 is older than the existing 1.3, so keep 1.3
  assert_line 'Plugin-Version: 1.3'
}

@test "[${SUT_DESCRIPTION}] clean work directory" {
  run bash -c "ls -la $BATS_TEST_DIRNAME/upgrade-plugins ; rm -rf $BATS_TEST_DIRNAME/upgrade-plugins/work-${SUT_IMAGE}"
  assert_success
}

@test "[${SUT_DESCRIPTION}] do not upgrade if plugin has been manually updated" {
  run docker_build_child $SUT_IMAGE-plugins-cli $BATS_TEST_DIRNAME/plugins-cli
  assert_success
  local work; work="$BATS_TEST_DIRNAME/upgrade-plugins/work-${SUT_IMAGE}"
  mkdir -p $work
  # Image contains junit 1.8 and ant-plugin 1.3
  run bash -c "docker run -u $UID -v $work:/var/jenkins_home --rm $SUT_IMAGE-plugins-cli curl --connect-timeout 20 --retry 5 --retry-delay 0 --retry-max-time 60 -s -f -L https://updates.jenkins.io/download/plugins/junit/1.8/junit.hpi -o /var/jenkins_home/plugins/junit.jpi"
  assert_success
  run unzip_manifest junit.jpi $work
  assert_line 'Plugin-Version: 1.8'
  run docker_build_child $SUT_IMAGE-upgrade-plugins $BATS_TEST_DIRNAME/upgrade-plugins
  assert_success
  # Images contains junit 1.28 and ant-plugin 1.2
  run bash -c "docker run -u $UID -v $work:/var/jenkins_home --rm $SUT_IMAGE-upgrade-plugins true"
  assert_success
  # junit shouldn't be upgraded
  run unzip_manifest junit.jpi $work
  assert_success
  assert_line 'Plugin-Version: 1.8'
  refute_line 'Plugin-Version: 1.28'
  # ant shouldn't be downgraded
  run unzip_manifest ant.jpi $work
  assert_success
  assert_line 'Plugin-Version: 1.3'
  refute_line 'Plugin-Version: 1.2'
}

@test "[${SUT_DESCRIPTION}] clean work directory" {
  run bash -c "ls -la $BATS_TEST_DIRNAME/upgrade-plugins ; rm -rf $BATS_TEST_DIRNAME/upgrade-plugins/work-${SUT_IMAGE}"
  assert_success
}

@test "[${SUT_DESCRIPTION}] upgrade plugin even if it has been manually updated when PLUGINS_FORCE_UPGRADE=true" {
  run docker_build_child $SUT_IMAGE-plugins-cli $BATS_TEST_DIRNAME/plugins-cli
  assert_success
  local work; work="$BATS_TEST_DIRNAME/upgrade-plugins/work-${SUT_IMAGE}"
  mkdir -p $work
  # Image contains junit 1.6 and ant-plugin 1.3
  run bash -c "docker run -u $UID -v $work:/var/jenkins_home --rm $SUT_IMAGE-plugins-cli curl --connect-timeout 20 --retry 5 --retry-delay 0 --retry-max-time 60 -s -f -L https://updates.jenkins.io/download/plugins/junit/1.8/junit.hpi -o /var/jenkins_home/plugins/junit.jpi"
  assert_success
  run unzip_manifest junit.jpi $work
  assert_line 'Plugin-Version: 1.8'
  run docker_build_child $SUT_IMAGE-upgrade-plugins $BATS_TEST_DIRNAME/upgrade-plugins
  assert_success
  # Images contains junit 1.28 and ant-plugin 1.2
  run bash -c "docker run -e PLUGINS_FORCE_UPGRADE=true -u $UID -v $work:/var/jenkins_home --rm $SUT_IMAGE-upgrade-plugins true"
  assert_success
  # junit should be upgraded
  run unzip_manifest junit.jpi $work
  assert_success
  refute_line 'Plugin-Version: 1.8'
  assert_line 'Plugin-Version: 1.28'
  # ant shouldn't be downgraded
  run unzip_manifest ant.jpi $work
  assert_success
  assert_line 'Plugin-Version: 1.3'
  refute_line 'Plugin-Version: 1.2'
}

@test "[${SUT_DESCRIPTION}] clean work directory" {
  run bash -c "ls -la $BATS_TEST_DIRNAME/upgrade-plugins ; rm -rf $BATS_TEST_DIRNAME/upgrade-plugins/work-${SUT_IMAGE}"
  assert_success
}

@test "[${SUT_DESCRIPTION}] plugins are installed with jenkins-plugin-cli and no war" {
  run docker_build_child $SUT_IMAGE-plugins-cli-no-war $BATS_TEST_DIRNAME/plugins-cli/no-war
  assert_success
}

@test "[${SUT_DESCRIPTION}] Use a custom jenkins.war" {
  run docker_build_child $SUT_IMAGE-plugins-cli-custom-war $BATS_TEST_DIRNAME/plugins-cli/custom-war --no-cache
  assert_success
}

@test "[${SUT_DESCRIPTION}] clean work directory" {
  run bash -c "ls -la $BATS_TEST_DIRNAME/upgrade-plugins ; rm -rf $BATS_TEST_DIRNAME/upgrade-plugins/work-${SUT_IMAGE}"
  assert_success
}
