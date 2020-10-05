Import-Module -DisableNameChecking -Force $PSScriptRoot/../jenkins-support.psm1
Import-Module -DisableNameChecking -Force $PSScriptRoot/test_helpers.psm1
$SUT_IMAGE=Get-SutImage
$SUT_CONTAINER=Get-SutImage
$TEST_TAG=$SUT_IMAGE.Replace('pester-jenkins-', '')

Describe "[$TEST_TAG] build image" {
  BeforeEach {
    Push-Location -StackName 'jenkins' -Path "$PSScriptRoot/.."
  }

  It 'builds image' {
    $exitCode, $stdout, $stderr = Build-Docker -t $SUT_IMAGE
    $exitCode | Should -Be 0
  }

  AfterEach {
    Pop-Location -StackName 'jenkins'
  }
}

Describe "[$TEST_TAG] cleanup container" {
  It 'cleanup' {
    Cleanup $SUT_CONTAINER | Out-Null
  }
}

Describe "[$TEST_TAG] plugins are installed with jenkins-plugin-cli" {
  It 'build child image' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins-plugins-cli $PSScriptRoot/install-plugins-plugins-cli
    $exitCode | Should -Be 0

    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run --rm $SUT_IMAGE-install-plugins gci `$env:JENKINS_HOME/plugins | Select-Object -Property Name"
    $exitCode | Should -Be 0

    $stdout | Should -Match 'junit.jpi'
    $stdout | Should -Match 'junit.jpi.pinned'
    $stdout | Should -Match 'ant.jpi'
    $stdout | Should -Match 'ant.jpi.pinned'
    $stdout | Should -Match 'credentials.jpi'
    $stdout | Should -Match 'credentials.jpi.pinned'
    $stdout | Should -Match 'mesos.jpi'
    $stdout | Should -Match 'mesos.jpi.pinned'
    # optional dependencies
    $stdout | Should -Not -Match 'metrics.jpi'
    $stdout | Should -Not -Match 'metrics.jpi.pinned'
    # plugins bundled but under detached-plugins, so need to be installed
    $stdout | Should -Match 'mailer.jpi'
    $stdout | Should -Match 'mailer.jpi.pinned'
    $stdout | Should -Match 'git.jpi'
    $stdout | Should -Match 'git.jpi.pinned'
    $stdout | Should -Match 'filesystem_scm.jpi'
    $stdout | Should -Match 'filesystem_scm.jpi.pinned'
    $stdout | Should -Match 'docker-plugin.jpi'
    $stdout | Should -Match 'docker-plugin.jpi.pinned'
  }
}

Describe "[$TEST_TAG] plugins are installed with jenkins-plugin-cli with non-default REF" {
  $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins-plugins-cli-ref $PSScriptRoot/install-plugins-plugins-cli/ref
  $exitCode | Should -Be 0
  Write-Host $stdout
  Write-Host $stderr

  $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run --rm $SUT_IMAGE-install-plugins-plugins-cli-ref gci `$env:JENKINS_HOME/plugins | Select-Object -Property Name"
  $exitCode | Should -Be 0
  Write-Host $stdout
  Write-Host $stderr

  $stdout | Should -Match 'junit.jpi'
  $stdout | Should -Match 'junit.jpi.pinned'
  $stdout | Should -Match 'ant.jpi'
  $stdout | Should -Match 'ant.jpi.pinned'
  $stdout | Should -Match 'credentials.jpi'
  $stdout | Should -Match 'credentials.jpi.pinned'
  $stdout | Should -Match 'mesos.jpi'
  $stdout | Should -Match 'mesos.jpi.pinned'
  # optional dependencies
  $stdout | Should -Not -Match 'metrics.jpi'
  $stdout | Should -Not -Match 'metrics.jpi.pinned'
  # plugins bundled but under detached-plugins, so need to be installed
  $stdout | Should -Match 'mailer.jpi'
  $stdout | Should -Match 'mailer.jpi.pinned'
  $stdout | Should -Match 'git.jpi'
  $stdout | Should -Match 'git.jpi.pinned'
  $stdout | Should -Match 'filesystem_scm.jpi'
  $stdout | Should -Match 'filesystem_scm.jpi.pinned'
  $stdout | Should -Match 'docker-plugin.jpi'
  $stdout | Should -Match 'docker-plugin.jpi.pinned'
}

