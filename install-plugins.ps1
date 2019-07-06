# Resolve dependencies and download plugins given on the command line
#
# FROM jenkins
# RUN install-plugins.sh docker-slaves github-branch-source

$REF_DIR='C:/ProgramData/Jenkins/Ref/plugins'
if(-not [System.String]::IsNullOrWhiteSpace($env:REF_DIR)) {
    $REF_DIR = $env:REF_DIR
}

$FAILED="$REF_DIR/failed-plugins.txt"

Import-Module -DisableNameChecking -Force C:/ProgramData/Jenkins/jenkins-support.psm1

function Get-LockFile($plugin) {
    return "$REF_DIR/$($plugin).lock"
}

function Get-ArchiveFileName($plugin) {
    return "$REF_DIR/$($plugin).jpi"
}

function Download-Plugin($plugin, $version='latest', $ignoreLockFile=$false, $url='') {
    $lock=Get-LockFile $plugin

    if($ignoreLockFile -or (mkdir $lock)) {
        if(-not (Do-Download $plugin $version $url)) {
            # some plugin don't follow the rules about artifact ID
            # typically: docker-plugin
            $originalPlugin=$plugin
            $plugin="$($plugin)-plugin"
            if(-not (Do-Download $plugin $version $url)) {
                Write-Error "Failed to download plugin: $originalPlugin or $plugin"
                Add-Content -Path $FAILED -Value "Not downloaded: $originalPlugin"
                return $false
            }
        }

        if(-not (Check-Integrity $plugin)) {
            Write-Error "Downloaded file is not a valid ZIP: $(Get-ArchiveFilename $plugin)"
            Add-Content -Path $FAILED -Value "Download integrity: $plugin"
            return $false
        }

        Resolve-Dependencies $plugin
    }
    return $true
}

function Do-Download($plugin, $version, $url) {
    $jpi=Get-ArchiveFileName $plugin

    if((Test-Path $jpi) -and ((Unzip-File $jpi "META-INF/MANIFEST.MF") -match "^Plugin-Version $version`$")) {
        # If plugin already exists and is the same version do not download
        Write-Host "Using provided plugin: $plugin"
        return $true
    }

    if(![System.String]::IsNullOrWhiteSpace($url)) {
        Write-Host "We will use url=$url"
    } elseif($version -eq "latest" -and ![System.String]::IsNullOrWhiteSpace($JENKINS_UC_LATEST)) {
        # If version-specific Update Center is available, which is the case for LTS versions,
        # use it to resolve latest versions.
        $url="$env:JENKINS_UC_LATEST/latest/$($plugin).hpi"
    } elseif($version -eq "experimental" -and ![System.String]::IsNullOrWhiteSpace($JENKINS_UC_EXPERIMENTAL)) {
        # Download from the experimental update center
        $url="$env:JENKINS_UC_EXPERIMENTAL/latest/$($plugin).hpi"
    } elseif($version -match "incrementals.*") {
        # Download from Incrementals repo: https://jenkins.io/blog/2018/05/15/incremental-deployment/
        # Example URL: https://repo.jenkins-ci.org/incrementals/org/jenkins-ci/plugins/workflow/workflow-support/2.19-rc289.d09828a05a74/workflow-support-2.19-rc289.d09828a05a74.hpi

        $arrIN=$version -split ';'
        $groupId=$arrIN[1]
        $incrementalsVersion=$arrIN[2]
        $url="$env:JENKINS_INCREMENTALS_REPO_MIRROR/$($groupId.Replace('.', '/'))/$plugin/$incrementalsVersion/$plugin-$($incrementalsVersion).hpi"
    } else {
        $JENKINS_UC_DOWNLOAD="$env:JENKINS_UC/download"
        if(![System.String]::IsNullOrWhiteSpace($env:JENKINS_UC_DOWNLOAD)) {
            $JENKINS_UC_DOWNLOAD = $env:JENKINS_UC_DOWNLOAD
        }
        $url="$JENKINS_UC_DOWNLOAD/plugins/$plugin/$version/$($plugin).hpi"
    }

    Write-Host "Downloading plugin: $plugin from $url"
    try {
        Invoke-WebRequest -Uri $url -OutFile $jpi
    } catch {
        return $false
    }
    return $true
}

function Check-Integrity($plugin) {
    $jpi = Get-ArchiveFileName $plugin

    unzip -t -qq "$jpi" >/dev/null
    return $?
}

function Resolve-Dependencies($plugin) {
    $jpi = Get-ArchiveFileName $plugin

    # dependencies="$(unzip -p "$jpi" META-INF/MANIFEST.MF | tr -d '\r' | tr '\n' '|' | sed -e 's#| ##g' | tr '|' '\n' | grep "^Plugin-Dependencies: " | sed -e 's#^Plugin-Dependencies: ##')"

    # if [[ ! $dependencies ]]; then
    #     echo " > $plugin has no dependencies"
    #     return
    # fi

    # echo " > $plugin depends on $dependencies"

    # IFS=',' read -r -a array <<< "$dependencies"

    # for d in "${array[@]}"
    # do
    #     plugin="$(cut -d':' -f1 - <<< "$d")"
    #     if [[ $d == *"resolution:=optional"* ]]; then
    #         echo "Skipping optional dependency $plugin"
    #     else
    #         local pluginInstalled
    #         if pluginInstalled="$(echo -e "${bundledPlugins}\n${installedPlugins}" | grep "^${plugin}:")"; then
    #             pluginInstalled="${pluginInstalled//[$'\r']}"
    #             local versionInstalled; versionInstalled=$(versionFromPlugin "${pluginInstalled}")
    #             local minVersion; minVersion=$(versionFromPlugin "${d}")
    #             if versionLT "${versionInstalled}" "${minVersion}"; then
    #                 echo "Upgrading bundled dependency $d ($minVersion > $versionInstalled)"
    #                 download "$plugin" &
    #             else
    #                 echo "Skipping already installed dependency $d ($minVersion <= $versionInstalled)"
    #             fi
    #         else
    #             download "$plugin" &
    #         fi
    #     fi
    # done
    # wait
}

