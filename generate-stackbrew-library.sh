#!/bin/bash

set -e
shopt -s extglob

declare -A aliases
aliases=(
	[1.605]='weekly'
	[1.596.1]='latest'
)

versions() {
	local IFS=$'\n'
	local versions=( "${@%/}" )
	sort -Vr <<< "${versions[*]}"
}

lts_versions=( $(versions *.*.*/) )
weekly_versions=( $(versions !(*.*.*)/) )
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
for version in "${lts_versions[@]}"; do
	if [ "${aliases[$version]}" ]; then
		continue
	fi

	commit="$(git log -1 --format='format:%H' -- "$version")"
	echo "$version: ${url}@${commit} $version"
done
echo

echo "# group: Previous Weekly Releases"
for version in "${weekly_versions[@]}"; do
	if [ "${aliases[$version]}" ]; then
		continue
	fi

	commit="$(git log -1 --format='format:%H' -- "$version")"
	echo "$version: ${url}@${commit} $version"
done