@test "plugins are installed with jenkins-plugin-cli from a plugins file" {
  run docker_build_child $SUT_IMAGE-install-plugins $BATS_TEST_DIRNAME/install-plugins
  assert_success
  run docker_build_child $SUT_IMAGE-install-plugins-pluginsfile $BATS_TEST_DIRNAME/install-plugins/pluginsfile
  assert_success
  $stdout | Should -Not -Match --partial 'Skipping already installed dependency'
  # replace DOS line endings \r\n
  run bash -c "docker run --rm $SUT_IMAGE-install-plugins ls --color=never -1 /var/jenkins_home/plugins | tr -d '\r'"
  assert_success
  $stdout | Should -Match 'junit.jpi'
  $stdout | Should -Match 'junit.jpi.pinned'
  $stdout | Should -Match 'ant.jpi'
  $stdout | Should -Match 'ant.jpi.pinned'
  $stdout | Should -Match 'credentials.jpi'
  $stdout | Should -Match 'credentials.jpi.pinned'
  $stdout | Should -Match 'mesos.jpi'
  $stdout | Should -Match 'mesos.jpi.pinned'
  # optional dependencies
  $stdout | Should -Not -Match 'metrics.jpi'
  $stdout | Should -Not -Match 'metrics.jpi.pinned'
  # plugins bundled but under detached-plugins, so need to be installed
  $stdout | Should -Match 'mailer.jpi'
  $stdout | Should -Match 'mailer.jpi.pinned'
  $stdout | Should -Match 'git.jpi'
  $stdout | Should -Match 'git.jpi.pinned'
  $stdout | Should -Match 'filesystem_scm.jpi'
  $stdout | Should -Match 'filesystem_scm.jpi.pinned'
}

@test "plugins are installed with jenkins-plugin-cli even when already exist" {
  run docker_build_child $SUT_IMAGE-install-plugins $BATS_TEST_DIRNAME/install-plugins
  assert_success
  run docker_build_child $SUT_IMAGE-install-plugins-update $BATS_TEST_DIRNAME/install-plugins/update --no-cache
  assert_success
  $stdout | Should -Match --partial 'Skipping already installed dependency workflow-step-api'
  $stdout | Should -Match "Using provided plugin: ant"
  # replace DOS line endings \r\n
  run bash -c "docker run --rm $SUT_IMAGE-install-plugins-update unzip -p /var/jenkins_home/plugins/junit.jpi META-INF/MANIFEST.MF | tr -d '\r'"
  assert_success
  $stdout | Should -Match 'Plugin-Version: 1.28'
}

@test "clean work directory" {
  run bash -c "ls -la $BATS_TEST_DIRNAME/upgrade-plugins ; rm -rf $BATS_TEST_DIRNAME/upgrade-plugins/work-${SUT_IMAGE}"
  assert_success
}

@test "plugins are getting upgraded but not downgraded" {
  # Initial execution
  run docker_build_child $SUT_IMAGE-install-plugins $BATS_TEST_DIRNAME/install-plugins
  assert_success
  local work; work="$BATS_TEST_DIRNAME/upgrade-plugins/work-${SUT_IMAGE}"
  mkdir -p $work
  # Image contains junit 1.6 and ant-plugin 1.3
  run bash -c "docker run -u $UID -v $work:/var/jenkins_home --rm $SUT_IMAGE-install-plugins true"
  assert_success
  run unzip_manifest junit.jpi $work
  $stdout | Should -Match 'Plugin-Version: 1.6'
  run unzip_manifest ant.jpi $work
  $stdout | Should -Match 'Plugin-Version: 1.3'

  # Upgrade to new image with different plugins
  run docker_build_child $SUT_IMAGE-upgrade-plugins $BATS_TEST_DIRNAME/upgrade-plugins
  assert_success
  # Images contains junit 1.28 and ant-plugin 1.2
  run bash -c "docker run -u $UID -v $work:/var/jenkins_home --rm $SUT_IMAGE-upgrade-plugins true"
  assert_success
  run unzip_manifest junit.jpi $work
  assert_success
  # Should be updated
  $stdout | Should -Match 'Plugin-Version: 1.28'
  run unzip_manifest ant.jpi $work
  # 1.2 is older than the existing 1.3, so keep 1.3
  $stdout | Should -Match 'Plugin-Version: 1.3'
}

@test "clean work directory" {
  run bash -c "ls -la $BATS_TEST_DIRNAME/upgrade-plugins ; rm -rf $BATS_TEST_DIRNAME/upgrade-plugins/work-${SUT_IMAGE}"
  assert_success
}

