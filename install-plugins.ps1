# Resolve dependencies and download plugins given on the command line
#
# FROM jenkins
# RUN & C:/ProgramData/Jenkins/install-plugins.ps1 docker-slaves github-branch-source
#
# Environment variables:
# REF: directory with preinstalled plugins. Default: C:/ProgramData/Jenkins/Reference/Plugins
# JENKINS_WAR: full path to the jenkins.war. Default: C:/ProgramData/Jenkins/jenkins.war
# JENKINS_UC: url of the Update Center. Default: ""
# JENKINS_UC_EXPERIMENTAL: url of the Experimental Update Center for experimental versions of plugins. Default: ""
# JENKINS_INCREMENTALS_REPO_MIRROR: url of the incrementals repo mirror. Default: ""
# JENKINS_UC_DOWNLOAD: download url of the Update Center. Default: JENKINS_UC/download

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$false,Position=1)][String[]] $Plugins = @(),
    [String] $PluginFile = '',
    [String] $ReferenceDir = 'C:/ProgramData/Jenkins/Reference'
)

Import-Module -Force -DisableNameChecking C:/ProgramData/Jenkins/jenkins-support.psm1

$JENKINS_WAR = Get-EnvOrDefault 'JENKINS_WAR' 'C:/ProgramData/Jenkins/jenkins.war'
$JENKINS_UC = Get-EnvOrDefault 'JENKINS_UC' ''
$JENKINS_UC_EXPERIMENTAL = Get-EnvOrDefault 'JENKINS_UC_EXPERIMENTAL' ''
$JENKINS_INCREMENTALS_REPO_MIRROR = Get-EnvOrDefault 'JENKINS_INCREMENTALS_REPO_MIRROR' ''
$JENKINS_UC_DOWNLOAD = Get-EnvOrDefault 'JENKINS_UC_DOWNLOAD' "$JENKINS_UC/download"

$REF_DIR=Join-Path $(Get-EnvOrDefault 'REF' $ReferenceDir) "plugins"
$FAILED=Join-path $REF_DIR "failed-plugins.txt"

function Get-LockFile($pluginName) {
    Join-Path $REF_DIR "$pluginName.lock"
}

function Get-ArchiveFileName($pluginName) {
    Join-Path $REF_DIR "$pluginName.jpi"
}
function Download($plugin, $version='latest', $ignoreLockFile=$false, $url='') {
    $lock=Get-LockFile $plugin
    if($ignoreLockFile -or !(Test-Path $lock)) {
        if(!(DoDownload $plugin $version $url)) {
            # some plugin don't follow the rules about artifact ID
            # typically: docker-plugin
            $originalPlugin=$plugin
            $plugin="${plugin}-plugin"
            if(!(DoDownload $plugin $version $url)) {
                Write-Host -ForegroundColor Red "Failed to download plugin: $originalPlugin or $plugin"
                Add-Content -Path $FAILED -Value "Not downloaded: ${originalPlugin}"
                return $false
            }
        }

        if(!(CheckIntegrity $plugin)) {
            Write-Host -ForegroundColor Red "Downloaded file is not a valid ZIP: $(Get-ArchiveFileName $plugin)"
            Add-Content -Path $FAILED -Value "Download integrity: ${plugin}"
            return $false
        }

        Resolve-Dependencies $plugin
    }
}

function DoDownload($plugin, $version, $url) {
    $jpi=Get-ArchiveFileName $plugin

    # If plugin already exists and is the same version do not download
    if((Test-Path $jpi) -and ((Get-PluginVersion $jpi) -eq $version)) {
        Write-Host "Using provided plugin: $plugin"
        return $true
    }

    if(![System.String]::IsNullOrWhiteSpace($url)) {
        Write-Host "Will use url=$url"
    } elseif(($version -eq "latest") -and ![System.String]::IsNullOrWhiteSpace($JENKINS_UC_LATEST)) {
        # If version-specific Update Center is available, which is the case for LTS versions,
        # use it to resolve latest versions.
        $url="$JENKINS_UC_LATEST/latest/${plugin}.hpi"
    } elseif(($version -eq "experimental") -and ![System.String]::IsNullOrWhiteSpace($JENKINS_UC_EXPERIMENTAL)) {
        # Download from the experimental update center
        $url="$JENKINS_UC_EXPERIMENTAL/latest/${plugin}.hpi"
    } elseif($version -match "^incrementals.*") {
        # Download from Incrementals repo: https://jenkins.io/blog/2018/05/15/incremental-deployment/
        # Example URL: https://repo.jenkins-ci.org/incrementals/org/jenkins-ci/plugins/workflow/workflow-support/2.19-rc289.d09828a05a74/workflow-support-2.19-rc289.d09828a05a74.hpi
        $items = $version -split ';'
        $groupId=$items[1].Replace('.', '/').Trim()
        $incrementalsVersion=$items[2].Trim()
        $url="${JENKINS_INCREMENTALS_REPO_MIRROR}/${groupId}/${plugin}/${incrementalsVersion}/${plugin}-${incrementalsVersion}.hpi"
    } else {
        $JENKINS_UC_DOWNLOAD=Get-EnvOrDefault 'JENKINS_UC_DOWNLOAD' "$JENKINS_UC/download"
        $url="$JENKINS_UC_DOWNLOAD/plugins/$plugin/$version/${plugin}.hpi"
    }

    Write-Host "Downloading plugin $plugin from $url"
    $done = $false
    $retries = 0
    $success = $false
    do {
        try {
            $res = Invoke-WebRequest -Uri $url -UseBasicParsing -OutFile $jpi -PassThru -TimeoutSec 20
            $done = $success = $res.StatusCode -eq 200
        } catch {
            $retries = $retries + 1
            if($retries -gt 5) {
                $done = $true
            }
        }
    } while(!$done)
    return $success
}

