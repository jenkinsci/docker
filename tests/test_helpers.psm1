
Import-Module -DisableNameChecking -Force $PSScriptRoot/../jenkins-support.psm1

function Test-CommandExists($command) {
  $oldPreference = $ErrorActionPreference
  $ErrorActionPreference = 'stop'
  $res = $false
  try {
      if(Get-Command $command) { 
          $res = $true 
      }
  } catch {
      $res = $false 
  } finally {
      $ErrorActionPreference=$oldPreference
  }
  return $res
}

# check dependencies
if(-Not (Test-CommandExists docker)) {
    Write-Error "docker is not available"
}

function Retry-Command {
    [CmdletBinding()]
    param (
        [parameter(Mandatory, ValueFromPipeline)] 
        [ValidateNotNullOrEmpty()]
        [scriptblock] $ScriptBlock,
        [int] $RetryCount = 3,
        [int] $Delay = 30,
        [string] $SuccessMessage = "Command executed successfuly!",
        [string] $FailureMessage = "Failed to execute the command"
        )
        
    process {
        $Attempt = 1
        $Flag = $true
        
        do {
            try {
                $PreviousPreference = $ErrorActionPreference
                $ErrorActionPreference = 'Stop'
                Invoke-Command -NoNewScope -ScriptBlock $ScriptBlock -OutVariable Result 4>&1              
                $ErrorActionPreference = $PreviousPreference

                # flow control will execute the next line only if the command in the scriptblock executed without any errors
                # if an error is thrown, flow control will go to the 'catch' block
                Write-Verbose "$SuccessMessage `n"
                $Flag = $false
            }
            catch {
                if ($Attempt -gt $RetryCount) {
                    Write-Verbose "$FailureMessage! Total retry attempts: $RetryCount"
                    Write-Verbose "[Error Message] $($_.exception.message) `n"
                    $Flag = $false
                } else {
                    Write-Verbose "[$Attempt/$RetryCount] $FailureMessage. Retrying in $Delay seconds..."
                    Start-Sleep -Seconds $Delay
                    $Attempt = $Attempt + 1
                }
            }
        }
        While ($Flag)
    }
}

function Get-SutImage {
    $FOLDER = Get-EnvOrDefault 'FOLDER' ''

    $REAL_FOLDER=Resolve-Path -Path "$PSScriptRoot/../${FOLDER}"

    if(($FOLDER -match '^(?<jdk>[0-9]+)[\\/](?<os>.+)[\\/](?<flavor>.+)[\\/](?<jvm>.+)$') -and (Test-Path $REAL_FOLDER)) {
        $JDK = $Matches['jdk']
        $FLAVOR = $Matches['flavor']
        $JVM = $Matches['jvm']
    } else {
        Write-Error "Wrong folder format or folder does not exist: $FOLDER"
        exit 1
    }

    return "pester-jenkins-$JDK-$JVM-$FLAVOR".ToLower()
}

