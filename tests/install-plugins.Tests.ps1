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

    # $stdout | Should -Not -Match 'Skipping already installed dependency'

    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run --rm $SUT_IMAGE-install-plugins gci `$env:JENKINS_HOME/plugins | Select-Object -Property Name"
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
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins-pluginsfile $PSScriptRoot/install-plugins/pluginsfile 
    $exitCode | Should -Be 0

    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run --rm $SUT_IMAGE-install-plugins-pluginsfile gci `$env:JENKINS_HOME/plugins | Select-Object -Property Name"
    $exitCode | Should -Be 0

    $stdout | Should -Match  'maven-plugin.jpi'
    $stdout | Should -Match  'maven-plugin.jpi.pinned'
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
    $stdout | Should -Match  'javadoc.jpi'
    $stdout | Should -Match  'javadoc.jpi.pinned'
    $stdout | Should -Match  'mailer.jpi'
    $stdout | Should -Match  'mailer.jpi.pinned'
    $stdout | Should -Match  'git.jpi'
    $stdout | Should -Match  'git.jpi.pinned'
    $stdout | Should -Match  'filesystem_scm.jpi'
    $stdout | Should -Match  'filesystem_scm.jpi.pinned'
  }
}

Describe 'plugins are installed with plugin-management-cli.jar even when already exist' {
  It 'run test' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins-update $PSScriptRoot/install-plugins/update --no-cache 
    $exitCode | Should -Be 0

    $stdout | Should -Match 'Skipping already installed dependency javadoc'
    $stdout | Should -Match 'ant already installed, skipping'

    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run --rm $SUT_IMAGE-install-plugins-update Import-Module -Force -DisableNameChecking C:/ProgramData/Jenkins/jenkins-support.psm1 ; Unzip-File `$env:JENKINS_HOME/plugins/maven-plugin.jpi 'META-INF/MANIFEST.MF'"
    $exitCode | Should -Be 0
    $stdout | Should -Match 'Plugin-Version: 2.13'
  }
}

Describe 'clean work directory' {
  It 'cleanup' {
    if(Test-Path $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE) {
      Remove-Item -Recurse -Force $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE | Out-Null
    }
  }
}

Describe 'plugins are getting upgraded but not downgraded' {
  # Initial execution
  It 'run test' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins $PSScriptRoot/install-plugins
    $exitCode | Should -Be 0

    $work="$PSScriptRoot/upgrade-plugins/work-${SUT_IMAGE}"
    New-Item -ItemType Directory -Path $work
    # Image contains maven-plugin 2.7.1 and ant-plugin 1.3
    $exitCode, $stdout, $stderr = Run-Program "docker.exe" "run -v ${work}:C:/ProgramData/Jenkins/JenkinsHome --rm $SUT_IMAGE-install-plugins exit 0"
    $exitCode | Should -Be 0
    
    $exitCode, $stdout, $stderr = Unzip-Manifest "$SUT_IMAGE-install-plugins" "maven-plugin.jpi" $work
    $exitCode | Should -Be 0
    $stdout | Should -Match  'Plugin-Version: 2.7.1'
    
    $exitCode, $stdout, $stderr = Unzip-Manifest "$SUT_IMAGE-install-plugins" "ant.jpi" $work
    $exitCode | Should -Be 0
    $stdout | Should -Match  'Plugin-Version: 1.3'

    # Upgrade to new image with different plugins
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-upgrade-plugins $PSScriptRoot/upgrade-plugins
    $exitCode | Should -Be 0
    # Images contains maven-plugin 2.13 and ant-plugin 1.2
    $exitCode, $stdout, $stderr = Run-Program "docker.exe" "run -v ${work}:C:/ProgramData/Jenkins/JenkinsHome --rm $SUT_IMAGE-upgrade-plugins exit 0"
    $exitCode | Should -Be 0
    $exitCode, $stdout, $stderr = Unzip-Manifest "$SUT_IMAGE-upgrade-plugins" "maven-plugin.jpi" $work
    $exitCode | Should -Be 0
    # Should be updated
    $stdout | Should -Match  'Plugin-Version: 2.13'
    $exitCode, $stdout, $stderr = Unzip-Manifest "$SUT_IMAGE-upgrade-plugins" "ant.jpi" $work
    # 1.2 is older than the existing 1.3, so keep 1.3
    $stdout | Should -Match  'Plugin-Version: 1.3'
  }
}

Describe 'clean work directory' {
  It 'cleanup' {
    if(Test-Path $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE) {
      Remove-Item -Recurse -Force $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE | Out-Null
    }
  }
}

Describe 'do not upgrade if plugin has been manually updated' {
  It 'run test' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins $PSScriptRoot/install-plugins 
    $exitCode | Should -Be 0

    $work = "$PSScriptRoot/upgrade-plugins/work-${SUT_IMAGE}"
    New-Item -ItemType Directory -Path $work
    # Image contains maven-plugin 2.7.1 and ant-plugin 1.3
    $exitCode, $stdout, $stderr = Run-Program "docker.exe" "run -v ${work}:C:/ProgramData/Jenkins/JenkinsHome --rm $SUT_IMAGE-install-plugins Invoke-WebRequest -UseBasicParsing -Uri 'https://updates.jenkins.io/download/plugins/maven-plugin/2.12.1/maven-plugin.hpi' -OutFile 'C:/ProgramData/Jenkins/JenkinsHome/plugins/maven-plugin.jpi' -TimeoutSec 60"
    $exitCode | Should -Be 0

    $exitCode, $stdout, $stderr = Unzip-Manifest "$SUT_IMAGE-install-plugins" "maven-plugin.jpi" $work
    $exitCode | Should -Be 0
    $stdout | Should -Match  'Plugin-Version: 2.12.1'

    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-upgrade-plugins $PSScriptRoot/upgrade-plugins
    $exitCode | Should -Be 0
    # Images contains maven-plugin 2.13 and ant-plugin 1.2
    $exitCode, $stdout, $stderr = Run-Program "docker.exe" "run -v ${work}:C:/ProgramData/Jenkins/JenkinsHome --rm $SUT_IMAGE-upgrade-plugins exit 0"
    $exitCode | Should -Be 0

    # maven shouldn't be upgraded
    $exitCode, $stdout, $stderr = Unzip-Manifest "$SUT_IMAGE-upgrade-plugins" "maven-plugin.jpi" $work
    $exitCode | Should -Be 0
    $stdout | Should -Match  'Plugin-Version: 2.12.1'
    $stdout | Should -Not -Match 'Plugin-Version: 2.13'
    # ant shouldn't be downgraded
    $exitCode, $stdout, $stderr = Unzip-Manifest "$SUT_IMAGE-upgrade-plugins" "ant.jpi" $work
    $exitCode | Should -Be 0  
    $stdout | Should -Match  'Plugin-Version: 1.3'
    $stdout | Should -Not -Match 'Plugin-Version: 1.2'
  }
}

Describe 'clean work directory' {
  It 'cleanup' {
    if(Test-Path $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE) {
      Remove-Item -Recurse -Force $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE | Out-Null
    }
  }
}

Describe 'upgrade plugin even if it has been manually updated when PLUGINS_FORCE_UPGRADE=true' {
  It 'run test' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins $PSScriptRoot/install-plugins 
    $exitCode | Should -Be 0
  
    $work = "$PSScriptRoot/upgrade-plugins/work-${SUT_IMAGE}"
    New-Item -ItemType Directory -Force $work
    # Image contains maven-plugin 2.7.1 and ant-plugin 1.3
    $exitCode, $stdout, $stderr = Run-Program "docker.exe" "run -v ${work}:C:/ProgramData/Jenkins/JenkinsHome --rm $SUT_IMAGE-install-plugins Invoke-WebRequest -Uri 'https://updates.jenkins.io/download/plugins/maven-plugin/2.12.1/maven-plugin.hpi' -OutFile 'C:/ProgramData/Jenkins/JenkinsHome/plugins/maven-plugin.jpi' -TimeoutSec 60"
    $exitCode | Should -Be 0
    $exitCode, $stdout, $stderr = Unzip-Manifest "$SUT_IMAGE-install-plugins" "maven-plugin.jpi" $work
    $stdout | Should -Match 'Plugin-Version: 2.12.1'
    
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-upgrade-plugins $PSScriptRoot/upgrade-plugins
    $exitCode | Should -Be 0
    # Images contains maven-plugin 2.13 and ant-plugin 1.2
    $exitCode, $stdout, $stderr = Run-Program "docker.exe" "run -e PLUGINS_FORCE_UPGRADE=true -v ${work}:C:/ProgramData/Jenkins/JenkinsHome --rm $SUT_IMAGE-upgrade-plugins exit 0"
    $exitCode | Should -Be 0

    # maven should be upgraded
    $exitCode, $stdout, $stderr = Unzip-Manifest "$SUT_IMAGE-upgrade-plugins" "maven-plugin.jpi" $work
    $exitCode | Should -Be 0
    $stdout | Should -Not -Match 'Plugin-Version: 2.12.1'
    $stdout | Should -Match  'Plugin-Version: 2.13'
    # ant shouldn't be downgraded
    $exitCode, $stdout, $stderr = Unzip-Manifest "$SUT_IMAGE-upgrade-plugins" "ant.jpi" $work
    $exitCode | Should -Be 0
    $stdout | Should -Match  'Plugin-Version: 1.3'
    $stdout | Should -Not -Match 'Plugin-Version: 1.2'
  }
}

Describe 'clean work directory' {
  It 'cleanup' {
    if(Test-Path $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE) {
      Remove-Item -Recurse -Force $PSScriptRoot/upgrade-plugins/work-$SUT_IMAGE | Out-Null
    }
  }
}

Describe 'plugins are installed with plugin-management-cli.jar and no war' {
  It 'run test' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE-install-plugins-no-war $PSScriptRoot/install-plugins/no-war 
    $exitCode | Should -Be 0
  }
}
