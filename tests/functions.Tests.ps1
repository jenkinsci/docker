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

  It 'has left side non-final' {
    docker run --rm $global:SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '1.0-beta-1' '1.0')) { exit 0 } else { exit -1 }" 
    $LastExitCode | Should -Be 0
  }

  It 'has right side non-final' {
    docker run --rm $global:SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '1.0' '1.0-beta-1')) { exit 0 } else { exit -1 }"
    $LastExitCode | Should -Be -1
  }

  It 'has left alpha and right beta' {
    docker run --rm $global:SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '1.0-alpha-1' '1.0-beta-1')) { exit 0 } else { exit -1 }"
    $LastExitCode | Should -Be 0
  }

  It 'has left beta and right alpha' {
    docker run --rm $global:SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '1.0-beta-1' '1.0-alpha-1')) { exit 0 } else { exit -1 }"
    $LastExitCode | Should -Be -1
  }

  It "has left 'latest' and right 1.0" {
    docker run --rm $global:SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan 'latest' '1.0')) { exit -1 } else { exit 0 }"
    $LastExitCode | Should -Be 0
  }

  It "has left 'latest' and right 'latest'" {
    docker run --rm $global:SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan 'latest' 'latest')) { exit -1 } else { exit 0 }"
    $LastExitCode | Should -Be 0
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

  It 'cleanup container' {
    Cleanup $global:SUT_CONTAINER | Out-Null
  }
}
