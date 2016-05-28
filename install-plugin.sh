#! /bin/sh

function download() {
	plugin=$1

	if [[ ! -f ${plugin}.hpi ]]; then

		url=http://updates.jenkins-ci.org/latest/${plugin}.hpi
		echo "download plugin : $plugin from $url"

		curl -s -f -L $url -o ${plugin}.hpi
		if [[ $? -ne 0 ]]
		then
			>&2 echo "failed to download plugin ${plugin}"
			exit -1
		fi
	else
		echo "$plugin is allready downloaded."
	fi	
	resolveDependencies $1
}

function resolveDependencies() {	
	plugin=$1

	dependencies=`jrunscript -e 'java.lang.System.out.println(new java.util.jar.JarFile("'${plugin}.hpi'").getManifest().getMainAttributes().getValue("Plugin-Dependencies"));'`

	if [[ "$dependencies" == "null" ]]; then
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
}


download $1           
