
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

# Copy files from /usr/share/jenkins/ref into $JENKINS_HOME
# So the initial JENKINS-HOME is set with expected content.
# Don't override, as this is just a reference setup, and use from UI
# can then change this, upgrade plugins, etc.
function Copy-ReferenceFile($file) {
    Write-Host "Copy-ReferenceFile - $file"
    # f="${1%/}"
    # b="${f%.override}"
    # rel="${b:23}"
    # version_marker="${rel}.version_from_image"
    # dir=$(dirname "${b}")
    # $log=$false
    # if [[ ${rel} == plugins/*.jpi ]]; then
    #     container_version=$(get_plugin_version "$JENKINS_HOME/${rel}")
    #     image_version=$(get_plugin_version "${f}")
    #     if [[ -e $JENKINS_HOME/${version_marker} ]]; then
    #         marker_version=$(cat "$JENKINS_HOME/${version_marker}")
    #         if versionLT "$marker_version" "$container_version"; then
    #             if ( versionLT "$container_version" "$image_version" && [[ -n $PLUGINS_FORCE_UPGRADE ]]); then
    #                 action="UPGRADED"
    #                 reason="Manually upgraded version ($container_version) is older than image version $image_version"
    #                 log=true
    #             else
    #                 action="SKIPPED"
    #                 reason="Installed version ($container_version) has been manually upgraded from initial version ($marker_version)"
    #                 log=true
    #             fi
    #         else
    #             if [[ "$image_version" == "$container_version" ]]; then
    #                 action="SKIPPED"
    #                 reason="Version from image is the same as the installed version $image_version"
    #             else
    #                 if versionLT "$image_version" "$container_version"; then
    #                     action="SKIPPED"
    #                     log=true
    #                     reason="Image version ($image_version) is older than installed version ($container_version)"
    #                 else
    #                     action="UPGRADED"
    #                     log=true
    #                     reason="Image version ($image_version) is newer than installed version ($container_version)"
    #                 fi
    #             fi
    #         fi
    #     else
    #         if [[ -n "$TRY_UPGRADE_IF_NO_MARKER" ]]; then
    #             if [[ "$image_version" == "$container_version" ]]; then
    #                 action="SKIPPED"
    #                 reason="Version from image is the same as the installed version $image_version (no marker found)"
    #                 # Add marker for next time
    #                 echo "$image_version" > "$JENKINS_HOME/${version_marker}"
    #             else
    #                 if versionLT "$image_version" "$container_version"; then
    #                     action="SKIPPED"
    #                     log=true
    #                     reason="Image version ($image_version) is older than installed version ($container_version) (no marker found)"
    #                 else
    #                     action="UPGRADED"
    #                     log=true
    #                     reason="Image version ($image_version) is newer than installed version ($container_version) (no marker found)"
    #                 fi
    #             fi
    #         fi
    #     fi
    #     if [[ ! -e $JENKINS_HOME/${rel} || "$action" == "UPGRADED" || $f = *.override ]]; then
    #         action=${action:-"INSTALLED"}
    #         log=true
    #         mkdir -p "$JENKINS_HOME/${dir:23}"
    #         cp -pr "${f}" "$JENKINS_HOME/${rel}";
    #         # pin plugins on initial copy
    #         touch "$JENKINS_HOME/${rel}.pinned"
    #         echo "$image_version" > "$JENKINS_HOME/${version_marker}"
    #         reason=${reason:-$image_version}
    #     else
    #         action=${action:-"SKIPPED"}
    #     fi
    # else
    #     if [[ ! -e $JENKINS_HOME/${rel} || $f = *.override ]]
    #     then
    #         action="INSTALLED"
    #         log=true
    #         mkdir -p "$JENKINS_HOME/${dir:23}"
    #         cp -pr "$(realpath "${f}")" "$JENKINS_HOME/${rel}";
    #     else
    #         action="SKIPPED"
    #     fi
    # fi
    # if [[ -n "$VERBOSE" || "$log" == "true" ]]; then
    #     if [ -z "$reason" ]; then
    #         echo "$action $rel" >> "$COPY_REFERENCE_FILE_LOG"
    #     else
    #         echo "$action $rel : $reason" >> "$COPY_REFERENCE_FILE_LOG"
    #     fi
    # fi
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
