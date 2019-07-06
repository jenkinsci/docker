Import-Module -DisableNameChecking -Force $PSScriptRoot/test_helpers.psm1

$SUT_IMAGE=Get-SutImage

Import-Module -DisableNameChecking -Force $PSScriptRoot/../jenkins-support.psm1

Describe 'build image' {
  BeforeEach {
    Push-Location -StackName 'jenkins' -Path "$PSScriptRoot/.."    
  }

  It 'builds image' {
    $exitCode, $stdout, $stderr = Build-Docker -t $SUT_IMAGE . 
    $exitCode | Should -Be 0
  }

  AfterEach {
    Pop-Location -StackName 'jenkins'
  }
}

Describe 'plugins are installed with plugin-management-cli.jar' {
  It 'build child image' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins $PSScriptRoot/install-plugins
    $exitCode | Should -Be 0

    $stdout | Should -Not -Match 'Skipping already installed dependency'
    
    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run --rm $SUT_IMAGE-install-plugins gci C:/ProgramData/Jenkins/JenkinsHome/plugins"
    $exitCode | Should -Be 0

    $stdout | Should -Match 'maven-plugin.jpi'

    $stdout | Should -Match 'maven-plugin.jpi.pinned'
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
    $stdout | Should -Match 'javadoc.jpi'
    $stdout | Should -Match 'javadoc.jpi.pinned'
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

Describe 'plugins are installed with plugin-management-cli.jar from a plugins file' {
  It 'run test' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins $PSScriptRoot/install-plugins 
    $exitCode | Should -Be 0

    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins-pluginsfile $PSScriptRoot/install-plugins/pluginsfile 
    $exitCode | Should -Be 0

    $stdout | Should -Not -Match 'Skipping already installed dependency'
    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run --rm $SUT_IMAGE-install-plugins gci C:/ProgramData/Jenkins/JenkinsHome/plugins"
    $exitCode | Should -Be 0

    Write-Host "stdout = $stdout"
  }
  # assert_line 'maven-plugin.jpi'
  # assert_line 'maven-plugin.jpi.pinned'
  # assert_line 'ant.jpi'
  # assert_line 'ant.jpi.pinned'
  # assert_line 'credentials.jpi'
  # assert_line 'credentials.jpi.pinned'
  # assert_line 'mesos.jpi'
  # assert_line 'mesos.jpi.pinned'
  # # optional dependencies
  # refute_line 'metrics.jpi'
  # refute_line 'metrics.jpi.pinned'
  # # plugins bundled but under detached-plugins, so need to be installed
  # assert_line 'javadoc.jpi'
  # assert_line 'javadoc.jpi.pinned'
  # assert_line 'mailer.jpi'
  # assert_line 'mailer.jpi.pinned'
  # assert_line 'git.jpi'
  # assert_line 'git.jpi.pinned'
  # assert_line 'filesystem_scm.jpi'
  # assert_line 'filesystem_scm.jpi.pinned'
}

Describe 'plugins are installed with plugin-management-cli.jar even when already exist' {
  It 'run test' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins $PSScriptRoot/install-plugins 
    $exitCode | Should -Be 0
  
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins-update $PSScriptRoot/install-plugins/update --no-cache 
    $exitCode | Should -Be 0

    Write-Host "stdout = $stdout"
    
    $stdout | Should -Match 'Skipping already installed dependency javadoc'
    $stdout | Should -Match 'Using provided plugin: ant'

    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run --rm $SUT_IMAGE-install-plugins-update Expand-Archive C:/ProgramData/Jenkins/JenkinsHome/plugins/maven-plugin.jpi ; cat META-INF/MANIFEST.MF"
    $exitCode | Should -Be 0
    $stdout | Should -Match 'Plugin-Version: 2.13'
  }
}

if(Test-Path $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE) {
  rm -Recurse -Force $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE | Out-Null
}

Describe 'plugins are getting upgraded but not downgraded' {
  # Initial execution
  It 'run test' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins $PSScriptRoot/install-plugins 
    $exitCode | Should -Be 0
  }

  # $work="$PSScriptRoot/upgrade-plugins/work-${SUT_IMAGE}"
  # mkdir -p $work
  # Image contains maven-plugin 2.7.1 and ant-plugin 1.3
  # run bash -c "docker run -u $UID -v $work:/var/jenkins_home --rm $SUT_IMAGE-install-plugins true"
  # assert_success
  # run unzip_manifest maven-plugin.jpi $work
  # assert_line 'Plugin-Version: 2.7.1'
  # run unzip_manifest ant.jpi $work
  # assert_line 'Plugin-Version: 1.3'

  # # Upgrade to new image with different plugins
  # run docker_build_child $SUT_IMAGE-upgrade-plugins $PSScriptRoot/upgrade-plugins
  # assert_success
  # # Images contains maven-plugin 2.13 and ant-plugin 1.2
  # run bash -c "docker run -u $UID -v $work:/var/jenkins_home --rm $SUT_IMAGE-upgrade-plugins true"
  # assert_success
  # run unzip_manifest maven-plugin.jpi $work
  # assert_success
  # # Should be updated
  # assert_line 'Plugin-Version: 2.13'
  # run unzip_manifest ant.jpi $work
  # # 1.2 is older than the existing 1.3, so keep 1.3
  # assert_line 'Plugin-Version: 1.3'
}

