#!/bin/bash
set -e

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

for version in "${versions[@]}"; do
	rm -rf "$version"/*
	cp Dockerfile.template jenkins.sh plugins.sh init.groovy "$version/"
	mv "$version/Dockerfile.template" "$version/Dockerfile"
    case $version in
		1\.*\.*\.*) download="http:\/\/nectar-downloads.cloudbees.com\/jenkins-enterprise\/${version::5}\/war\/$version\/jenkins.war" ;;
    	1\.*\.*) download="http:\/\/mirrors.jenkins-ci.org\/war-stable\/$version\/jenkins.war" ;;
    	*) download="http:\/\/mirrors.jenkins-ci.org\/war\/$version\/jenkins.war" ;;
	esac

	sed -i "" 's/%%JENKINS_VERSION%%/'$version'/g; s/%%DOWNLOAD_URL%%/'$download'/g' "$version/Dockerfile"
done

