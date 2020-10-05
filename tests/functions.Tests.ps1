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

Describe "[$TEST_TAG] Check-VersionLessThan" {
  It 'exit codes work' {
    docker run --rm $SUT_IMAGE "exit -1"
    $LastExitCode | Should -Be -1
  }

  It 'has same version' {
    docker run --rm $SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '1.0' '1.0')) { exit 0 } else { exit -1 }" 
    $LastExitCode | Should -Be -1
  }

  It 'has right side greater' {
    docker run --rm $SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '1.0' '1.1')) { exit 0 } else { exit -1 }"
    $LastExitCode | Should -Be 0
  }

  It 'has left side greater' {
    docker run --rm $SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '1.1' '1.0')) { exit 0 } else { exit -1 }"
    $LastExitCode | Should -Be -1
  }

  It 'has left side non-final' {
    docker run --rm $SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '1.0-beta-1' '1.0')) { exit 0 } else { exit -1 }" 
    $LastExitCode | Should -Be 0
  }

  It 'has right side non-final' {
    docker run --rm $SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '1.0' '1.0-beta-1')) { exit 0 } else { exit -1 }"
    $LastExitCode | Should -Be -1
  }

  It 'has left alpha and right beta' {
    docker run --rm $SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '1.0-alpha-1' '1.0-beta-1')) { exit 0 } else { exit -1 }"
    $LastExitCode | Should -Be 0
  }

  It 'has left beta and right alpha' {
    docker run --rm $SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan '1.0-beta-1' '1.0-alpha-1')) { exit 0 } else { exit -1 }"
    $LastExitCode | Should -Be -1
  }

  It "has left 'latest' and right 1.0" {
    docker run --rm $SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan 'latest' '1.0')) { exit -1 } else { exit 0 }"
    $LastExitCode | Should -Be 0
  }

  It "has left 'latest' and right 'latest'" {
    docker run --rm $SUT_IMAGE "Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1 ; if(`$(Compare-VersionLessThan 'latest' 'latest')) { exit -1 } else { exit 0 }"
    $LastExitCode | Should -Be 0
  }
}

Describe "[$TEST_TAG] Copy-ReferenceFile" {
  It 'build test image' {
    $exitCode, $stdout, $stderr = Build-DockerChild $SUT_IMAGE $PSScriptRoot/functions
    $exitCode | Should -Be 0
  }

  It 'start container' {
    $exitCode, $stdout, $stderr = Run-Program 'docker' "run -d --name $SUT_CONTAINER -P $SUT_IMAGE"
    $exitCode | Should -Be 0
  }

  It 'wait for running' {
    # give time to eventually fail to initialize
    Start-Sleep -Seconds 5
    Retry-Command -RetryCount 3 -Delay 1 -ScriptBlock { docker inspect -f "{{.State.Running}}" $SUT_CONTAINER ; if($lastExitCode -ne 0) { throw('Docker inspect failed') } } -Verbose | Should -BeTrue
  }

  It 'is initialized' {
    Retry-Command -RetryCount 30 -Delay 5 -ScriptBlock { Test-Url $SUT_CONTAINER "/api/json" } -Verbose | Should -BeTrue
  }

  It 'check files in JENKINS_HOME' {
    $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $SUT_CONTAINER powershell -C `"Get-ChildItem `$env:JENKINS_HOME`" | Select-Object -Property 'Name'"
    $exitCode | Should -Be 0
    $stdout | Should -Match "pester"
    $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $SUT_CONTAINER powershell -C `"Get-ChildItem `$env:JENKINS_HOME/pester`" | Select-Object -Property 'Name'"
    $exitCode | Should -Be 0
    $stdout | Should -Match "test.override"
  }

  It 'cleanup container' {
    Cleanup $SUT_CONTAINER | Out-Null
  }
}