function CheckIntegrity($plugin) {
    $jpi = Get-ArchiveFileName $plugin

    try {
        Expand-Zip $jpi "META-INF/MANIFEST.MF"
    } catch {
        return $false
    }
    return $true
}

function Resolve-Dependencies($plugin) {
    $jpi=Get-ArchiveFileName $plugin

    $dependencies = (Expand-Zip $jpi "META-INF/MANIFEST.MF").Replace("`r",'').Replace("`n", "|").Replace("| ", "").Replace("|", "`n").Split("`n") | Select-String -Pattern "^Plugin-Dependencies:\s+" | ForEach-Object { $_ -replace "^Plugin-Dependencies:\s+(.*)", '$1' } | Select-Object -First 1

    if([System.String]::IsNullOrWhiteSpace($dependencies)) {
        Write-Host " > $plugin has no dependencies"
        return
    }

    Write-Host " > $plugin depends on $dependencies"
    $dependencyJobs = @()

    $deps = $dependencies.Split(",", [System.StringSplitOptions]::RemoveEmptyEntries)
    foreach($dep in $deps) {
        $plugin=$dep.Split(":", [System.StringSplitOptions]::RemoveEmptyEntries)[0]
        if($dep -match "resolution:=optional") {
            Write-Host "Skipping optional dependency $plugin"
        } else {
            $bundled = $bundledPlugins.ContainsKey($plugin)
            $installed = (Get-InstalledPlugins).ContainsKey($plugin)
            if($bundled -or $installed) {
                if($bundled) {
                    $versionInstalled=$bundled[$plugin]
                } elseif($installed) {
                    $versionInstalled=(Get-InstalledPlugins)[$plugin]
                }
                $minVersion=Get-VersionFromPlugin $dep
                if(Compare-VersionLessThan $versionInstalled $minVersion) {
                    Write-Host "Upgrading bundled dependency $dep ($minVersion > $versionInstalled)"
                    Download $plugin | Out-Null
                } else {
                    Write-Host "Skipping already installed dependency $dep ($minVersion <= $versionInstalled)"
                }
            } else {
                Download $plugin | Out-Null
            }
        }
    }

    if($dependencyJobs.Length -gt 0) {
        Wait-Job -Job $dependencyJobs | Out-Null
        Write-Host (Receive-Job -Job $dependencyJobs)
    }
}

function Get-BundledPlugins() {
    $private:bundledPlugins = @{}
    if(Test-Path $JENKINS_WAR) {
        $TEMP_PLUGIN_DIR="C:/tmp/plugintemp.`$"
        jar tf $JENKINS_WAR | Select-String -Pattern '[^detached-]plugins.*\..pi' | Sort-Object | ForEach-Object {
            if(Test-Path $TEMP_PLUGIN_DIR) {
                Remove-Item -Force -Recurse $TEMP_PLUGIN_DIR
            }
            New-Item -ItemType Directory -Force -Path $TEMP_PLUGIN_DIR | Out-Null
            $PLUGIN=[System.IO.Path]::GetFileNameWithoutExtension($_)
            Push-Location $TEMP_PLUGIN_DIR
            & jar xf "$JENKINS_WAR" "$_"
            Pop-Location
            $VER=Get-PluginVersion "$TEMP_PLUGIN_DIR/$_"
            $private:bundledPlugins.Add($PLUGIN, $VER)
        }
        if(Test-Path $TEMP_PLUGIN_DIR) {
            Remove-Item -Force -Recurse $TEMP_PLUGIN_DIR
        }
    } else {
        Write-Host "war not found, installing all plugins: $JENKINS_WAR"
    }
    return $private:bundledPlugins
}

function Get-VersionFromPlugin($plugin) {
    if($plugin -match ".*:.*") {
        return $plugin.Split(":")[1]
    }
    return "latest"
}

