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

Describe "[$TEST_TAG] test multiple JENKINS_OPTS" {
  It '"--help --version" should return the version, not the help' {
    $folder = Get-EnvOrDefault 'FOLDER' ''
    $version=Get-Content $(Join-Path $folder 'Dockerfile') | Select-String -Pattern 'ENV JENKINS_VERSION.*' | ForEach-Object {$_ -replace '.*:-(.*)}','$1'} | Select-Object -First 1
    # need the last line of output
    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run --rm -e JENKINS_OPTS=`"--help --version`" --name $SUT_CONTAINER -P $SUT_IMAGE"
    $exitCode | Should -Be 0
    $stdout -split '`n' | %{$_.Trim()} | Select-Object -Last 1 | Should -Be $version
  }
}

Describe "[$TEST_TAG] test jenkins arguments" {
  BeforeEach {
    $folder = Get-EnvOrDefault 'FOLDER' ''
    $version=Get-Content $(Join-Path $folder 'Dockerfile') | Select-String -Pattern 'ENV JENKINS_VERSION.*' | %{$_ -replace '.*:-(.*)}','$1'} | Select-Object -First 1
    $revision=Get-Content $(Join-Path $folder 'Dockerfile') | Select-String -Pattern 'ENV COMMIT_SHA.*' | %{$_ -replace '.*:-(.*)}','$1'} | Select-Object -First 1
  }

  It 'running --help --version should return the version, not the help' {
    # need the last line of output
    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run --rm --name $SUT_CONTAINER -P $SUT_IMAGE --help --version"
    $exitCode | Should -Be 0
    $stdout -split '`n' | %{$_.Trim()} | Select-Object -Last 1 | Should -Be $version
  }

  It 'version in docker metadata' {
    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "inspect -f `"{{index .Config.Labels \`"org.opencontainers.image.version\`"}}`" $SUT_IMAGE"
    $exitCode | Should -Be 0
    $stdout.Trim() | Should -Match $version
  }

  It 'commit SHA in docker metadata' {
    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "inspect -f `"{{index .Config.Labels \`"org.opencontainers.image.revision\`"}}`" $SUT_IMAGE"
    $exitCode | Should -Be 0
    $stdout.Trim() | Should -Match $revision
  }
}

Describe "[$TEST_TAG] passing JVM parameters" {
  BeforeAll {
    $tzSetting = '-Duser.timezone=Europe/Madrid'
    $tzRegex = [regex]::Escape("Europe/Madrid")

    $cspSetting = @'
-Dhudson.model.DirectoryBrowserSupport.CSP=\"default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';\"
'@
    $cspRegex = [regex]::Escape("default-src &#039;self&#039;; script-src &#039;self&#039; &#039;unsafe-inline&#039; &#039;unsafe-eval&#039;; style-src &#039;self&#039; &#039;unsafe-inline&#039;;")

    function Start-With-Opts() {
      Param (
        [string] $JAVA_OPTS,
        [string] $JENKINS_JAVA_OPTS
      )

      $cmd = "docker --% run -d --name $SUT_CONTAINER -P"
      if ($JAVA_OPTS.length -gt 0) {
        $cmd += " -e JAVA_OPTS=`"$JAVA_OPTS`""
      }
      if ($JENKINS_JAVA_OPTS.length -gt 0) {
        $cmd += " -e JENKINS_JAVA_OPTS=`"$JENKINS_JAVA_OPTS`""
      }
      $cmd += " $SUT_IMAGE"

      Invoke-Expression $cmd
      $lastExitCode | Should -Be 0

      # give time to eventually fail to initialize
      Start-Sleep -Seconds 5
      Retry-Command -RetryCount 3 -Delay 1 -ScriptBlock { docker inspect -f "{{.State.Running}}" $SUT_CONTAINER ; if($lastExitCode -ne 0) { throw('Docker inspect failed') } } -Verbose | Should -BeTrue

      # it takes a while for jenkins to be up enough
      Retry-Command -RetryCount 30 -Delay 5 -ScriptBlock { Test-Url $SUT_CONTAINER "/api/json" } -Verbose | Should -BeTrue
    }

    function Get-Csp-Value() {
      return (Get-JenkinsWebpage $SUT_CONTAINER "/systemInfo").Replace("</tr>","</tr>`n").Replace("<wbr>", "").Split("`n") | Select-String -Pattern '<td class="pane">hudson.model.DirectoryBrowserSupport.CSP</td>' 
    }

    function Get-Timezone-Value() {
      return (Get-JenkinsWebpage $SUT_CONTAINER "/systemInfo").Replace("</tr>","</tr>`n").Replace("<wbr>", "").Split("`n") | Select-String -Pattern '<td class="pane">user.timezone</td>' 
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
    Cleanup $SUT_CONTAINER | Out-Null
  }
}

