#!/bin/bash

# Read JAVA_OPTS into array to avoid the need for eval and handle spaces correctly
read -r -a java_opts_array <<<"$JAVA_OPTS"

# Execute the Java program
exec java "${java_opts_array[@]}" -jar /opt/jenkins-plugin-manager.jar "$@"

