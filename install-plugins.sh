#!/bin/bash -eu

# Resolve dependencies and download plugins given on the command line
#
# FROM jenkins
# RUN install-plugins.sh docker-slaves github-branch-source
#
# Environment variables:
# REF: directory with preinstalled plugins. Default: /usr/share/jenkins/ref/plugins
# JENKINS_WAR: full path to the jenkins.war. Default: /usr/share/jenkins/jenkins.war
# JENKINS_UC: url of the Update Center. Default: ""
# JENKINS_UC_EXPERIMENTAL: url of the Experimental Update Center for experimental versions of plugins. Default: ""
# JENKINS_INCREMENTALS_REPO_MIRROR: url of the incrementals repo mirror. Default: ""
# JENKINS_UC_DOWNLOAD: download url of the Update Center. Default: JENKINS_UC/download

set -o pipefail

main() {
    local plugin
    local plugins=()
    local args=()

    if [[ -v JENKINS_WAR ]] ; then
      args+=("--war ${JENKINS_WAR}")
    fi 

    if [[ -v JENKINS_UC ]] ; then
      args+=("")  
    fi

    # Read plugins from stdin or from the command line arguments
    if [[ ($# -eq 0) ]]; then
        while read -r line || [ "$line" != "" ]; do
            # Remove leading/trailing spaces, comments, and empty lines
            plugin=$(echo "${line}" | tr -d '\r' | sed -e 's/^[ \t]*//g' -e 's/[ \t]*$//g' -e 's/[ \t]*#.*$//g' -e '/^[ \t]*$/d')

            # Avoid adding empty plugin into array
            if [ ${#plugin} -ne 0 ]; then
                plugins+=("${plugin}")
            fi
        done
    else
        plugins=("$@")
    fi

    declare -A mappings=( [docker]='docker-plugin' )

    for key in "${!mappings[@]}" ; do
        for i in "${!plugins[@]}" ; do
            if [[ "${plugins[$i]}" =~ ^${key}: ]] ; then
                local replacement="${mappings[$key]}"
                local haystack="${plugins[$i]}"
                plugins[$i]=${haystack/$key/$replacement}
            fi
        done
    done    

    if [[ -f "${plugins[0]}" ]] ; then
      jenkins-plugin-cli --list --verbose "${args[*]}" --plugin-file "${plugins[0]}"
    else
      jenkins-plugin-cli --list --verbose "${args[*]}" --plugins "${plugins[*]}"
    fi
}

main "$@"
