#! /bin/bash

set -e

# compare if version1 < version2
versionLT() {
	[ "$1" = "$2" ] && return 1 || [  "$1" = "`echo -e "$1\n$2" | sort -V | head -n1`" ]
}

# returns a plugin version from a plugin archive
get_plugin_version() {
	local archive; archive=$1
	local version; version=$(unzip -p $archive META-INF/MANIFEST.MF | grep "^Plugin-Version: " | sed -e 's#^Plugin-Version: ##')
	version=${version%%[[:space:]]}
	echo $version
}

# Copy files from /usr/share/jenkins/ref into $JENKINS_HOME
# So the initial JENKINS-HOME is set with expected content.
# Don't override, as this is just a reference setup, and use from UI
# can then change this, upgrade plugins, etc.
copy_reference_file() {
	f="${1%/}"
	b="${f%.override}"
	rel="${b:23}"
	version_marker="${rel}.version_from_image"
	dir=$(dirname "${b}")
	local action;
	local reason;
	local container_version;
	local image_version;
	local marker_version;
	local log; log=false
	if [[ ${rel} == plugins/*.jpi ]]; then
	    container_version=$(get_plugin_version $JENKINS_HOME/${rel})
        image_version=$(get_plugin_version ${f})
	    if [[ -e $JENKINS_HOME/${version_marker} ]]; then
            marker_version=$(cat $JENKINS_HOME/${version_marker})
            if versionLT $marker_version $container_version; then
                action="SKIPPED"
                reason="Installed version ($container_version) has been manually upgraded from initial version ($marker_version)"
                log=true
            else
                if [[ "$image_version" == "$container_version" ]]; then
                    action="SKIPPED"
                    reason="Version from image is the same as the installed version $image_version"
                else
                    if versionLT $image_version $container_version; then
                        action="SKIPPED"
                        log=true
                        reason="Image version ($image_version) is older than installed version ($container_version)"
                    else
                        action="UPGRADED"
                        log=true
                        reason="Image version ($image_version) is newer than installed version ($container_version)"
                    fi
                fi
            fi
        else
            if [[ -n "$TRY_UPGRADE_IF_NO_MARKER" ]]; then
                if [[ "$image_version" == "$container_version" ]]; then
                    action="SKIPPED"
                    reason="Version from image is the same as the installed version $image_version (no marker found)"
                    # Add marker for next time
                    echo $image_version > $JENKINS_HOME/${version_marker}
                else
                    if versionLT $image_version $container_version; then
                        action="SKIPPED"
                        log=true
                        reason="Image version ($image_version) is older than installed version ($container_version) (no marker found)"
                    else
                        action="UPGRADED"
                        log=true
                        reason="Image version ($image_version) is newer than installed version ($container_version) (no marker found)"
                    fi
                fi
            fi
		fi
        if [[ ! -e $JENKINS_HOME/${rel} || "$action" == "UPGRADED" || $f = *.override ]]; then
            action=${action:-"INSTALLED"}
            log=true
            mkdir -p "$JENKINS_HOME/${dir:23}"
            cp -r "${f}" "$JENKINS_HOME/${rel}";
		    # pin plugins on initial copy
		    touch "$JENKINS_HOME/${rel}.pinned"
            echo $image_version > $JENKINS_HOME/${version_marker}
            reason=${reason:-$image_version}
        else
            action=${action:-"SKIPPED"}
	    fi
    else
        if [[ ! -e $JENKINS_HOME/${rel} || $f = *.override ]]
        then
            action="INSTALLED"
            log=true
            mkdir -p "$JENKINS_HOME/${dir:23}"
            cp -r "${f}" "$JENKINS_HOME/${rel}";
        else
            action="SKIPPED"
        fi
	fi
	if [[ -n "$VERBOSE" || "$log" == "true" ]]; then
        if [ -z "$reason" ]; then
            echo "$action $rel" >> "$COPY_REFERENCE_FILE_LOG"
        else
            echo "$action $rel : $reason" >> "$COPY_REFERENCE_FILE_LOG"
        fi
	fi
}
: ${JENKINS_HOME:="/var/jenkins_home"}
export -f versionLT
export -f get_plugin_version
export -f copy_reference_file
touch "${COPY_REFERENCE_FILE_LOG}" || (echo "Can not write to ${COPY_REFERENCE_FILE_LOG}. Wrong volume permissions?" && exit 1)
echo "--- Copying files at $(date)" >> "$COPY_REFERENCE_FILE_LOG"
find /usr/share/jenkins/ref/ -type f -exec bash -c "copy_reference_file '{}'" \;

# if `docker run` first argument start with `--` the user is passing jenkins launcher arguments
if [[ $# -lt 1 ]] || [[ "$1" == "--"* ]]; then
  eval "exec java $JAVA_OPTS -jar /usr/share/jenkins/jenkins.war $JENKINS_OPTS \"\$@\""
fi

# As argument is not jenkins, assume user want to run his own process, for sample a `bash` shell to explore this image
exec "$@"
