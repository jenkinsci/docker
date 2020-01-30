Import-Module -DisableNameChecking -Force $PSScriptRoot/test_helpers.psm1

$SUT_IMAGE=Get-SutImage
$TEST_TAG=$SUT_IMAGE.Replace('pester-jenkins-', '')

Import-Module -DisableNameChecking -Force $PSScriptRoot/../jenkins-support.psm1

Describe "[$TEST_TAG] build image" {
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

Describe "[$TEST_TAG] plugins are installed with install-plugins.ps1" {
  It 'build child image' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins $PSScriptRoot/install-plugins
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

Describe "[$TEST_TAG] plugins are installed with install-plugins.ps1 with non-default REF" {
  It 'run test' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins-ref $PSScriptRoot/install-plugins/ref
    $exitCode | Should -Be 0

    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run -e REF=C:/ProgramData/JenkinsDir/Reference --rm $SUT_IMAGE-install-plugins-ref gci C:/ProgramData/JenkinsDir/Reference"

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

Describe "[$TEST_TAG] plugins are installed with install-plugins.ps1 from a plugins file" {
  It 'run test' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins $PSScriptRoot/install-plugins
    $exitCode | Should -Be 0
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins-pluginsfile $PSScriptRoot/install-plugins/pluginsfile
    $exitCode | Should -Be 0

    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run --rm $SUT_IMAGE-install-plugins gci `$env:JENKINS_HOME/plugins | Select-Object -Property Name"
    $exitCode | Should -Be 0

    $stdout | Should -Match  'junit.jpi'
    $stdout | Should -Match  'junit.jpi.pinned'
    $stdout | Should -Match  'ant.jpi'
    $stdout | Should -Match  'ant.jpi.pinned'
    $stdout | Should -Match  'credentials.jpi'
    $stdout | Should -Match  'credentials.jpi.pinned'
    $stdout | Should -Match  'mesos.jpi'
    $stdout | Should -Match  'mesos.jpi.pinned'
    # optional dependencies
    $stdout | Should -Not -Match 'metrics.jpi'
    $stdout | Should -Not -Match 'metrics.jpi.pinned'
    # plugins bundled but under detached-plugins, so need to be installed
    $stdout | Should -Match  'mailer.jpi'
    $stdout | Should -Match  'mailer.jpi.pinned'
    $stdout | Should -Match  'git.jpi'
    $stdout | Should -Match  'git.jpi.pinned'
    $stdout | Should -Match  'filesystem_scm.jpi'
    $stdout | Should -Match  'filesystem_scm.jpi.pinned'
  }
}

Describe "[$TEST_TAG] plugins are installed with install-plugins.ps1 even when already exist" {
  It 'run test' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins $PSScriptRoot/install-plugins
    $exitCode | Should -Be 0
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins-update $PSScriptRoot/install-plugins/update --no-cache
    $exitCode | Should -Be 0

    $stdout | Should -Match "Skipping already installed dependency workflow-step-api"
    $stdout | Should -Match "Using provided plugin: ant"

    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run --rm $SUT_IMAGE-install-plugins-update Import-Module -Force -DisableNameChecking C:/ProgramData/Jenkins/jenkins-support.psm1 ; Expand-Zip `$env:JENKINS_HOME/plugins/junit.jpi 'META-INF/MANIFEST.MF'"
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
  It 'run test' {
    # Initial execution
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins $PSScriptRoot/install-plugins
    $exitCode | Should -Be 0

    $work="$PSScriptRoot/upgrade-plugins/work-${SUT_IMAGE}"
    New-Item -ItemType Directory -Path $work
    # Image contains junit 1.6 and ant-plugin 1.3
    $exitCode, $stdout, $stderr = Run-Program "docker.exe" "run -v ${work}:C:/ProgramData/Jenkins/JenkinsHome --rm $SUT_IMAGE-install-plugins exit 0"
    $exitCode | Should -Be 0

    $exitCode, $stdout, $stderr = Unzip-Manifest "$SUT_IMAGE-install-plugins" "junit.jpi" $work
    $exitCode | Should -Be 0
    $stdout | Should -Match  'Plugin-Version: 1.6'

    $exitCode, $stdout, $stderr = Unzip-Manifest "$SUT_IMAGE-install-plugins" "ant.jpi" $work
    $exitCode | Should -Be 0
    $stdout | Should -Match  'Plugin-Version: 1.3'

    # Upgrade to new image with different plugins
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-upgrade-plugins $PSScriptRoot/upgrade-plugins
    $exitCode | Should -Be 0
    # Images contains junit 1.28 and ant-plugin 1.2
    $exitCode, $stdout, $stderr = Run-Program "docker.exe" "run -v ${work}:C:/ProgramData/Jenkins/JenkinsHome --rm $SUT_IMAGE-upgrade-plugins exit 0"
    $exitCode | Should -Be 0
    $exitCode, $stdout, $stderr = Unzip-Manifest "$SUT_IMAGE-upgrade-plugins" "junit.jpi" $work
    $exitCode | Should -Be 0
    # Should be updated
    $stdout | Should -Match  'Plugin-Version: 1.28'
    $exitCode, $stdout, $stderr = Unzip-Manifest "$SUT_IMAGE-upgrade-plugins" "ant.jpi" $work
    # 1.2 is older than the existing 1.3, so keep 1.3
    $stdout | Should -Match  'Plugin-Version: 1.3'
  }
}

Describe "[$TEST_TAG] clean work directory" {
  It 'cleanup' {
    if(Test-Path $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE) {
      Remove-Item -Recurse -Force $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE | Out-Null
    }
  }
}

Describe "[$TEST_TAG] do not upgrade if plugin has been manually updated" {
  It 'run test' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins $PSScriptRoot/install-plugins
    $exitCode | Should -Be 0

    $work = "$PSScriptRoot/upgrade-plugins/work-${SUT_IMAGE}"
    New-Item -ItemType Directory -Path $work
    # Image contains junit 1.6 and ant-plugin 1.3
    $exitCode, $stdout, $stderr = Run-Program "docker.exe" "run -v ${work}:C:/ProgramData/Jenkins/JenkinsHome --rm $SUT_IMAGE-install-plugins Invoke-WebRequest -UseBasicParsing -Uri 'https://updates.jenkins.io/download/plugins/junit/1.8/junit.hpi' -OutFile 'C:/ProgramData/Jenkins/JenkinsHome/plugins/junit.jpi' -TimeoutSec 60"
    $exitCode | Should -Be 0

    $exitCode, $stdout, $stderr = Unzip-Manifest "$SUT_IMAGE-install-plugins" "junit.jpi" $work
    $exitCode | Should -Be 0
    $stdout | Should -Match  'Plugin-Version: 1.8'

    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-upgrade-plugins $PSScriptRoot/upgrade-plugins
    $exitCode | Should -Be 0
    # Images contains junit 1.28 and ant-plugin 1.2
    $exitCode, $stdout, $stderr = Run-Program "docker.exe" "run -v ${work}:C:/ProgramData/Jenkins/JenkinsHome --rm $SUT_IMAGE-upgrade-plugins exit 0"
    $exitCode | Should -Be 0

    # junit shouldn't be upgraded
    $exitCode, $stdout, $stderr = Unzip-Manifest "$SUT_IMAGE-upgrade-plugins" "junit.jpi" $work
    $exitCode | Should -Be 0
    $stdout | Should -Match  'Plugin-Version: 1.8'
    $stdout | Should -Not -Match 'Plugin-Version: 1.28'
    # ant shouldn't be downgraded
    $exitCode, $stdout, $stderr = Unzip-Manifest "$SUT_IMAGE-upgrade-plugins" "ant.jpi" $work
    $exitCode | Should -Be 0
    $stdout | Should -Match  'Plugin-Version: 1.3'
    $stdout | Should -Not -Match 'Plugin-Version: 1.2'
  }
}

Describe "[$TEST_TAG] clean work directory" {
  It 'cleanup' {
    if(Test-Path $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE) {
      Remove-Item -Recurse -Force $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE | Out-Null
    }
  }
}

Describe "[$TEST_TAG] upgrade plugin even if it has been manually updated when PLUGINS_FORCE_UPGRADE=true" {
  It 'run test' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins $PSScriptRoot/install-plugins
    $exitCode | Should -Be 0

    $work = "$PSScriptRoot/upgrade-plugins/work-${SUT_IMAGE}"
    New-Item -ItemType Directory -Force $work
    # Image contains junit 1.6 and ant-plugin 1.3
    $exitCode, $stdout, $stderr = Run-Program "docker.exe" "run -v ${work}:C:/ProgramData/Jenkins/JenkinsHome --rm $SUT_IMAGE-install-plugins Invoke-WebRequest -Uri 'https://updates.jenkins.io/download/plugins/junit/1.8/junit.hpi' -OutFile 'C:/ProgramData/Jenkins/JenkinsHome/plugins/junit.jpi' -TimeoutSec 60"
    $exitCode | Should -Be 0
    $exitCode, $stdout, $stderr = Unzip-Manifest "$SUT_IMAGE-install-plugins" "junit.jpi" $work
    $stdout | Should -Match 'Plugin-Version: 1.8'

    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-upgrade-plugins $PSScriptRoot/upgrade-plugins
    $exitCode | Should -Be 0
    # Images contains junit 1.28 and ant-plugin 1.2
    $exitCode, $stdout, $stderr = Run-Program "docker.exe" "run -e PLUGINS_FORCE_UPGRADE=true -v ${work}:C:/ProgramData/Jenkins/JenkinsHome --rm $SUT_IMAGE-upgrade-plugins exit 0"
    $exitCode | Should -Be 0

    # junit should be upgraded
    $exitCode, $stdout, $stderr = Unzip-Manifest "$SUT_IMAGE-upgrade-plugins" "junit.jpi" $work
    $exitCode | Should -Be 0
    $stdout | Should -Not -Match 'Plugin-Version: 1.8'
    $stdout | Should -Match  'Plugin-Version: 1.28'
    # ant shouldn't be downgraded
    $exitCode, $stdout, $stderr = Unzip-Manifest "$SUT_IMAGE-upgrade-plugins" "ant.jpi" $work
    $exitCode | Should -Be 0
    $stdout | Should -Match  'Plugin-Version: 1.3'
    $stdout | Should -Not -Match 'Plugin-Version: 1.2'
  }
}

Describe "[$TEST_TAG] clean work directory" {
  It 'cleanup' {
    if(Test-Path $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE) {
      Remove-Item -Recurse -Force $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE | Out-Null
    }
  }
}

Describe "[$TEST_TAG] plugins are installed with install-plugins.ps1 and no war" {
  It 'run test' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins-no-war $PSScriptRoot/install-plugins/no-war
    $exitCode | Should -Be 0
  }
}

Describe "[$TEST_TAG] Use a custom jenkins.war" {
  It 'run test' {
    # Build the image using the right Dockerfile setting a new war with JENKINS_WAR env and with a weird plugin inside
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins-custom-war $PSScriptRoot/install-plugins/custom-war --no-cache
    $exitCode | Should -Be 0
    # Assert the weird plugin is there
    $stdout | Should -Match 'my-happy-plugin\s+1\.1'
  }
}

Describe "[$TEST_TAG] clean work directory" {
  It 'cleanup' {
    if(Test-Path $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE) {
      Remove-Item -Recurse -Force $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE | Out-Null
    }
  }
}