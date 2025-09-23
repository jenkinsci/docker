Import-Module -DisableNameChecking -Force $PSScriptRoot/../jenkins-support.psm1
Import-Module -DisableNameChecking -Force $PSScriptRoot/test_helpers.psm1

$global:SUT_IMAGE=Get-SutImage
$global:SUT_CONTAINER=Get-SutImage
$global:TEST_TAG=$global:SUT_IMAGE.Replace('pester-jenkins-', '')

Describe "[runtime > $global:TEST_TAG] build image" {
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

Describe "[runtime > $global:TEST_TAG] cleanup container" {
  It 'cleanup' {
    Cleanup $global:SUT_CONTAINER | Out-Null
  }
}

# Only test on Java 21, one JDK is enough to test all versions
Describe "[runtime > $global:TEST_TAG] test multiple JENKINS_OPTS" -Skip:(-not $global:TEST_TAG.Contains('jdk21-')) {
  It '"--help --version" should return the version, not the help' {
    # need the last line of output
    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run --rm -e JENKINS_OPTS=`"--help --version`" --name $global:SUT_CONTAINER -P $global:SUT_IMAGE"
    $exitCode | Should -Be 0
    $stdout -split '`n' | %{$_.Trim()} | Select-Object -Last 1 | Should -Be $env:JENKINS_VERSION
  }
}

# Only test on Java 21, one JDK is enough to test all versions
Describe "[runtime > $global:TEST_TAG] test jenkins arguments" -Skip:(-not $global:TEST_TAG.Contains('jdk21-')) {
  It 'running --help --version should return the version, not the help' {
    # need the last line of output
    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run --rm --name $global:SUT_CONTAINER -P $global:SUT_IMAGE --help --version"
    $exitCode | Should -Be 0
    $stdout -split '`n' | %{$_.Trim()} | Select-Object -Last 1 | Should -Be $env:JENKINS_VERSION
  }

  It 'version in docker metadata' {
    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "inspect -f `"{{index .Config.Labels \`"org.opencontainers.image.version\`"}}`" $global:SUT_IMAGE"
    $exitCode | Should -Be 0
    $stdout.Trim() | Should -Match $env:JENKINS_VERSION
  }

  It 'commit SHA in docker metadata' {
    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "inspect -f `"{{index .Config.Labels \`"org.opencontainers.image.revision\`"}}`" $global:SUT_IMAGE"
    $exitCode | Should -Be 0
    $stdout.Trim() | Should -Match $env:COMMIT_SHA
  }
}

# Only test on Java 21, one JDK is enough to test all versions
Describe "[runtime > $global:TEST_TAG] passing JVM parameters" -Skip:(-not $global:TEST_TAG.Contains('jdk21-')) {
  BeforeAll {
    $tzSetting = '-Duser.timezone=Europe/Madrid'
    $tzRegex = [regex]::Escape("Europe/Madrid")

    $cspSetting = @'
-Dhudson.model.DirectoryBrowserSupport.CSP=\"default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';\"
'@
    $cspRegex = [regex]::Escape("default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';")

    function Start-With-Opts() {
      Param (
        [string] $JAVA_OPTS,
        [string] $JENKINS_JAVA_OPTS
      )

      $cmd = "docker --% run -d --name $global:SUT_CONTAINER -P"
      if ($JAVA_OPTS.length -gt 0) {
        $cmd += " -e JAVA_OPTS=`"$JAVA_OPTS`""
      }
      if ($JENKINS_JAVA_OPTS.length -gt 0) {
        $cmd += " -e JENKINS_JAVA_OPTS=`"$JENKINS_JAVA_OPTS`""
      }
      $cmd += " $global:SUT_IMAGE"

      Invoke-Expression $cmd
      $lastExitCode | Should -Be 0

      # give time to eventually fail to initialize
      Start-Sleep -Seconds 5
      Retry-Command -RetryCount 3 -Delay 1 -ScriptBlock { docker inspect -f "{{.State.Running}}" $global:SUT_CONTAINER ; if($lastExitCode -ne 0) { throw('Docker inspect failed') } } -Verbose | Should -BeTrue

      # it takes a while for jenkins to be up enough
      Retry-Command -RetryCount 30 -Delay 5 -ScriptBlock { Test-Url $global:SUT_CONTAINER "/api/json" } -Verbose | Should -BeTrue
    }

    function Get-Csp-Value() {
      return (Run-In-Script-Console $global:SUT_CONTAINER "System.getProperty('hudson.model.DirectoryBrowserSupport.CSP')")
    }

    function Get-Timezone-Value() {
      return (Run-In-Script-Console $global:SUT_CONTAINER "System.getProperty('user.timezone')")
    }
  }

  It 'passes JAVA_OPTS' {
    Start-With-Opts -JAVA_OPTS "$tzSetting $cspSetting"

    Get-Csp-Value | Should -Match $cspRegex
    Get-Timezone-Value | Should -Match $tzRegex
  }

  It 'passes JENKINS_JAVA_OPTS' {
    Start-With-Opts -JENKINS_JAVA_OPTS "$tzSetting $cspSetting"

    Get-Csp-Value | Should -Match $cspRegex
    Get-Timezone-Value | Should -Match $tzRegex
  }

  It 'JENKINS_JAVA_OPTS overrides JAVA_OPTS' {
    Start-With-Opts -JAVA_OPTS "$tzSetting -Dhudson.model.DirectoryBrowserSupport.CSP=\`"default-src 'self';\`"" -JENKINS_JAVA_OPTS "$cspSetting"

    Get-Csp-Value | Should -Match $cspRegex
    Get-Timezone-Value | Should -Match $tzRegex
  }

  AfterEach {
    Cleanup $global:SUT_CONTAINER | Out-Null
  }
}