@test "do not upgrade if plugin has been manually updated" {
  run docker_build_child $SUT_IMAGE-install-plugins $BATS_TEST_DIRNAME/install-plugins
  assert_success
  local work; work="$BATS_TEST_DIRNAME/upgrade-plugins/work-${SUT_IMAGE}"
  mkdir -p $work
  # Image contains junit 1.6 and ant-plugin 1.3
  run bash -c "docker run -u $UID -v $work:/var/jenkins_home --rm $SUT_IMAGE-install-plugins curl --connect-timeout 20 --retry 5 --retry-delay 0 --retry-max-time 60 -s -f -L https://updates.jenkins.io/download/plugins/junit/1.8/junit.hpi -o /var/jenkins_home/plugins/junit.jpi"
  assert_success
  run unzip_manifest junit.jpi $work
  $stdout | Should -Match 'Plugin-Version: 1.8'
  run docker_build_child $SUT_IMAGE-upgrade-plugins $BATS_TEST_DIRNAME/upgrade-plugins
  assert_success
  # Images contains junit 1.28 and ant-plugin 1.2
  run bash -c "docker run -u $UID -v $work:/var/jenkins_home --rm $SUT_IMAGE-upgrade-plugins true"
  assert_success
  # junit shouldn't be upgraded
  run unzip_manifest junit.jpi $work
  assert_success
  $stdout | Should -Match 'Plugin-Version: 1.8'
  $stdout | Should -Not -Match 'Plugin-Version: 1.28'
  # ant shouldn't be downgraded
  run unzip_manifest ant.jpi $work
  assert_success
  $stdout | Should -Match 'Plugin-Version: 1.3'
  $stdout | Should -Not -Match 'Plugin-Version: 1.2'
}

@test "clean work directory" {
  run bash -c "ls -la $BATS_TEST_DIRNAME/upgrade-plugins ; rm -rf $BATS_TEST_DIRNAME/upgrade-plugins/work-${SUT_IMAGE}"
  assert_success
}

@test "upgrade plugin even if it has been manually updated when PLUGINS_FORCE_UPGRADE=true" {
  run docker_build_child $SUT_IMAGE-install-plugins $BATS_TEST_DIRNAME/install-plugins
  assert_success
  local work; work="$BATS_TEST_DIRNAME/upgrade-plugins/work-${SUT_IMAGE}"
  mkdir -p $work
  # Image contains junit 1.6 and ant-plugin 1.3
  run bash -c "docker run -u $UID -v $work:/var/jenkins_home --rm $SUT_IMAGE-install-plugins curl --connect-timeout 20 --retry 5 --retry-delay 0 --retry-max-time 60 -s -f -L https://updates.jenkins.io/download/plugins/junit/1.8/junit.hpi -o /var/jenkins_home/plugins/junit.jpi"
  assert_success
  run unzip_manifest junit.jpi $work
  $stdout | Should -Match 'Plugin-Version: 1.8'
  run docker_build_child $SUT_IMAGE-upgrade-plugins $BATS_TEST_DIRNAME/upgrade-plugins
  assert_success
  # Images contains junit 1.28 and ant-plugin 1.2
  run bash -c "docker run -e PLUGINS_FORCE_UPGRADE=true -u $UID -v $work:/var/jenkins_home --rm $SUT_IMAGE-upgrade-plugins true"
  assert_success
  # junit should be upgraded
  run unzip_manifest junit.jpi $work
  assert_success
  $stdout | Should -Not -Match 'Plugin-Version: 1.8'
  $stdout | Should -Match 'Plugin-Version: 1.28'
  # ant shouldn't be downgraded
  run unzip_manifest ant.jpi $work
  assert_success
  $stdout | Should -Match 'Plugin-Version: 1.3'
  $stdout | Should -Not -Match 'Plugin-Version: 1.2'
}

@test "clean work directory" {
  run bash -c "ls -la $BATS_TEST_DIRNAME/upgrade-plugins ; rm -rf $BATS_TEST_DIRNAME/upgrade-plugins/work-${SUT_IMAGE}"
  assert_success
}

@test "plugins are installed with jenkins-plugin-cli and no war" {
  run docker_build_child $SUT_IMAGE-install-plugins-no-war $BATS_TEST_DIRNAME/install-plugins/no-war
  assert_success
}

@test "Use a custom jenkins.war" {
  # Build the image using the right Dockerfile setting a new war with JENKINS_WAR env and with a weird plugin inside
  run docker_build_child $SUT_IMAGE-install-plugins-custom-war $BATS_TEST_DIRNAME/install-plugins/custom-war --no-cache
  assert_success
  # Assert the weird plugin is there
  assert_output --partial 'my-happy-plugin:1.1'
}

Describe "[$TEST_TAG] clean work directory" {
  It 'cleanup' {
    if(Test-Path $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE) {
      Remove-Item -Recurse -Force $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE | Out-Null
    }
  }
}