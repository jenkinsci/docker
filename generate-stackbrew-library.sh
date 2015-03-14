#!/bin/bash
set -e

declare -A aliases
aliases=(
	[1.600]='weekly'
	[1.580.3]='latest'
)

versions=( */ )
versions=( "${versions[@]%/}" )
versions=( $(IFS=$'\n'; sort -Vr <<< "${versions[*]}") )
url='git://github.com/cloudbees/jenkins-ci.org-docker'

echo '# maintainer: Nicolas De Loof <nicolas.deloof@gmail.com> (@ndeloof)'
echo '# maintainer: Michael Neale <mneale@cloudbees.com> (@michaelneale)'

echo
echo "# group: Current Releases"
for current in $(IFS=$'\n'; sort -V <<< "${!aliases[*]}"); do
	commit="$(git log -1 --format='format:%H' -- "$current")"
	for va in "$current" ${aliases[$current]}; do
		echo "$va: ${url}@${commit} $version"
	done
	echo
done

echo "# group: Previous LTS Releases"
for version in "${versions[@]}"; do
	if [[ "${aliases[$version]}" || "$version" != *.*.* ]]; then
		continue
	fi

	commit="$(git log -1 --format='format:%H' -- "$version")"
	echo "$version: ${url}@${commit} $version"
done
echo

echo "# group: Previous Weekly Releases"
for version in "${versions[@]}"; do
	if [[ "${aliases[$version]}" || "$version" == *.*.* ]]; then
		continue
	fi

	commit="$(git log -1 --format='format:%H' -- "$version")"
	echo "$version: ${url}@${commit} $version"
done
