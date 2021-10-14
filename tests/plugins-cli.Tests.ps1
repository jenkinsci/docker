Import-Module -DisableNameChecking -Force $PSScriptRoot/../jenkins-support.psm1
Import-Module -DisableNameChecking -Force $PSScriptRoot/test_helpers.psm1
$SUT_IMAGE=Get-SutImage
$SUT_CONTAINER=Get-SutImage
$TEST_TAG=$SUT_IMAGE.Replace('pester-jenkins-', '')

$work = Join-Path $PSScriptRoot "upgrade-plugins/work-${SUT_IMAGE}"

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
  It 'builds child image' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-plugins-cli $PSScriptRoot/plugins-cli
    $exitCode | Should -Be 0
    $stdout | Should -Not -Match "Skipping already installed dependency"
  }

  It 'has correct plugins' {
    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run --rm $SUT_IMAGE-plugins-cli gci `$env:JENKINS_HOME/plugins | Select-Object -Property Name"
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
  It 'builds child image' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-plugins-cli-ref $PSScriptRoot/plugins-cli/ref
    $exitCode | Should -Be 0
    $stdout | Should -Not -Match "Skipping already installed dependency"
  }

  It 'has correct plugins' {
    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run --rm $SUT_IMAGE-plugins-cli-ref -e REF=C:/ProgramData/JenkinsDir/Reference gci C:/ProgramData/JenkinsDir/Reference"
    $exitCode | Should -Be 0

    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run --rm $SUT_IMAGE-plugins-cli gci `$env:JENKINS_HOME/plugins | Select-Object -Property Name"
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

Describe "[$TEST_TAG] plugins are installed with jenkins-plugin-cli from a plugins file" {
  It 'builds child image' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-plugins-cli $PSScriptRoot/plugins-cli
    $exitCode | Should -Be 0
  }

  It 'builds grandchild image' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-plugins-cli-pluginsfile $PSScriptRoot/plugins-cli/pluginsfile
    $exitCode | Should -Be 0
    $stdout | Should -Not -Match "Skipping already installed dependency"
  }

  It 'has correct plugins' {
    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run --rm $SUT_IMAGE-plugins-cli gci `$env:JENKINS_HOME/plugins | Select-Object -Property Name"
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
  }
}

Describe "[$TEST_TAG] plugins are installed with jenkins-plugin-cli even when already exist" {
  It 'builds child image' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-plugins-cli $PSScriptRoot/plugins-cli
    $exitCode | Should -Be 0
  }

  It 'builds grandchild image' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-plugins-cli-update $PSScriptRoot/plugins-cli/update --no-cache
    $exitCode | Should -Be 0
  }
    
  It 'has the correct version of junit' {
    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run --rm $SUT_IMAGE-plugins-cli-update Import-Module -Force -DisableNameChecking C:/ProgramData/Jenkins/jenkins-support.psm1 ; Expand-Zip `$env:JENKINS_HOME/plugins/junit.jpi 'META-INF/MANIFEST.MF'"
    $exitCode | Should -Be 0
    $stdout | Should -Match 'Plugin-Version: 1.28'
  }
}

Describe "[$TEST_TAG] clean work directory" {
  It 'cleanup' {
    if(Test-Path $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE) {
      Remove-Item -Recurse -Force $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE | Out-Null
    }
  }
}

Describe "[$TEST_TAG] plugins are getting upgraded but not downgraded" {
  It 'builds child image' {
    # Initial execution
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-plugins-cli $PSScriptRoot/plugins-cli
    $exitCode | Should -Be 0
  }

  It 'has correct version of junit and ant plugins' {
    if(-not (Test-Path $work)) {
      New-Item -ItemType Directory -Path $work
    }

    # Image contains junit 1.6 and ant-plugin 1.3
    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run -v `"${work}:C:\ProgramData\Jenkins\JenkinsHome`" --rm $SUT_IMAGE-plugins-cli exit 0"
    $exitCode | Should -Be 0

    $exitCode, $stdout, $stderr = Unzip-Manifest $SUT_IMAGE "junit.jpi" $work
    $exitCode | Should -Be 0
    $stdout | Should -Match 'Plugin-Version: 1.6'
    $exitCode, $stdout, $stderr = Unzip-Manifest $SUT_IMAGE "ant.jpi" $work
    $exitCode | Should -Be 0
    $stdout | Should -Match 'Plugin-Version: 1.3'
  }

  It 'upgrades plugins' {
    # Upgrade to new image with different plugins
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-upgrade-plugins $PSScriptRoot/upgrade-plugins
    $exitCode | Should -Be 0
    # Images contains junit 1.28 and ant-plugin 1.2
    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run -v `"${work}:C:\ProgramData\Jenkins\JenkinsHome`" --rm $SUT_IMAGE-upgrade-plugins exit 0"
    $exitCode | Should -Be 0
    $exitCode, $stdout, $stderr = Unzip-Manifest $SUT_IMAGE 'junit.jpi' $work
    $exitCode | Should -Be 0
    # Should be updated
    $stdout | Should -Match 'Plugin-Version: 1.28'
    $exitCode, $stdout, $stderr = Unzip-Manifest $SUT_IMAGE 'ant.jpi' $work
    $exitCode | Should -Be 0
    # 1.2 is older than the existing 1.3, so keep 1.3
    $stdout | Should -Match 'Plugin-Version: 1.3'
  }
}

Describe "[$TEST_TAG] clean work directory" {
  It 'cleanup' {
    if(Test-Path $work) {
      Remove-Item -Recurse -Force $work | Out-Null
    }
  }
}

