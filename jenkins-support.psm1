
# compare if version1 < version2
function Compare-VersionLessThan($version1, $version2) {
    # Quick equality check
    if ($version1 -eq $version2) {
        return $false
    }
    
    # Normalize Jenkins version format
    function Normalize-JenkinsVersion($version) {
        $mainVersion = $version
        $qualifier = ''
        
        # Split on first dash only
        if ($version.Contains('-')) {
            $dashIndex = $version.IndexOf('-')
            $mainVersion = $version.Substring(0, $dashIndex).Trim()
            $qualifier = $version.Substring($dashIndex + 1).Trim()
        }
        
        # Remove trailing .0 segments from main version
        # 3.12.0.0 -> 3.12.0, but preserve versions like 1.0
        while ($mainVersion.EndsWith('.0') -and ($mainVersion.Split('.').Length -gt 2)) {
            $mainVersion = $mainVersion.Substring(0, $mainVersion.Length - 2)
        }
        
        # Reconstruct normalized version
        if (-not [string]::IsNullOrWhiteSpace($qualifier)) {
            return "$mainVersion-$qualifier"
        } else {
            return $mainVersion
        }
    }
    
    # Detect if qualifier is a Jenkins build qualifier
    function Is-JenkinsBuildQualifier($qualifier) {
        # Jenkins build qualifiers typically: 36.vd97de6465d5b_, 1.v123, etc.
        return $qualifier -match '^[0-9]+\.v[a-zA-Z0-9_]+$'
    }
    
    # Detect if qualifier is a semantic pre-release identifier
    function Is-SemverPrerelease($qualifier) {
        # Common pre-release identifiers
        return $qualifier -match '^(alpha|beta|rc|snapshot|dev|test|milestone|m)([.-]?[0-9]*)?$'
    }
    
    # Normalize both versions
    $normV1 = Normalize-JenkinsVersion $version1
    $normV2 = Normalize-JenkinsVersion $version2
    
    # If versions are identical after normalization, they're equal
    if ($normV1 -eq $normV2) {
        return $false
    }
    
    # Split normalized versions for comparison
    $temp1 = $normV1.Split('-')
    $v1 = $temp1[0].Trim()
    $q1 = ''
    if ($temp1.Length -gt 1) {
        $q1 = $temp1[1].Trim()
    }
    
    $temp2 = $normV2.Split('-')
    $v2 = $temp2[0].Trim()
    $q2 = ''
    if ($temp2.Length -gt 1) {
        $q2 = $temp2[1].Trim()
    }
    
    # Compare main versions first
    if ($v1 -ne $v2) {
        # Handle "latest" special case
        if ($v1 -eq "latest") {
            return $false
        } elseif ($v2 -eq "latest") {
            return $true
        }
        
        # Use version sorting for numeric versions
        try {
            return ($v1 -eq ($v1, $v2 | Sort-Object {[version] $_} | Select-Object -first 1))
        } catch {
            # Fallback to string comparison if version parsing fails
            return ($v1 -eq ($v1, $v2 | Sort-Object | Select-Object -first 1))
        }
    }
    
    # Main versions are equal, compare qualifiers intelligently
    # FIXED LOGIC: Context-aware qualifier comparison
    
    if ([string]::IsNullOrWhiteSpace($q1) -and (-not [string]::IsNullOrWhiteSpace($q2))) {
        # v1 has no qualifier, v2 has qualifier
        if (Is-SemverPrerelease $q2) {
            # Semantic versioning: 1.0 > 1.0-beta (release > pre-release)
            return $false
        } elseif (Is-JenkinsBuildQualifier $q2) {
            # Jenkins versioning: 3.12.0 < 3.12.0-36.vXXX (base < build)
            return $true
        } else {
            # Default: assume Jenkins-style for unknown qualifiers (fixes issue #1456)
            return $true
        }
    } elseif ((-not [string]::IsNullOrWhiteSpace($q1)) -and [string]::IsNullOrWhiteSpace($q2)) {
        # v1 has qualifier, v2 has no qualifier  
        if (Is-SemverPrerelease $q1) {
            # Semantic versioning: 1.0-beta < 1.0 (pre-release < release)
            return $true
        } elseif (Is-JenkinsBuildQualifier $q1) {
            # Jenkins versioning: 3.12.0-36.vXXX > 3.12.0 (build > base)
            return $false
        } else {
            # Default: assume Jenkins-style
            return $false
        }
    } elseif ((-not [string]::IsNullOrWhiteSpace($q1)) -and (-not [string]::IsNullOrWhiteSpace($q2))) {
        # Both have qualifiers, compare them using sort
        return ($q1 -eq ($q1, $q2 | Sort-Object | Select-Object -First 1))
    }
    
    # Both are release versions and main versions are equal
    return $false
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