[CmdletBinding()]
Param(
    [Parameter(Position=1)]
    [String] $Target = "build",
    [String] $TagPrefix = 'latest',
    [String] $AdditionalArgs = '',
    [String] $Build = '',
    [String] $JenkinsVersion = ''
)

$Repository = 'jenkins'
$Organization = 'jenkins4eval'

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_REPO)) {
    $Repository = $env:DOCKERHUB_REPO
}

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_ORGANISATION)) {
    $Organization = $env:DOCKERHUB_ORGANISATION
}

# this is the jdk version that will be used for the 'bare tag' images, e.g., jdk8-windowsservercore-1809 -> windowsserver-1809
$defaultBuild = '8'
$defaultJvm = 'hotspot'
$builds = @{}

Get-ChildItem -Recurse -Include windows -Directory | ForEach-Object {
    Get-ChildItem -Recurse -Directory -Path $_ | Where-Object { Test-Path (Join-Path $_.FullName "Dockerfile") } | ForEach-Object {
        $dir = $_.FullName.Replace((Get-Location), "").TrimStart("\")
        $items = $dir.Split("\")
        $jdkVersion = $items[0]
        $baseImage = $items[2]
        $jvmType = $items[3]
        $basicTag = "jdk${jdkVersion}-${jvmType}-${baseImage}"
        $tags = @( $basicTag )
        if(($jdkVersion -eq $defaultBuild) -and ($jvmType -eq $defaultJvm)) {
            $tags += $baseImage
        }

        $builds[$basicTag] = @{
            'Folder' = $dir;
            'Tags' = $tags;
        }
    }
}

if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
    foreach($tag in $builds[$Build]['Tags']) {
        Write-Host "Building $Build => tag=$tag"
        Copy-Item -Path 'jenkins.ps1' -Destination (Join-Path $builds[$Build]['Folder'] 'jenkins.ps1') -Force
        Copy-Item -Path 'jenkins-support.psm1' -Destination (Join-Path $builds[$Build]['Folder'] 'jenkins-support.psm1') -Force
        Copy-Item -Path 'jenkins-plugin-cli.ps1' -Destination (Join-Path $builds[$Build]['Folder'] 'jenkins-plugin-cli.ps1') -Force
        $cmd = "docker build -t {0}/{1}:{2} {3} {4}" -f $Organization, $Repository, $tag, $AdditionalArgs, $builds[$Build]['Folder']
        Invoke-Expression $cmd

        if($PushVersions) {
            $buildTag = "$JenkinsVersion-$tag"
            if($tag -eq 'latest') {
                $buildTag = "$JenkinsVersion"
            }
            Write-Host "Building $Build => tag=$buildTag"
            $cmd = "docker build -t {0}/{1}:{2} {3} {4}" -f $Organization, $Repository, $buildTag, $AdditionalArgs, $builds[$Build]['Folder']
            Invoke-Expression $cmd
        }
    }
} else {
    foreach($b in $builds.Keys) {
        foreach($tag in $builds[$b]['Tags']) {
            Write-Host "Building $b => tag=$tag"
            Copy-Item -Path 'jenkins.ps1' -Destination (Join-Path $builds[$b]['Folder'] 'jenkins.ps1') -Force
            Copy-Item -Path 'jenkins-support.psm1' -Destination (Join-Path $builds[$b]['Folder'] 'jenkins-support.psm1') -Force
            Copy-Item -Path 'jenkins-plugin-cli.ps1' -Destination (Join-Path $builds[$b]['Folder'] 'jenkins-plugin-cli.ps1') -Force
            $cmd = "docker build -t {0}/{1}:{2} {3} {4}" -f $Organization, $Repository, $tag, $AdditionalArgs, $builds[$b]['Folder']
            Invoke-Expression $cmd

            if($PushVersions) {
                $buildTag = "$JenkinsVersion-$tag"
                if($tag -eq 'latest') {
                    $buildTag = "$JenkinsVersion"
                }
                Write-Host "Building $Build => tag=$buildTag"
                $cmd = "docker build -t {0}/{1}:{2} {3} {4}" -f $Organization, $Repository, $buildTag, $AdditionalArgs, $builds[$b]['Folder']
                Invoke-Expression $cmd
            }
        }
    }
}

if($lastExitCode -ne 0) {
    exit $lastExitCode
}

if($target -eq "test") {
    # Only fail the run afterwards in case of any test failures
    $testFailed = $false
    $mod = Get-InstalledModule -Name Pester -MinimumVersion 4.9.0 -MaximumVersion 4.99.99 -ErrorAction SilentlyContinue
    if($null -eq $mod) {
        $module = "c:\Program Files\WindowsPowerShell\Modules\Pester"
        if(Test-Path $module) {
            takeown /F $module /A /R
            icacls $module /reset
            icacls $module /grant Administrators:'F' /inheritance:d /T
            Remove-Item -Path $module -Recurse -Force -Confirm:$false
        }
        Install-Module -Force -Name Pester -MaximumVersion 4.99.99
    }

    if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
        $folder = $builds[$Build]['Folder']
        $env:FOLDER = $folder
        if(Test-Path ".\target\$folder") {
            Remove-Item -Force -Recurse ".\target\$folder"
        }
        New-Item -Path ".\target\$folder" -Type Directory | Out-Null
        $TestResults = Invoke-Pester -Path tests -PassThru -OutputFile ".\target\$folder\junit-results.xml" -OutputFormat JUnitXml
        if ($TestResults.FailedCount -gt 0) {
            Write-Host "There were $($TestResults.FailedCount) failed tests in $Build"
            $testFailed = $true
        } else {
            Write-Host "There were $($TestResults.PassedCount) passed tests out of $($TestResults.TotalCount) in $Build"
        }
        Remove-Item -Force env:\FOLDER
    } else {
        foreach($b in $builds.Keys) {
            $folder = $builds[$b]['Folder']
            $env:FOLDER = $folder
            if(Test-Path ".\target\$folder") {
                Remove-Item -Force -Recurse ".\target\$folder"
            }
            New-Item -Path ".\target\$folder" -Type Directory | Out-Null
            $TestResults = Invoke-Pester -Path tests -PassThru -OutputFile ".\target\$folder\junit-results.xml" -OutputFormat JUnitXml
            if ($TestResults.FailedCount -gt 0) {
                Write-Host "There were $($TestResults.FailedCount) failed tests in $b"
                $testFailed = $true
            } else {
                Write-Host "There were $($TestResults.PassedCount) passed tests out of $($TestResults.TotalCount) in $b"
            }
            Remove-Item -Force env:\FOLDER
        }
    }

    # Fail if any test failures
    if($testFailed -ne $false) {
        Write-Error "Test stage failed!"
        exit 1
    } else {
        Write-Host "Test stage passed!"
    }
}

