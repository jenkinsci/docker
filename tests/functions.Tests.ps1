Import-Module -DisableNameChecking -Force $PSScriptRoot/../jenkins-support.psm1
Import-Module -DisableNameChecking -Force $PSScriptRoot/test_helpers.psm1

$global:SUT_IMAGE=Get-SutImage
$global:SUT_CONTAINER=Get-SutImage
$global:TEST_TAG=$global:SUT_IMAGE.Replace('pester-jenkins-', '')

Describe "[functions > $global:TEST_TAG] build image" {
  BeforeEach {
    Push-Location -StackName 'jenkins' -Path "$PSScriptRoot/.."
  }

  It 'builds image' {
    $exitCode, $stdout, $stderr = Build-Docker $global:SUT_IMAGE
    $exitCode | Should -Be 0
  }

  AfterEach {
    Pop-Location -StackName 'jenkins'
  }
}

# Only test on Java 21, one JDK is enough to test all versions
Describe "[functions > $global:TEST_TAG] Check-VersionLessThan" -Skip:(-not $global:TEST_TAG.Contains('jdk21-')) {
  It 'exit codes work' {
    docker run --rm $global:SUT_IMAGE "exit -1"
    $LastExitCode | Should -Be -1
  }

  It 'has same version' {
    docker run --rm $global:SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '1.0' '1.0')) { exit 0 } else { exit -1 }"
    $LastExitCode | Should -Be -1
  }

  It 'has right side greater' {
    docker run --rm $global:SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '1.0' '1.1')) { exit 0 } else { exit -1 }"
    $LastExitCode | Should -Be 0
  }

  It 'has left side greater' {
    docker run --rm $global:SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '1.1' '1.0')) { exit 0 } else { exit -1 }"
    $LastExitCode | Should -Be -1
  }
  ## Real world examples from https://github.com/jenkinsci/docker/issues/1456
  It 'has left side greater (commons-lang3-api-plugin)' {
    docker run --rm $global:SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '3.12.0.0' '3.12.0-36.vd97de6465d5b_')) { exit 0 } else { exit -1 }"
    $LastExitCode | Should -Be 0
  }
  It 'has left side greater (map-db-plugin)' {
    docker run --rm $global:SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '1.0.9.0' '1.0.9-28.vf251ce40855d')) { exit 0 } else { exit -1 }"
    $LastExitCode | Should -Be 0
  }
  It 'has left side greater (role-strategy-plugin, security fix backport)' {
    docker run --rm $global:SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '587.v2872c41fa_e51' '587.588.v850a_20a_30162')) { exit 0 } else { exit -1 }"
    $LastExitCode | Should -Be 0
  }
  It 'has left side greater (workflow-cps-plugin, security fix backport)' {
    docker run --rm $global:SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '3894.vd0f0248b_a_fc4' '3894.3896.vca_2c931e7935')) { exit 0 } else { exit -1 }"
    $LastExitCode | Should -Be 0
  }
  It 'has left side greater (workflow-cps-plugin, security fix backport of an older release, published later than a newer normal release)' {
    docker run --rm $global:SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '4106.4108.v841a_e1819d4d' '4151.v5406e29e3c90')) { exit 0 } else { exit -1 }"
    $LastExitCode | Should -Be 0
  }
  ## Major version transitions
  It 'has right side greater (major version 9 vs 10)' {
    docker run --rm $global:SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '9.0' '10.0')) { exit 0 } else { exit -1 }"
    $LastExitCode | Should -Be 0
  }
  It 'has left side greater (major version 10 vs 9)' {
    docker run --rm $global:SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '10.0' '9.0')) { exit 0 } else { exit -1 }"
    $LastExitCode | Should -Be -1
  }
  ## https://github.com/jenkinsci/docker/issues/2328
  ## Reverse-direction cases: image is the 4-part backport / maintenance release, installed is the 3-part normal release.
  ## Copy-ReferenceFile calls Compare-VersionLessThan(image, container) at this site, so the workaround has to handle both argument orders.
  It 'has left side greater (workflow-cps-plugin, reverse-direction)' {
    docker run --rm $global:SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '3894.3896.vca_2c931e7935' '3894.vd0f0248b_a_fc4')) { exit 0 } else { exit -1 }"
    $LastExitCode | Should -Be -1
  }
  It 'has left side greater (github-branch-source-plugin, 1967.x security maintenance branch)' {
    docker run --rm $global:SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '1967.1969.v205fd594c821' '1967.vdea_d580c1a_b_a_')) { exit 0 } else { exit -1 }"
    $LastExitCode | Should -Be -1
  }
  It 'has left side greater (workflow-job-plugin, same shape)' {
    docker run --rm $global:SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '1571.1580.v18e46842c125' '1571.vb_423c255d6d9')) { exit 0 } else { exit -1 }"
    $LastExitCode | Should -Be -1
  }
  It 'has left side greater (role-strategy-plugin, reverse-direction)' {
    docker run --rm $global:SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '587.588.v850a_20a_30162' '587.v2872c41fa_e51')) { exit 0 } else { exit -1 }"
    $LastExitCode | Should -Be -1
  }
}