function Run-Program($cmd, $params, $verbose=$false) {
    if($verbose) {
        Write-Host "$cmd $params"
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo 
    $psi.CreateNoWindow = $true 
    $psi.UseShellExecute = $false 
    $psi.RedirectStandardOutput = $true 
    $psi.RedirectStandardError = $true
    $psi.WorkingDirectory = (Get-Location)
    $psi.FileName = $cmd 
    $psi.Arguments = $params
    $proc = New-Object System.Diagnostics.Process 
    $proc.StartInfo = $psi 
    [void]$proc.Start()
    $stdout = $proc.StandardOutput.ReadToEnd() 
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit() 
    if($proc.ExitCode -ne 0) {
        Write-Host "`n`nstdout:`n$stdout`n`nstderr:`n$stderr`n`n"
    }

    return $proc.ExitCode, $stdout, $stderr
}

function Build-Docker {
    $FOLDER = Get-EnvOrDefault 'FOLDER' ''
    $FOLDER = $FOLDER.Trim()

    if(-not [System.String]::IsNullOrWhiteSpace($env:JENKINS_VERSION)) {
        return (Run-Program 'docker.exe' "build --build-arg JENKINS_VERSION=$env:JENKINS_VERSION --build-arg JENKINS_SHA=$env:JENKINS_SHA $args $FOLDER")
    } 
    return (Run-Program 'docker.exe' "build $args $FOLDER")
}

function Build-DockerChild($tag, $dir) {
    Get-Content "$dir/Dockerfile-windows" | ForEach-Object{$_ -replace "FROM bats-jenkins","FROM $(Get-SutImage)" } | Out-File -FilePath "$dir/Dockerfile-windows.tmp" -Encoding ASCII
    return (Run-Program 'docker.exe' "build -t `"$tag`" $args -f `"$dir/Dockerfile-windows.tmp`" `"$dir`"")
}

function Get-JenkinsUrl($Container) {
    $DOCKER_IP=(Get-EnvOrDefault 'DOCKER_HOST' 'localhost') | %{$_ -replace 'tcp://(.*):[0-9]*','$1'} | Select-Object -First 1
    $port = (docker port "$CONTAINER" 8080 | %{$_ -split ':'})[1]
    return "http://$($DOCKER_IP):$($port)"
}

function Get-JenkinsPassword($Container) {
    $res = docker exec $Container powershell.exe -c 'if(Test-Path "C:\ProgramData\Jenkins\JenkinsHome\secrets\initialAdminPassword") { Get-Content "C:\ProgramData\Jenkins\JenkinsHome\secrets\initialAdminPassword" ; exit 0 } else { exit -1 }'
    if($lastExitCode -eq 0) {
        return $res
    }
    return $null
}

function Get-JenkinsWebpage($Container, $Url) {
    $jenkinsPassword = Get-JenkinsPassword $Container
    $jenkinsUrl = Get-JenkinsUrl $Container
    if($null -ne $jenkinsPassword) {
        $pair = "admin:$($jenkinsPassword)"
        $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
        $basicAuthValue = "Basic $encodedCreds"
        $Headers = @{ Authorization = $basicAuthValue }

        $res = Invoke-WebRequest -Uri $('{0}{1}' -f $jenkinsUrl, $Url) -Headers $Headers -TimeoutSec 60 -Method Get -UseBasicParsing
        if($res.StatusCode -eq 200) {
            return $res.Content
        } 
    }
    return $null    
}

function Test-Url($Container, $Url) {
    $jenkinsPassword = Get-JenkinsPassword $Container
    $jenkinsUrl = Get-JenkinsUrl $Container
    if($null -ne $jenkinsPassword) {
        $pair = "admin:$($jenkinsPassword)"
        $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
        $basicAuthValue = "Basic $encodedCreds"
        $Headers = @{ Authorization = $basicAuthValue }

        $res = Invoke-WebRequest -Uri $('{0}{1}' -f $jenkinsUrl, $Url) -Headers $Headers -TimeoutSec 60 -Method Head -UseBasicParsing
        if($res.StatusCode -eq 200) {
            return $true
        } 
    }
    Write-Error "URL $(Get-JenkinsUrl $Container)$Url failed"
    return $false    
}

function Cleanup($image) {
    docker kill "$image" 2>&1 | Out-Null
    docker rm -fv "$image" 2>&1 | Out-Null
}

function Unzip-Manifest($Container, $Plugin, $Work) {
    return (Run-Program "docker.exe" "run --rm -v `"${Work}:C:\ProgramData\Jenkins\JenkinsHome`" $Container mkdir C:/ProgramData/Jenkins/temp | Out-Null ; Copy-Item C:/ProgramData/Jenkins/JenkinsHome/plugins/$Plugin C:/ProgramData/Jenkins/temp/$Plugin.zip ; Expand-Archive C:/ProgramData/Jenkins/temp/$Plugin.zip -Destinationpath C:/ProgramData/Jenkins/temp ; `$content = Get-Content C:/ProgramData/Jenkins/temp/META-INF/MANIFEST.MF ; Remove-Item -Force -Recurse C:/ProgramData/Jenkins/temp ; Write-Host `$content ; exit 0")
}
