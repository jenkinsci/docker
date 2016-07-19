#!/bin/bash

# Resolve dependencies and download plugins given on the command line
#
# FROM jenkins
# RUN install-plugins.sh docker-slaves github-branch-source

REF_DIR=${REF:-/usr/share/jenkins/ref/plugins}
FAILED="$REF_DIR/failed-plugins.txt"

. /usr/local/bin/jenkins-support

function getLockFile() {
	echo -n "$REF_DIR/${1}.lock"
}

function getArchiveFilename() {
	echo -n "$REF_DIR/${1}.jpi"
}

function download() {
	local plugin originalPlugin version lock ignoreLockFile
	plugin="$1"
	version="${2:-latest}"
	ignoreLockFile="$3"
	lock="$(getLockFile "$plugin")"

	if [[ $ignoreLockFile ]] || mkdir "$lock" &>/dev/null; then
		if ! doDownload "$plugin" "$version"; then
			# some plugin don't follow the rules about artifact ID
			# typically: docker-plugin
			originalPlugin="$plugin"
			plugin="${plugin}-plugin"
			if ! doDownload "$plugin" "$version"; then
				echo "Failed to download plugin: $originalPlugin or $plugin" >&2
				echo "Not downloaded: ${originalPlugin}" >> "$FAILED"
				return 1
			fi
		fi

		if ! checkIntegrity "$plugin"; then
			echo "Downloaded file is not a valid ZIP: $(getArchiveFilename "$plugin")" >&2
			echo "Download integrity: ${plugin}" >> "$FAILED"
			return 1
		fi

		resolveDependencies "$plugin"
	fi
}

function doDownload() {
	local plugin version url jpi
	plugin="$1"
	version="$2"
	jpi="$(getArchiveFilename "$plugin")"

	if [[ -f $jpi ]]; then
		echo "Using provided plugin: $plugin"
		return 0
	fi

	url="$JENKINS_UC/download/plugins/$plugin/$version/${plugin}.hpi"

	echo "Downloading plugin: $plugin from $url"
	curl --connect-timeout 5 --retry 5 --retry-delay 0 --retry-max-time 60 -s -f -L "$url" -o "$jpi"
	return $?
}

function checkIntegrity() {
	local plugin jpi
	plugin="$1"
	jpi="$(getArchiveFilename "$plugin")"

	zip -T "$jpi" >/dev/null
	return $?
}

function resolveDependencies() {	
	local plugin jpi dependencies
	plugin="$1"
	jpi="$(getArchiveFilename "$plugin")"

	# ^M below is a control character, inserted by typing ctrl+v ctrl+m
	dependencies="$(unzip -p "$jpi" META-INF/MANIFEST.MF | sed -e 's###g' | tr '\n' '|' | sed -e 's#| ##g' | tr '|' '\n' | grep "^Plugin-Dependencies: " | sed -e 's#^Plugin-Dependencies: ##')"

	if [[ ! $dependencies ]]; then
		echo " > $plugin has no dependencies"
		return
	fi

	echo " > $plugin depends on $dependencies"

	IFS=',' read -a array <<< "$dependencies"

	for d in "${array[@]}"
	do
		plugin="$(cut -d':' -f1 - <<< "$d")"
		if [[ $d == *"resolution:=optional"* ]]; then	
			echo "Skipping optional dependency $plugin"
		else
			pluginInstalled="$(echo "${bundledPlugins}" | grep "^${plugin}:")"
			pluginInstalled="${pluginInstalled//[$'\r']}"
			if ! [ -z "${pluginInstalled}" ]; then
				versionInstalled=$(versionFromPlugin "${pluginInstalled}")
				versionToInstall=$(versionFromPlugin "${d}")
				if versionLT "${versionInstalled}" "${versionToInstall}"; then
					echo "Upgrading bundled dependency $d ($versionToInstall > $versionInstalled)"
					download "$plugin" "$versionToInstall" &
				else
					echo "Skipping already bundled dependency $d ($versionToInstall <= $versionInstalled)"
				fi
			else
				download "$plugin" "$(versionFromPlugin "${d}")" &
			fi
		fi
	done
	wait
}

function bundledPlugins() {
  local JENKINS_WAR=/usr/share/jenkins/jenkins.war
  if [ -f $JENKINS_WAR ]
  then
      TEMP_PLUGIN_DIR=/tmp/plugintemp.$$
      for i in `jar tf $JENKINS_WAR|egrep 'plugins.*\..pi'|egrep -v '\/$'|sort`
      do
          rm -fr $TEMP_PLUGIN_DIR
          mkdir -p $TEMP_PLUGIN_DIR
          PLUGIN=`basename $i|cut -f1 -d'.'`
          (cd $TEMP_PLUGIN_DIR;jar xf $JENKINS_WAR "$i";jar xvf $TEMP_PLUGIN_DIR/$i META-INF/MANIFEST.MF >/dev/null 2>&1)
          VER=`egrep -i Plugin-Version "$TEMP_PLUGIN_DIR/META-INF/MANIFEST.MF"|cut -d\: -f2|sed 's/ //'`
          echo "$PLUGIN:$VER"
      done
      rm -fr $TEMP_PLUGIN_DIR
  else
      rm -f $TEMP_ALREADY_INSTALLED
      echo "ERROR file not found: $JENKINS_WAR"
      exit 1
  fi
}

function versionFromPlugin() {
	local plugin=$1
	if [[ $plugin =~ .*:.* ]]; then
		echo "${plugin##*:}"
	else
		echo "latest"
	fi

}

main() {
	local plugin version

	mkdir -p "$REF_DIR" || exit 1

	# Create lockfile manually before first run to make sure any explicit version set is used.
	echo "Creating initial locks..."
	for plugin in "$@"; do
		mkdir "$(getLockFile "${plugin%%:*}")"
	done

	echo -e "\nAnalyzing war..."
	bundledPlugins="$(bundledPlugins)"

	echo -e "\nDownloading plugins..."
	for plugin in "$@"; do
		version=""

		if [[ $plugin =~ .*:.* ]]; then
			version=$(versionFromPlugin "${plugin}")
			plugin="${plugin%%:*}"
		fi

		download "$plugin" "$version" "true" &
	done				  
	wait

	if [[ -f $FAILED ]]; then
		echo -e "\nSome plugins failed to download!\n$(<"$FAILED")" >&2
		exit 1
	fi

	echo -e "\nCleaning up locks"
	rm -r "$REF_DIR"/*.lock
}

main "$@"
