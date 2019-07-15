
# compare if version1 < version2
function Compare-VersionLessThan($version1, $version2) {
    $temp = $version1.Split('-')
    $v1 = $temp[0].Trim()
    $q1 = ''
    if($temp.Length -gt 1) {
        $q1 = $temp[1].Trim()
    }

    $temp = $version2.Split('-')
    $v2 = $temp[0].Trim()
    $q2 = ''
    if($temp.Length -gt 1) {
        $q2 = $temp[1].Trim()
    }

    if($v1 -eq $v2) {
        if($q1 -eq $q2) {
            return $false
        } else {
            if([System.String]::IsNullOrWhiteSpace($q1)) {
                return $false
            } else {
                if([System.String]::IsNullOrWhiteSpace($q2)) {
                    return $true
                } else {
                    return ($q1 -eq $("$q1","$q2" | sort | select -first 1))
                }
            }
        }
    }
    return ($v1 -eq $("$v1","$v2" | sort {[version] $_} | select -first 1))
}

function Get-EnvOrDefault($name, $def) {
    $entry = gci env: | ?{ $_.Name -eq $name } | Select-Object -First 1
    if(($null -ne $entry) -and ![System.String]::IsNullOrWhiteSpace($entry.Value)) {
        return $entry.Value
    }
    return $def
}

function Unzip-File($archive, $file) {
    # load ZIP methods
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    # open ZIP archive for reading
    $zip = [System.IO.Compression.ZipFile]::OpenRead($archive)
    $entry = $zip.GetEntry($file)
    $contents = $null
    if($null -ne $entry) {
        $reader = New-Object -TypeName System.IO.BinaryReader -ArgumentList $entry.Open()
        $length = $reader.BaseStream.Length
        $content = $reader.ReadBytes($length)
        $reader.Dispose()
    }

    # close ZIP file
    $zip.Dispose()

    return $contents
}

# returns a plugin version from a plugin archive
function Get-PluginVersion($archive) {
    return Unzip-File $archive "META-INF/MANIFEST.MF" | Select-String -Pattern "^Plugin-Version: " | %{$_ -replace "^Plugin-Version: ", ""}.Trim()
}