if($target -eq "publish") {
    # Only fail the run afterwards in case of any issues when publishing the docker images
    $publishFailed = 0
    if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
        foreach($tag in $Builds[$Build]['Tags']) {
            Write-Host "Publishing $Build => tag=$tag"
            $cmd = "docker push {0}/{1}:{2}" -f $Organization, $Repository, $tag
            Invoke-Expression $cmd
            if($lastExitCode -ne 0) {
                $publishFailed = 1
            }

            if($PushVersions) {
                $buildTag = "$JenkinsVersion-$tag"
                if($tag -eq 'latest') {
                    $buildTag = "$JenkinsVersion"
                }
                Write-Host "Publishing $Build => tag=$buildTag"
                $cmd = "docker push {0}/{1}:{2}" -f $Organization, $Repository, $buildTag
                Invoke-Expression $cmd
                if($lastExitCode -ne 0) {
                    $publishFailed = 1
                }
            }
        }
    } else {
        foreach($b in $builds.Keys) {
            foreach($tag in $Builds[$b]['Tags']) {
                Write-Host "Publishing $b => tag=$tag"
                $cmd = "docker push {0}/{1}:{2}" -f $Organization, $Repository, $tag
                Invoke-Expression $cmd
                if($lastExitCode -ne 0) {
                    $publishFailed = 1
                }

                if($PushVersions) {
                    $buildTag = "$JenkinsVersion-$tag"
                    if($tag -eq 'latest') {
                        $buildTag = "$JenkinsVersion"
                    }
                    Write-Host "Publishing $Build => tag=$buildTag"
                    $cmd = "docker push {0}/{1}:{2}" -f $Organization, $Repository, $buildTag
                    Invoke-Expression $cmd
                    if($lastExitCode -ne 0) {
                        $publishFailed = 1
                    }
                }
            }
        }
    }

    # Fail if any issues when publising the docker images
    if($publishFailed -ne 0) {
        Write-Error "Publish failed!"
        exit 1
    }
}

if($lastExitCode -ne 0) {
    Write-Error "Build failed!"
} else {
    Write-Host "Build finished successfully"
}
exit $lastExitCode
