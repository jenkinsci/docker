#!/bin/bash

# read JAVA_OPTS into array to avoid need for eval (and associated vulnerabilities)
java_opts_array=()
while IFS= read -r -d '' item; do
	java_opts_array+=( "$item" )
done < <([[ $JAVA_OPTS ]] && xargs printf '%s\0' <<<"$JAVA_OPTS")

exec java "${java_opts_array[@]}" -jar /opt/jenkins-plugin-manager.jar "$@"
