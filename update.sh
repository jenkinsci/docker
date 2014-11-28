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
	sed -i "" 's/%%JENKINS_VERSION%%/'$version'/g; s/%%JENKINS_VERSION%%/'$version'/g' "$version/Dockerfile"
done