function Get-BundledPlugins {
    $JENKINS_WAR='C:/ProgramData/Jenkins/jenkins.war'
    $bundled = @()
    if(Test-Path $JENKINS_WAR) {
        $TEMP_PLUGIN_DIR="$env:TEMP/plugintemp.`$"
        foreach($i in (jar tf $JENKINS_WAR | where {$_ -match '[detached-]plugins.*\..pi'} | sort)) {
            if(Test-Path $TEMP_PLUGIN_DIR) {
                rm -Recurse -Force $TEMP_PLUGIN_DIR
            }
            mkdir -p $TEMP_PLUGIN_DIR | Out-Null
            $PLUGIN=[System.IO.Path]::GetFileNameWithoutExtension($i)
            pushd -StackName 'install-plugins' $TEMP_PLUGIN_DIR
            jar xf "$JENKINS_WAR" "$i"
            jar xvf "$TEMP_PLUGIN_DIR/$i" META-INF/MANIFEST.MF | Out-Null
            popd -StackName 'install-plugins'
            $VER=Get-Content "$TEMP_PLUGIN_DIR/META-INF/MANIFEST.MF" | where {$_ -match 'plugin-version' } | %{$_ -split ':' } | select -last 1 | %{$_.Trim()}
            $bundled += "$($PLUGIN):$($VER)"
        }
        rm -Recurse -Force $TEMP_PLUGIN_DIR
    } else {
        Write-Host "war not found, installing all plugins: $JENKINS_WAR"
    }
    return $bundled
}

function Get-VersionFromPlugin($plugin) {
    if($plugin -match ".*:.*") {
        return $plugin.Split(':')[1]
    }
    return "latest"
}

function Get-InstalledPlugins {
    $installed = @()
    foreach($f in (gci $REF_DIR -Recurse -Include *.jpi)) {
        $installed += "$((Get-Item $f).Basename):$(Get-PluginVersion $f)"
    }
    return $installed
}

function Get-JenkinsMajorMinorVersion() {
    $JENKINS_WAR='C:/ProgramData/Jenkins/jenkins.war'
    $res = ''
    if(Test-Path $JENKINS_WAR) {
        $version=java -jar $JENKINS_WAR --version
        $major = ([version]$version).Major
        $minor = ([version]$version).Minor
        $res = "$major.$minor"
    } 
    return $res
}

$plugins=@()

mkdir -p "$REF_DIR"
if(-not (Test-Path $REF_DIR)) {
    exit 1
}

if(Test-Path $FAILED) {
    rm -Force $FAILED
}

# Read plugins from stdin or from the command line arguments
if(Test-Path $args[0]) {
    # we have a plugins.txt type file
    $plugins = Get-Content $args[0] | %{$_.Trim()} | where {$_ -notmatch '^#' -and $_ -notmatch ''}
} else {
    # the plugins are passed as arguments
    $plugins = $args
}

# Create lockfile manually before first run to make sure any explicit version set is used.
Write-Host "Creating initial locks..."
foreach($plugin in $plugins) {
    mkdir $(Get-LockFile $plugin.Split(':')[0])
}

Write-Host "Analyzing war..."
$bundledPlugins = (Get-BundledPlugins)

Write-Host "Registering preinstalled plugins..."
$installedPlugins=Get-InstalledPlugins

# Check if there's a version-specific update center, which is the case for LTS versions
$jenkinsVersion=Get-JenkinsMajorMinorVersion
$JENKINS_UC_LATEST=''
try {
    $res = Invoke-WebRequest -Uri "$($JENKINS_UC)/$($jenkinsVersion)" -TimeoutSec 30 | Out-Null
    if($res.StatusCode -eq 200) {
        $JENKINS_UC_LATEST="$JENKINS_UC/$jenkinsVersion"
        Write-Host "Using version-specific update center: $JENKINS_UC_LATEST..."
    }
} catch {
    # don't do anything...
}

Write-Host "Downloading plugins..."
foreach($plugin in $plugins) {
    $m = [regex]::Match($plugin, '^([^:]+):?([^:]+)?:?([^:]+)?:?(http.+)?')
    if($m.Success) {
        $pluginId = $m.Groups[1].Value
        $version = $m.Groups[2].Value
        $lock = $m.Groups[3].Value
        if([System.String]::IsNullOrWhiteSpace($lock)) {
            $lock = $true
        }
        $url = $m.Groups[4].Value
        #Start-Job -ScriptBlock { Download-Plugin $Input[0] $Input[1] $Input[2] $Input[3] } -InputObject @($pluginId, $version, $lock, $url) | Out-Null
        Download-Plugin $pluginId $version $lock $url
    } else {
      Write-Host "Skipping the line '$plugin' as it does not look like a reference to a plugin"
    }
    break
}

Get-Job | Wait-Job | Out-Null

Write-Host "`nWAR bundled plugins:"
Write-Host "$bundledPlugins"
Write-Host "`nInstalled plugins:"
Write-Host "$installedPlugins"

if(Test-Path $FAILED) {
    Write-Error "Some plugins failed to download! $(Get-Content $FAILED)"
    exit 1
}

Write-Host "Cleaning up locks"
foreach($filepath in (gci $REF_DIR -Recurse -Include "*.lock")) {
    rm -Recurse -Force $filepath
}