function Get-InstalledPlugins() {
    $private:installedPlugins = @{}
    Get-ChildItem -Path (Join-Path $REF_DIR "*.jpi") | ForEach-Object {
        $private:installedPlugins.Add([System.IO.Path]::GetFileNameWithoutExtension($_.Name), (Get-PluginVersion $_.FullName))
    }
    return $private:installedPlugins
}

function Get-JenkinsMajorMinorVersion() {
    if(Test-Path $JENKINS_WAR) {
        $version=New-Object -TypeName "System.Version" -ArgumentList $(java -jar "$JENKINS_WAR" --version)
        return ('{0}.{1}' -f $version.Major,$version.Minor)
    }
    return ""
}


New-Item -Path $REF_DIR -ItemType Directory -Force | Out-Null
if(!(Test-Path $REF_DIR)) {
    exit 1
}

if(Test-Path $FAILED) {
    Remove-Item -Force -Recurse -Path $FAILED | Out-Null
}

if(![System.String]::IsNullOrWhiteSpace($PluginFile) -and (Test-Path $PluginFile)) {
    Get-Content $Pluginfile | ForEach-Object {
        # Remove leading/trailing spaces, comments, and empty lines
        $line = ((($_.Replace("`r", "") -replace '^[ \t]*','') -replace '[ \t]*$','') -replace '[ \t]*#.*$','') -replace '^[ \t]*$',''
        if(![System.String]::IsNullOrWhiteSpace($line)) {
            $Plugins += $line
        }
    }
}

# Create lock file manually before first run to make sure any explicit version set is used.
Write-Host "Creating initial ignoreLocks..."
foreach($plugin in $Plugins) {
    $p = $plugin.Split(':')[0]
    New-Item -ItemType Directory -Path (Get-LockFile $p) -Force | Out-Null
}

Write-Host "Analyzing war $JENKINS_WAR..."
$bundledPlugins = Get-BundledPlugins

Write-Host "Registering preinstalled plugins..."
$installedPlugins = Get-InstalledPlugins

# Check if there's a version-specific update center, which is the case for LTS versions
$jenkinsVersion=Get-JenkinsMajorMinorVersion
$res = Invoke-WebRequest -Uri "$JENKINS_UC/$jenkinsVersion" -UseBasicParsing -Method HEAD
if($res.StatusCode -eq 200) {
    $JENKINS_UC_LATEST="$JENKINS_UC/$jenkinsVersion"
    Write-Host "Using version-specific update center: $JENKINS_UC_LATEST..."
} else {
    $JENKINS_UC_LATEST=''
}

$pluginJobs = @()

# $init = [scriptblock]::Create(@"
# function Download {$function:Download}
# "@)

Write-Host "Downloading plugins..."
$pattern = New-Object -TypeName "System.Text.RegularExpressions.Regex" -ArgumentList '^([^:]+):?([^:]+)?:?([^:]+)?:?(http.+)?',Compiled
foreach($plugin in $Plugins) {
    $matches = $pattern.Matches($plugin)
    if($null -ne $matches) {
        $pluginId = $matches[0].Groups[1].Value
        $version = $matches[0].Groups[2].Value
        $ignoreLock = $matches[0].Groups[3].Value
        if([System.String]::IsNullOrWhiteSpace($ignoreLock)) {
            $ignoreLock = $true
        } else {
            $ignoreLock = [bool]$ignoreLock
        }
        $url = $matches[0].Groups[4].Value
        # $job = Start-Job -InitializationScript $init -ScriptBlock { Download $pluginId $version $ignoreLock $url | Out-Null }
        # $pluginJobs += $job
        Download $pluginId $version $ignoreLock $url | Out-Null
    } else {
        Write-Host "Skipping the line '${plugin}' as it does not look like a reference to a plugin"
    }
}

if($pluginJobs.Length -gt 0) {
    Wait-Job -Job $pluginJobs | Out-Null
    Receive-Job -Job $pluginJobs
}

Write-Host "`n`n"
Write-Host "WAR bundled plugins:"
$bundledPlugins.GetEnumerator() | Sort-Object -Property Key | Format-Table @{Label='Plugin'; Expression={$_.Key}},@{Label='Version';Expression={$_.Value}}

Write-Host "`n`n"
Write-Host "Installed plugins:"
(Get-InstalledPlugins).GetEnumerator() | Sort-Object -Property Key | Format-Table @{Label='Plugin'; Expression={$_.Key}},@{Label='Version';Expression={$_.Value}}

if(Test-Path $FAILED) {
    Write-Host -ForegroundColor Red "Some plugins failed to download!"
    Write-Host -ForegroundColor Red "$(Get-Content -Raw $FAILED)"
    exit 1
}

Write-Host "Cleaning up locks"
Get-ChildItem -Path "$REF_DIR\*.lock" | ForEach-Object {
    Remove-Item -Force -Recurse $_.FullName
}