Describe "[$TEST_TAG] do not upgrade if plugin has been manually updated" {
  
  It 'builds child image' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-plugins-cli $PSScriptRoot/plugins-cli
    $exitCode | Should -Be 0
  }

  It 'updates plugin manually and then via plugin-cli' {
    if(-not (Test-Path $work)) {
      New-Item -ItemType Directory -Path $work
    }
    
    # Image contains junit 1.8 and ant-plugin 1.3
    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run -v `"${work}:C:\ProgramData\Jenkins\JenkinsHome`" --rm $SUT_IMAGE-plugins-cli curl.exe --connect-timeout 20 --retry 5 --retry-delay 0 --retry-max-time 60 -s -f -L https://updates.jenkins.io/download/plugins/junit/1.8/junit.hpi -o C:/ProgramData/Jenkins/JenkinsHome/plugins/junit.jpi"
    $exitCode | Should -Be 0
    $exitCode, $stdout, $stderr = Unzip-Manifest $SUT_IMAGE 'junit.jpi' $work
    $exitCode | Should -Be 0
    $stdout | Should -Match 'Plugin-Version: 1.8'
    $exitCode, $stdout, $stderr = Unzip-Manifest $SUT_IMAGE 'ant.jpi' $work
    $exitCode | Should -Be 0
    $stdout | Should -Match 'Plugin-Version: 1.3'

    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-upgrade-plugins $PSScriptRoot/upgrade-plugins
    $exitCode | Should -Be 0

    # Images contains junit 1.28 and ant-plugin 1.2
    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run -v `"${work}:C:\ProgramData\Jenkins\JenkinsHome`" --rm $SUT_IMAGE-upgrade-plugins exit 0"
    $exitCode | Should -Be 0
    # junit shouldn't be upgraded
    $exitCode, $stdout, $stderr = Unzip-Manifest $SUT_IMAGE 'junit.jpi' $work
    $exitCode | Should -Be 0
    $stdout | Should -Match 'Plugin-Version: 1.8'
    $stdout | Should -Not -Match 'Plugin-Version: 1.28'
    # ant shouldn't be downgraded
    $exitCode, $stdout, $stderr = Unzip-Manifest $SUT_IMAGE 'ant.jpi' $work
    $exitCode | Should -Be 0
    $stdout | Should -Match 'Plugin-Version: 1.3'
    $stdout | Should -Not -Match 'Plugin-Version: 1.2'
  }
}

Describe "[$TEST_TAG] clean work directory" {
  It 'cleanup' {
    if(Test-Path $work) {
      Remove-Item -Recurse -Force $work | Out-Null
    }
  }
}

Describe "[$TEST_TAG] upgrade plugin even if it has been manually updated when PLUGINS_FORCE_UPGRADE=true" {
  It 'builds child image' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-plugins-cli $PSScriptRoot/plugins-cli
    $exitCode | Should -Be 0
  }

  It 'upgrades plugins' {
    if(-not (Test-Path $work)) {
      New-Item -ItemType Directory -Path $work
    }
    
    # Image contains junit 1.6 and ant-plugin 1.3
    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run -v `"${work}:C:\ProgramData\Jenkins\JenkinsHome`" --rm $SUT_IMAGE-plugins-cli curl.exe --connect-timeout 20 --retry 5 --retry-delay 0 --retry-max-time 60 -s -f -L https://updates.jenkins.io/download/plugins/junit/1.8/junit.hpi -o C:/ProgramData/Jenkins/JenkinsHome/plugins/junit.jpi"
    $exitCode | Should -Be 0

    $exitCode, $stdout, $stderr = Unzip-Manifest $SUT_IMAGE 'junit.jpi' $work
    $exitCode | Should -Be 0
    $stdout | Should -Match 'Plugin-Version: 1.8'
    
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-upgrade-plugins $PSScriptRoot/upgrade-plugins
    $exitCode | Should -Be 0
    
    # Images contains junit 1.28 and ant-plugin 1.2
    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run -e PLUGINS_FORCE_UPGRADE=true -v ${work}:C:/ProgramData/Jenkins/JenkinsHome --rm $SUT_IMAGE-upgrade-plugins exit 0"
    $exitCode | Should -Be 0
    # junit should be upgraded
    $exitCode, $stdout, $stderr = Unzip-Manifest $SUT_IMAGE 'junit.jpi' $work
    $exitCode | Should -Be 0
    $stdout | Should -Not -Match 'Plugin-Version: 1.8'
    $stdout | Should -Match 'Plugin-Version: 1.28'
    # ant shouldn't be downgraded
    $exitCode, $stdout, $stderr = Unzip-Manifest $SUT_IMAGE 'ant.jpi' $work
    $exitCode | Should -Be 0
    $stdout | Should -Match 'Plugin-Version: 1.3'
    $stdout | Should -Not -Match 'Plugin-Version: 1.2'
  }
}

Describe "[$TEST_TAG] clean work directory" {
  It 'cleanup' {
    if(Test-Path $work) {
      Remove-Item -Recurse -Force $work | Out-Null
    }
  }
}

Describe "[$TEST_TAG] plugins are installed with jenkins-plugin-cli and no war" {
  It 'builds child image' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-plugins-cli-no-war $PSScriptRoot/plugins-cli/no-war
    $exitCode | Should -Be 0
  }
}

Describe "[$TEST_TAG] Use a custom jenkins.war" {
  It 'builds child image' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-plugins-cli-custom-war $PSScriptRoot/plugins-cli/custom-war --no-cache
    $exitCode | Should -Be 0
  }
}

Describe "[$TEST_TAG] clean work directory" {
  It 'cleanup' {
    if(Test-Path $work) {
      Remove-Item -Recurse -Force $work | Out-Null
    }
  }
}
