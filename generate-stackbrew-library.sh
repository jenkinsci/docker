#!/usr/local/Cellar/bash/4.3.30/bin/bash
set -e

declare -A aliases
aliases=(
	[1.592]='weekly'
	[1.580.1]='latest'
)

versions=( */ )
versions=( "${versions[@]%/}" )
url='git://github.com/cloudbees/jenkins-ci.org-docker'

echo '# maintainer: Nicolas De Loof <nicolas.deloof@gmail.com> (@ndeloo)'

for version in "${versions[@]}"; do
	commit="$(git log -1 --format='format:%H' -- "$version")"
	versionAliases=( $version ${aliases[$version]} )
	
	echo
	for va in "${versionAliases[@]}"; do
		echo "$va: ${url}@${commit} $version"
	done
done
