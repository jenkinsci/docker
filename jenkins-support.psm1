
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
        # this works even if both sides are "latest"
        if($q1 -eq $q2) {
            return $false
        } else {
            if([System.String]::IsNullOrWhiteSpace($q1)) {
                return $false
            } else {
                if([System.String]::IsNullOrWhiteSpace($q2)) {
                    return $true
                } else {
                    return ($q1 -eq $("$q1","$q2" | Sort-Object | Select-Object -First 1))
                }
            }
        }
    }

    if($v1 -eq "latest") {
        return $false
    } elseif($v2 -eq "latest") {
        return $true
    }

    return ($v1 -eq $("$v1","$v2" | Sort-Object {[version] $_} | Select-Object -first 1))
}

function Get-EnvOrDefault($name, $def) {
    $entry = Get-ChildItem env: | Where-Object { $_.Name -eq $name } | Select-Object -First 1
    if(($null -ne $entry) -and ![System.String]::IsNullOrWhiteSpace($entry.Value)) {
        return $entry.Value
    }
    return $def
}

function Expand-Zip($archive, $file) {
    # load ZIP methods
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    Write-Verbose "Unzipping $file from $archive"

    $contents = ""

    if(Test-Path $archive) {
        # open ZIP archive for reading
        $zip = [System.IO.Compression.ZipFile]::OpenRead($archive)

        if($null -ne $zip) {
            $entry = $zip.GetEntry($file)
            if($null -ne $entry) {
                $reader = New-Object -TypeName System.IO.StreamReader -ArgumentList $entry.Open()
                $contents = $reader.ReadToEnd()
                $reader.Dispose()
            }

            # close ZIP file
            $zip.Dispose()
        }
    }

    return $contents
}

# returns a plugin version from a plugin archive
function Get-PluginVersion($archive) {
    $archive = $archive.Trim()
    Write-Verbose "Getting plugin version for $archive"
    if(-not (Test-Path $archive)) {
        return ""
    }

    $version = Expand-Zip $archive "META-INF/MANIFEST.MF" | ForEach-Object {$_ -split "`n"} | Select-String -Pattern "^Plugin-Version:\s+" | ForEach-Object {$_ -replace "^Plugin-Version:\s+(.*)", '$1'} | Select-Object -First 1 | Out-String
    return $version.Trim()
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

    Push-Location $refDir
    $rel = Resolve-Path -Relative -Path $file
    Pop-Location
    $dir = Split-Path -Parent $rel

    if($file -match "plugins[\\/].*\.jpi") {
        $fileName = Split-Path -Leaf $file
        $versionMarker = (Join-Path $env:JENKINS_HOME (Join-Path "plugins" "${fileName}.version_from_image"))
        $containerVersion = Get-PluginVersion (Join-Path $env:JENKINS_HOME $rel)
        $imageVersion = Get-PluginVersion $file
        if(Test-Path $versionMarker) {
            $markerVersion = (Get-Content -Raw $versionMarker).Trim()
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
                    Add-Content -Path $versionMarker -Value $imageVersion
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

            if(-not (Test-Path (Join-Path $env:JENKINS_HOME $dir))) {
                New-Item -ItemType Directory -Path (Join-Path $env:JENKINS_HOME $dir)
            }
            Copy-Item $file (Join-Path $env:JENKINS_HOME $rel)
            # pin plugins on initial copy
            Write-Output $null >> (Join-Path $env:JENKINS_HOME "${rel}.pinned")
            Add-Content -Path $versionMarker -Value $imageVersion
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
            if(-not (Test-Path (Join-Path $env:JENKINS_HOME (Split-Path -Parent $rel)))) {
                New-Item -ItemType Directory (Join-Path $env:JENKINS_HOME (Split-Path -Parent $rel))
            }
            Copy-Item $file (Join-Path $env:JENKINS_HOME $rel)
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