if(Test-Path $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE) {
  rm -Recurse -Force $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE | Out-Null
}

Describe 'do not upgrade if plugin has been manually updated' {
  It 'run test' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins $PSScriptRoot/install-plugins 
    $exitCode | Should -Be 0
  }

  # local work; work="$PSScriptRoot/upgrade-plugins/work-${SUT_IMAGE}"
  # mkdir -p $work
  # # Image contains maven-plugin 2.7.1 and ant-plugin 1.3
  # run bash -c "docker run -u $UID -v $work:/var/jenkins_home --rm $SUT_IMAGE-install-plugins curl --connect-timeout 20 --retry 5 --retry-delay 0 --retry-max-time 60 -s -f -L https://updates.jenkins.io/download/plugins/maven-plugin/2.12.1/maven-plugin.hpi -o /var/jenkins_home/plugins/maven-plugin.jpi"
  # assert_success
  # run unzip_manifest maven-plugin.jpi $work
  # assert_line 'Plugin-Version: 2.12.1'
  # run docker_build_child $SUT_IMAGE-upgrade-plugins $PSScriptRoot/upgrade-plugins
  # assert_success
  # # Images contains maven-plugin 2.13 and ant-plugin 1.2
  # run bash -c "docker run -u $UID -v $work:/var/jenkins_home --rm $SUT_IMAGE-upgrade-plugins true"
  # assert_success
  # # maven shouldn't be upgraded
  # run unzip_manifest maven-plugin.jpi $work
  # assert_success
  # assert_line 'Plugin-Version: 2.12.1'
  # refute_line 'Plugin-Version: 2.13'
  # # ant shouldn't be downgraded
  # run unzip_manifest ant.jpi $work
  # assert_success
  # assert_line 'Plugin-Version: 1.3'
  # refute_line 'Plugin-Version: 1.2'
}

if(Test-Path $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE) {
  rm -Recurse -Force $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE | Out-Null
}

Describe 'upgrade plugin even if it has been manually updated when PLUGINS_FORCE_UPGRADE=true' {
  It 'run test' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins $PSScriptRoot/install-plugins 
    $exitCode | Should -Be 0
  }
  # local work; work="$PSScriptRoot/upgrade-plugins/work-${SUT_IMAGE}"
  # mkdir -p $work
  # # Image contains maven-plugin 2.7.1 and ant-plugin 1.3
  # run bash -c "docker run -u $UID -v $work:/var/jenkins_home --rm $SUT_IMAGE-install-plugins curl --connect-timeout 20 --retry 5 --retry-delay 0 --retry-max-time 60 -s -f -L https://updates.jenkins.io/download/plugins/maven-plugin/2.12.1/maven-plugin.hpi -o /var/jenkins_home/plugins/maven-plugin.jpi"
  # assert_success
  # run unzip_manifest maven-plugin.jpi $work
  # assert_line 'Plugin-Version: 2.12.1'
  # run docker_build_child $SUT_IMAGE-upgrade-plugins $PSScriptRoot/upgrade-plugins
  # assert_success
  # # Images contains maven-plugin 2.13 and ant-plugin 1.2
  # run bash -c "docker run -e PLUGINS_FORCE_UPGRADE=true -u $UID -v $work:/var/jenkins_home --rm $SUT_IMAGE-upgrade-plugins true"
  # assert_success
  # # maven should be upgraded
  # run unzip_manifest maven-plugin.jpi $work
  # assert_success
  # refute_line 'Plugin-Version: 2.12.1'
  # assert_line 'Plugin-Version: 2.13'
  # # ant shouldn't be downgraded
  # run unzip_manifest ant.jpi $work
  # assert_success
  # assert_line 'Plugin-Version: 1.3'
  # refute_line 'Plugin-Version: 1.2'
}

if(Test-Path $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE) {
  rm -Recurse -Force $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE | Out-Null
}

Describe 'plugins are installed with plugin-management-cli.jar and no war' {
  It 'run test' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins-no-war $PSScriptRoot/install-plugins/no-war 
    $exitCode | Should -Be 0
  }
}
