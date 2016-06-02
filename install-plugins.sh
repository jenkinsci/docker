#! /bin/bash

# Resolve dependencies and download plugins given on the command line
#
# FROM jenkins
# RUN install-plugins.sh docker-slaves github-branch-source

set -e

REF=${REF:-/usr/share/jenkins/ref/plugins}
mkdir -p "$REF"

function download() {
	local plugin="$1"; shift

	if [[ ! -f "${plugin}.hpi" ]]; then

		local url="${JENKINS_UC}/latest/${plugin}.hpi"
		echo "download plugin : $plugin from $url"

		if ! curl -s -f -L "$url" -o "${plugin}.hpi" 
		then
			# some plugin don't follow the rules about artifact ID
			# typically: docker-plugin
			plugin=${plugin}-plugin

			local url="${JENKINS_UC}/latest/${plugin}.hpi"
			echo "download plugin : $plugin from $url"
			if ! curl -s -f -L "${url}" -o "${plugin}.hpi"
			then
				>&2 echo "failed to download plugin ${plugin}"
				exit -1
			fi
		fi
	else
		echo "$plugin is already downloaded."
	fi	

	if [[ ! -f ${plugin}.resolved ]]; then
		resolveDependencies "$plugin"
	fi
}

function resolveDependencies() {	
	local plugin="$1"; shift

	local dependencies=`jrunscript -e '\
	java.lang.System.out.println(\
		new java.util.jar.JarFile("'${plugin}.hpi'")\
			.getManifest()\
			.getMainAttributes()\
			.getValue("Plugin-Dependencies")\
	);'`

	if [[ "$dependencies" == "null" ]]; then
		echo " > plugin has no dependencies"
		return
	fi

	echo " > depends on  ${dependencies}"

	IFS=',' read -a array <<< "${dependencies}"
    for d in "${array[@]}"
	do
		local p=$(echo $d | cut -d':' -f1 -)
		if [[ $d == *"resolution:=optional"* ]] 
		then	
			echo "skipping optional dependency $p"
		else
			download "$p"
		fi
	done
	touch "${plugin}.resolved"
}

cd "$REF"

for plugin in "$@"
do
    download "$plugin"
done

# cleanup 'resolved' flag files
rm *.resolved