# Only test on Java 21, one JDK is enough to test all versions
Describe "[functions > $global:TEST_TAG] Copy-ReferenceFile" -Skip:(-not $global:TEST_TAG.Contains('jdk21-')) {
  It 'build test image' {
    $exitCode, $stdout, $stderr = Build-DockerChild $global:SUT_IMAGE $PSScriptRoot/functions
    $exitCode | Should -Be 0
  }

  It 'start container' {
    $exitCode, $stdout, $stderr = Run-Program 'docker' "run -d --name $global:SUT_CONTAINER -P $global:SUT_IMAGE"
    $exitCode | Should -Be 0
  }

  It 'wait for running' {
    # give time to eventually fail to initialize
    Start-Sleep -Seconds 5
    Retry-Command -RetryCount 3 -Delay 1 -ScriptBlock { docker inspect -f "{{.State.Running}}" $global:SUT_CONTAINER ; if($lastExitCode -ne 0) { throw('Docker inspect failed') } } -Verbose | Should -BeTrue
  }

  It 'is initialized' {
    Retry-Command -RetryCount 30 -Delay 5 -ScriptBlock { Test-Url $global:SUT_CONTAINER "/api/json" } -Verbose | Should -BeTrue
  }

  It 'check files in JENKINS_HOME' {
    $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:SUT_CONTAINER powershell -C `"Get-ChildItem `$env:JENKINS_HOME`" | Select-Object -Property 'Name'"
    $exitCode | Should -Be 0
    $stdout | Should -Match "pester"
    $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:SUT_CONTAINER powershell -C `"Get-ChildItem `$env:JENKINS_HOME/pester`" | Select-Object -Property 'Name'"
    $exitCode | Should -Be 0
    $stdout | Should -Match "test.override"
  }

  It 'substitute_env_vars replaces variable with env value' {
    $exitCode, $stdout, $stderr = Run-Program 'docker' "run --rm -e JENKINS_ENABLE_ENV_SUBST=true -e JENKINS_URL=http://prod.example.com $global:SUT_IMAGE powershell -C `"Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; `$tmp = New-TemporaryFile ; Set-Content -Path `$tmp -Value '<jenkinsUrl>`${JENKINS_URL:-http://localhost:8080/}</jenkinsUrl>' ; Invoke-EnvVarSubstitution `$tmp ; Get-Content `$tmp`""
    $exitCode | Should -Be 0
    $stdout | Should -Match 'http://prod.example.com'
  }

  It 'substitute_env_vars uses default when variable unset' {
    $exitCode, $stdout, $stderr = Run-Program 'docker' "run --rm -e JENKINS_ENABLE_ENV_SUBST=true $global:SUT_IMAGE powershell -C `"Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; `$tmp = New-TemporaryFile ; Set-Content -Path `$tmp -Value '<jenkinsUrl>`${JENKINS_URL:-http://localhost:8080/}</jenkinsUrl>' ; Invoke-EnvVarSubstitution `$tmp ; Get-Content `$tmp`""
    $exitCode | Should -Be 0
    $stdout | Should -Match 'http://localhost:8080/'
  }

  It 'copy_reference_file skips substitution when JENKINS_ENABLE_ENV_SUBST is unset' {
    $exitCode, $stdout, $stderr = Run-Program 'docker' "run --rm -e JENKINS_ENABLE_ENV_SUBST=false -e JENKINS_URL=http://prod.example.com $global:SUT_IMAGE powershell -C `"Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; `$tmp = New-TemporaryFile ; Set-Content -Path `$tmp -Value '<jenkinsUrl>`${JENKINS_URL:-http://localhost:8080/}</jenkinsUrl>' ; if((Get-EnvOrDefault 'JENKINS_ENABLE_ENV_SUBST' 'false') -eq 'true') { Invoke-EnvVarSubstitution `$tmp } ; Get-Content `$tmp`""
    $exitCode | Should -Be 0
    $stdout | Should -Match '\$\{JENKINS_URL:-http://localhost:8080/\}'
  }

  It 'cleanup container' {
    Cleanup $global:SUT_CONTAINER | Out-Null
  }
}
