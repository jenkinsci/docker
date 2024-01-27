#!/bin/bash
# This script checks that the provided JDK version has all the required binaries available for downloads
# as sometimes, the tag for adoptium is published immeidatly while binaries are published later.
##
# The source of truth is the ERB template stored at the location dist/profile/templates/jenkinscontroller/casc/tools.yaml.erb
# It lists all the installations used as "Jenkins Tools" by the Jenkins controllers of the infrastructure
##
set -eu -o pipefail

command -v curl >/dev/null 2>&1 || { echo "ERROR: curl command not found. Exiting."; exit 1; }

function get_jdk_download_url() {
  jdk_version="${1}"
  platform="${2}"
  case "${jdk_version}" in
    8*)
      ## JDK8 does not have the carret ('-') in their archive names
      echo "https://github.com/adoptium/temurin8-binaries/releases/download/jdk${jdk_version}/OpenJDK8U-jdk_${platform}_hotspot_${jdk_version//-}";
      return 0;;
    11*)
      ## JDK11 URLs have an underscore ('_') instead of a plus ('+') in their archive names
      echo "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-${jdk_version}/OpenJDK11U-jdk_${platform}_hotspot_${jdk_version//+/_}";
      return 0;;
    17*)
      ## JDK17 URLs have an underscore ('_') instead of a plus ('+') in their archive names
      echo "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-${jdk_version}/OpenJDK17U-jdk_${platform}_hotspot_${jdk_version//+/_}";
      return 0;;
    19*)
      ## JDK19 URLs have an underscore ('_') instead of a plus ('+') in their archive names
      echo "https://github.com/adoptium/temurin19-binaries/releases/download/jdk-${jdk_version}/OpenJDK19U-jdk_${platform}_hotspot_${jdk_version//+/_}";
      return 0;;
    21*-ea-beta)
      # JDK preview version (21+35-ea-beta, 21.0.1+12-ea-beta)
      jdk_version="${jdk_version//-ea-beta}"
      ##    https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21%2B35-ea-beta/OpenJDK21U-jdk_aarch64_linux_hotspot_ea_21-0-35.tar.gz
      ##    https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.1%2B12-ea-beta/OpenJDK21U-jdk_x64_linux_hotspot_ea_21-0-1-12.tar.gz
      dashJDKVersion="${jdk_version//+/-}"
      completeDashJDKVersion="${dashJDKVersion//./-}"
      echo "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${jdk_version//+/%2B}-ea-beta/OpenJDK21U-jdk_${platform}_hotspot_ea_${completeDashJDKVersion}"
      return 0;;
    21*)
      ## JDK21 URLs have an underscore ('_') instead of a plus ('+') in their archive names
      echo "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${jdk_version}/OpenJDK21U-jdk_${platform}_hotspot_${jdk_version//+/_}";
      return 0;;
    *)
      echo "ERROR: unsupported JDK version (${jdk_version}).";
      exit 1;;
  esac
}

case "${1}" in
  8u*)
    # No s390x support for JDK8: $platforms is kept as default
    platforms=("x64_linux" "x64_windows" "aarch64_linux");;
  11.*)
    platforms=("x64_linux" "x64_windows" "aarch64_linux" "s390x_linux");;
  17.*+*)
    platforms=("x64_linux" "x64_windows" "aarch64_linux" "s390x_linux");;
  19.*+*)
    platforms=("x64_linux" "x64_windows" "aarch64_linux" "s390x_linux");;
  21*+*-ea-beta)
    platforms=("x64_linux" "x64_windows" "aarch64_linux" "s390x_linux");;
  21*+*)
    platforms=("x64_linux" "x64_windows" "aarch64_linux");;
  *)
    echo "ERROR: unsupported JDK version (${1}).";
    exit 1;;
esac

for platform in "${platforms[@]}"
do
  url_to_check="$(get_jdk_download_url "${1}" "${platform}")"
  if [[ "${platform}" == *windows* ]]
  then
    url_to_check+=".zip"
  else
    url_to_check+=".tar.gz"
  fi
  >&2 curl --connect-timeout 5 --location --head --fail --silent "${url_to_check}" || { echo "ERROR: the following URL is NOT available: ${url_to_check}."; exit 1; }
done

echo "OK: all JDK URL for version=${1} are available."
