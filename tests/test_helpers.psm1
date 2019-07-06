
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

# # Assert that $1 is the outputof a command $2
# function assert {
#     local expected_output=$1
#     shift
#     local actual_output
#     actual_output=$("$@")
#     actual_output="${actual_output//[$'\t\r\n']}" # remove newlines
#     if ! [ "$actual_output" = "$expected_output" ]; then
#         echo "expected: \"$expected_output\""
#         echo "actual:   \"$actual_output\""
#         false
#     fi
# }

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
    $DOCKERFILE = Get-EnvOrDefault 'DOCKERFILE' 'Dockerfile-windows'
    return "pester-jenkins-$DOCKERFILE".ToLower() | %{$_ -replace 'dockerfile$','default'} | %{$_ -replace 'dockerfile-',''} | Select-Object -First 1
}

function Run-Program($cmd, $params) {
    $psi = New-object System.Diagnostics.ProcessStartInfo 
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
    $DOCKERFILE = Get-EnvOrDefault 'DOCKERFILE' 'Dockerfile-windows'
    $DOCKERFILE = $DOCKERFILE.Trim()

    if(-Not [System.String]::IsNullOrWhiteSpace($env:JENKINS_VERSION)) {
        return (Run-Program 'docker.exe' "build -f ./$DOCKERFILE --build-arg JENKINS_VERSION=$env:JENKINS_VERSION --build-arg JENKINS_SHA=$env:JENKINS_SHA $args")
    } 
    return (Run-Program 'docker.exe' "build -f ./$DOCKERFILE $args")
}

function Build-DockerChild($tag, $dir) {
    cat "$dir/Dockerfile-windows" | %{$_ -replace "FROM bats-jenkins","FROM $(Get-SutImage)" } | Out-File -FilePath "$dir/Dockerfile-windows.tmp" -Encoding ASCII
    return (Run-Program 'docker.exe' "build -t `"$tag`" $args -f `"$dir/Dockerfile-windows.tmp`" `"$dir`"")
}

function Get-JenkinsUrl($Container) {
    $DOCKER_IP=(Get-EnvOrDefault 'DOCKER_HOST' 'localhost') | %{$_ -replace 'tcp://(.*):[0-9]*','$1'} | Select-Object -First 1
    return "http://$($DOCKER_IP):$(docker port "$CONTAINER" 8080 | %{$_ -split ':',2})"
}

function Get-JenkinsPassword($Container) {
    return $(docker logs $Container 2>&1 | Select-String -Context 0,2 -Pattern "Please use the following password to proceed to installation").Context.PostContext[1]
}

function Test-Url($Container, $Url) {
    Write-Output "Jenkins password = $(Get-JenkinsPassword $Container)"
    Write-Output "Jenkins URL = $(Get-JenkinsUrl $Container)"
    $pass = ConvertTo-SecureString $(Get-JenkinsPassword) -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ("admin", $pass)
    $res = Invoke-WebRequest -Uri "$(Get-JenkinsUrl)$Url" -Credential $cred -TimeoutSec 60 -Method Head
    if($res.StatusCode -eq 200) {
        return $true
    } 
    Write-Error "URL $(Get-JenkinsUrl $Container)$url failed"
    return $false    
}

function Cleanup($image) {
    Write-Host "match? $(docker ps | %{ $_ -match $image })"
    docker kill "$image" | Out-Null
    docker rm -fv "$image" | Out-Null
}

function Unzip-Manifest($plugin, $work) {
    bash -c "docker run --rm -v $work:C:/ProgramData/jenkins_home --entrypoint unzip $SUT_IMAGE -p C:/ProgramData/jenkins_home/plugins/$plugin META-INF/MANIFEST.MF"
}