# Copy files from C:/ProgramData/Jenkins/Reference/ into $JENKINS_HOME
# So the initial JENKINS-HOME is set with expected content.
# Don't override, as this is just a reference setup, and use from UI
# can then change this, upgrade plugins, etc.
function Copy-ReferenceFile($file) {
    $action = ""
    $reason = ""
    $log = $false
    $refDir = Get-EnvOrDefault 'REF' 'C:/ProgramData/Jenkins/Reference'

    if(-not (Test-Path $refDir)) {
        return
    }

    Write-Host "Copy-ReferenceFile $file"
    pushd $refDir
    $rel = Resolve-Path -Relative -Path $file
    popd
    $dir = Split-Path -Parent $rel

    if($file -match "plugins[\\/].*\.jpi") {
        $fileName = Split-Path -Leaf $file
        $versionMarker = Join-Path "plugins" "$($fileName).version_from_image"
        $containerVersion = Get-PluginVersion (Join-Path $env:JENKINS_HOME (Join-Path "plugins" $fileName))
        $imageVersion = Get-PluginVersion $file
        if(Test-Path (Join-Path $env:JENKINS_HOME $versionMarker)) {
            $markerVersion = Get-Content $versionMarker
            if(Compare-VersionLessThan $markerVersion $containerVersion) {
                if((Compare-VersionLessThan $containerVersion $imageVersion) -and ![System.String]::IsNullOrWhiteSpace($env:PLUGINS_FORCE_UPGRADE)) {
                    $action = "UPGRADED"
                    $reason="Manually upgraded version ($containerVersion) is older than image version $imageVersion"
                    $log=$true
                } else {
                    $action="SKIPPED"
                    $reason="Installed version ($containerVersion) has been manually upgraded from initial version ($markerVersion)"
                    $log=$true
                }
            } else {
                if($imageVersion -eq $containerVersion) {
                    $action = "SKIPPED"
                    $reason = "Version from image is the same as the installed version $imageVersion"
                } else {
                    if(Compare-VersionLessThan $imageVersion $containerVersion) {
                        $action = "SKIPPED"
                        $log = $true
                        $reason = "Image version ($imageVersion) is older than installed version ($containerVersion)"
                    } else {
                        $action="UPGRADED"
                        $log=$true
                        $reason="Image version ($imageVersion) is newer than installed version ($containerVersion)"
                    }
                }
            }
         } else {
            if(![System.String]::IsNullOrWhiteSpace($env:TRY_UPGRADE_IF_NO_MARKER)) {
                if($imageVersion -eq $containerVersion) {
                    $action = "SKIPPED"
                    $reason = "Version from image is the same as the installed version $imageVersion (no marker found)"
                    # Add marker for next time
                    Add-Content -Path (Join-Path $env:JENKINS_HOME $versionMarker) -Value $imageVersion
                } else {
                    if(Compare-VersionLessThan $imageVersion $containerVersion) {
                        $action = "SKIPPED"
                        $log = $true
                        $reason = "Image version ($imageVersion) is older than installed version ($containerVersion) (no marker found)"
                    } else {
                        $action = "UPGRADED"
                        $log = $true
                        $reason = "Image version ($imageVersion) is newer than installed version ($containerVersion) (no marker found)"
                    }
                }
            }
        }

        if((-not (Test-Path (Join-Path $env:JENKINS_HOME $rel))) -or ($action -eq "UPGRADED") -or ($file -match "\.override")) {
            if([System.String]::IsNullOrWhiteSpace($action)) {
                $action = "INSTALLED"
            }
            $log=$true

            mkdir (Join-Path $env:JENKINS_HOME $dir)
            cp $file (Join-Path $env:JENKINS_HOME $rel)
            # pin plugins on initial copy

            touch (Join-Path $env:JENKINS_HOME "$($rel).pinned")
            Add-Content -Path (Join-Path $env:JENKINS_HOME $versionMarker) -Value $imageVersion
            if([System.String]::IsNullOrWhiteSpace($reason)) {
                $reason = $imageVersion
            }
        } else {
            if([System.String]::IsNullOrWhiteSpace($action)) {
                $action = "SKIPPED"
            }
        }
    } else {
        if((-not (Test-Path (Join-Path $env:JENKINS_HOME $rel))) -or ($file -match "\.override")) {
            $action = "INSTALLED"
            $log = $true
            mkdir (Join-Path $env:JENKINS_HOME (Split-Path -Parent $rel))
            cp $file (Join-Path $env:JENKINS_HOME $rel)
        } else {
            $action="SKIPPED"
        }
    }

    if(![System.String]::IsNullOrWhiteSpace($env:VERBOSE) -or $log) {
        if([System.String]::IsNullOrWhiteSpace($reason)) {
            Add-Content -Path $COPY_REFERENCE_FILE_LOG -Value "$action $rel"
        } else {
            Add-Content -Path $COPY_REFERENCE_FILE_LOG -Value "$action $rel : $reason"
        }
    }
}

function Get-DateUTC() {
    $now = (Get-Date).ToUniversalTime()
    return (Get-Date $now -UFormat '%T')
}

# Retries a command a configurable number of times with backoff.
#
# The retry count is given by ATTEMPTS (default 60), the initial backoff
# timeout is given by TIMEOUT in seconds (default 1.)
#
# function Retry-Command($cmd, $attempts=3, $timeout=1, $successTimeout=1, $successAttempts=1) {
#   $attempt=0
#   $success_attempt=0
#   $exitCode=0

#   while($attempt -lt $max_attempts) {
#     & $cmd
#     $exitCode=$lastExitCode

#     if($exitCode -eq 0) {
#       $success_attempt += 1
#       if($success_attempt -ge $max_success_attempt) {
#         break
#       } else {
#         Start-Sleep -Seconds $success_timeout
#         continue
#       }
#     }

#     Write-Warning "$(Get-DateUTC) Failure ($exitCode) Retrying in $timeout seconds..."
#     Start-Sleep -Seconds $timeout
#     $success_attempt=0
#     $attempt += 1
#   }
  
#   if($exitCode -ne 0) {
#     Write-Warning "$(Get-DateUTC) Failed in the last attempt ($cmd)"
#   }

#   return $exitCode
# }
