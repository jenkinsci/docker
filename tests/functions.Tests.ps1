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

Describe 'Check-VersionLessThan' {
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
}