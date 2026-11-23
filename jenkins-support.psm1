
# Splits a Jenkins plugin version string into its comparable "primary" dotted
# version and an optional trailing incremental-build qualifier, stopping
# before any opaque ".v<hash>" content-hash marker (e.g. ".vd97de6465d5b_").
# A literal '-' before the marker separates the primary version from the
# qualifier (e.g. "5.6.5-209.v..." -> primary "5.6.5", qualifier "209");
# without a '-', there is no qualifier and the whole pre-marker string is the
# primary (e.g. "587.588.v..." -> primary "587.588", no qualifier).
function Split-PluginVersion([string] $version) {
    $preMarker = $version
    if ($version -match '^(.*)\.v[0-9A-Za-z_]') {
        $preMarker = $matches[1]
    }
    $dashIndex = $preMarker.IndexOf('-')
    if ($dashIndex -ge 0) {
        return @($preMarker.Substring(0, $dashIndex), $preMarker.Substring($dashIndex + 1))
    }
    return @($preMarker, '')
}

# Compares two dotted-numeric primary versions, zero-padding the shorter one
# so e.g. "3.12.0" == "3.12.0.0" but "5.6" < "5.6.5". Returns -1, 0 or 1.
function Compare-PluginVersionPrimary([string] $a, [string] $b) {
    $partsA = $a.Split('.')
    $partsB = $b.Split('.')
    $maxLength = [Math]::Max($partsA.Length, $partsB.Length)
    for ($i = 0; $i -lt $maxLength; $i++) {
        $partA = if ($i -lt $partsA.Length) { $partsA[$i] } else { '0' }
        $partB = if ($i -lt $partsB.Length) { $partsB[$i] } else { '0' }
        $numA = 0
        $numB = 0
        $isNumA = [int64]::TryParse($partA, [ref]$numA)
        $isNumB = [int64]::TryParse($partB, [ref]$numB)
        if ($isNumA -and $isNumB) {
            if ($numA -lt $numB) { return -1 }
            if ($numA -gt $numB) { return 1 }
        } else {
            if ($partA -lt $partB) { return -1 }
            if ($partA -gt $partB) { return 1 }
        }
    }
    return 0
}

# compare if version1 < version2
#
# Jenkins plugin versions routinely mix two independent kinds of version
# strings for the *same* plugin across releases: a longer, more specific
# dotted version (e.g. "5.6.5-209.v<hash>") and a shorter one from before the
# plugin adopted that extra component (e.g. "5.6-191.v<hash>"). Naively
# flattening both into one dot-separated sequence (as `-replace '-', '.'`
# does) and comparing them position-by-position silently misaligns the two:
# the shorter version's incremental-build number ends up compared directly
# against the longer version's *real* third version component, since it
# slides into the same position. For "5.6-191.v..." vs "5.6.5-209.v...",
# that comparison is "191" against "5" at the third position -- 191 > 5, so
# the 4-part version is (wrongly) considered the older one, which is exactly
# backwards (5.6.5 is a newer release than 5.6). This is what the entrypoint
# hit for apache-httpcomponents-client-5-api 5.6.5-209.v... vs the installed
# 5.6-191.v..., causing jenkins-support to skip a real plugin upgrade and
# leave an incompatible, stale version installed.
#
# A prior fix (https://github.com/jenkinsci/docker/issues/2328) special-cased
# one specific depth of this same shape mismatch (a 2-part vs. 3-part
# version split right after the first segment, as in
# "3894.vd0f0248b_a_fc4" vs "3894.3896.vca_2c931e7935" -- a security-fix
# backport). It doesn't generalize: it only inspects the segment
# immediately after the first one, so it doesn't catch a mismatch one level
# deeper, like the httpcomponents-client-5-api case above.
#
# This splits each version into its real, comparable "primary" dotted
# version and an optional trailing incremental-build qualifier (see
# Split-PluginVersion), compares the primaries first (with zero-padding, so
# depth differences compare correctly instead of misaligning), and only
# falls back to comparing qualifiers when the primaries are equal -- which
# also subsumes the 2328 special case, so it's removed rather than kept
# alongside this.
function Compare-VersionLessThan([string] $version1 = '', [string] $version2 = '') {
    # Quick check for equality
    if($version1 -eq $version2) {
        return $false
    }

    $split1 = Split-PluginVersion $version1
    $split2 = Split-PluginVersion $version2
    $primary1 = $split1[0]
    $qualifier1 = $split1[1]
    $primary2 = $split2[0]
    $qualifier2 = $split2[1]

    $primaryCmp = Compare-PluginVersionPrimary $primary1 $primary2
    if ($primaryCmp -lt 0) { return $true }
    if ($primaryCmp -gt 0) { return $false }

    # Primaries are equal: a present qualifier is a later incremental build
    # on top of the same base version, so "no qualifier" is older than "has
    # a qualifier", and otherwise compare the qualifiers as plain integers.
    if ([string]::IsNullOrEmpty($qualifier1) -and -not [string]::IsNullOrEmpty($qualifier2)) {
        return $true
    }
    if (-not [string]::IsNullOrEmpty($qualifier1) -and [string]::IsNullOrEmpty($qualifier2)) {
        return $false
    }
    if ([string]::IsNullOrEmpty($qualifier1) -and [string]::IsNullOrEmpty($qualifier2)) {
        return $false
    }
    # Numerically when both are plain integers (as in every known real-world
    # case), falling back to a string comparison otherwise -- qualifiers
    # aren't guaranteed to be numeric, and this must never throw the way a
    # bare [int64] cast on a non-numeric value would.
    $numQ1 = 0
    $numQ2 = 0
    if ([int64]::TryParse($qualifier1, [ref]$numQ1) -and [int64]::TryParse($qualifier2, [ref]$numQ2)) {
        return ($numQ1 -lt $numQ2)
    }
    return ($qualifier1 -lt $qualifier2)
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

# Substitute environment variables in file content
# Supports ${VAR} and ${VAR:-default} syntax
# Enabled only when JENKINS_ENABLE_ENV_SUBST=true
function Invoke-EnvVarSubstitution($file) {
    $content = Get-Content -Raw $file
    $pattern = '\$\{([A-Za-z_][A-Za-z0-9_]*)(:-([^}]*))?\}'
    $content = [regex]::Replace($content, $pattern, {
        param($match)
        $varName = $match.Groups[1].Value
        $defaultValue = $match.Groups[3].Value
        $varValue = [System.Environment]::GetEnvironmentVariable($varName)
        if ([string]::IsNullOrEmpty($varValue)) {
            if (![string]::IsNullOrEmpty($defaultValue)) {
                return $defaultValue
            }
            return ''
        }
        return $varValue
    })
    Set-Content -Path $file -Value $content -NoNewline
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
            # Perform environment variable substitution on config files (opt-in)
            if ((Get-EnvOrDefault 'JENKINS_ENABLE_ENV_SUBST' 'false') -eq 'true') {
                if ($rel -match '\.(xml|conf|properties|groovy)$') {
                    $destFile = Join-Path $env:JENKINS_HOME $rel
                    if (Test-Path $destFile) {
                        Invoke-EnvVarSubstitution $destFile
                    }
                }
            }
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