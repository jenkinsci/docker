#! /bin/bash

function download() {
	local plugin=$1; shift

	if [[ ! -f ${plugin}.hpi ]]; then

		url=${JENKINS_UC}/latest/${plugin}.hpi
		echo "download plugin : $plugin from $url"

		curl -s -f -L $url -o ${plugin}.hpi
		if [[ $? -ne 0 ]]
		then
			# some plugin don't follow the rules about artifact ID
			# typically: docker-plugin
			curl -s -f -L $url -o ${plugin}-plugin.hpi
			if [[ $? -ne 0 ]]
			then
				>&2 echo "failed to download plugin ${plugin}"
				exit -1
			fi
		fi
	else
		echo "$plugin is already downloaded."
	fi	

	if [[ ! -f ${plugin}.resolved ]]; then
		resolveDependencies $1
	fi
}

function resolveDependencies() {	
	local plugin=$1; shift

	dependencies=`jrunscript -e '\
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
		plugin=$(echo $d | cut -d':' -f1 -)
		if [[ $d == *"resolution:=optional"* ]] 
		then	
			echo "skipping optional dependency $plugin"
		else
    		download $plugin
		fi
	done
	touch ${plugin}.resolved
}

for plugin in "$@"
do
    download $plugin
done

# cleanup 'resolved' flag files
rm *.resolved
