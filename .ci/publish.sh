#!/bin/bash -eu
set -eou pipefail

source ./.ci/common-functions.sh > /dev/null 2>&1

# Image Wrapper
build_image() {
    local file_path=$1
    local jenkins_version=$2
    local jenkins_sha=$3
    local dry_run=$4
    local force=$5

    if [ ! "$dry_run" = true ]; then
        dry_run=""
    else
        dry_run="-n"
    fi

    if [ ! "$force" = true ]; then
        force=""
    else
        force="--force"
    fi

    echo "Calling publish-images.sh with the following command: publish-images.sh -f ${file_path} -i jenkins -t ${jenkins_version}-$(get_list_of_docker_images ${file_path}) -a "JENKINS_VERSION=${jenkins_version} JENKINS_SHA=${jenkins_sha}" -b "--no-cache --pull" -c . ${dry_run} ${force} ....."
    .ci/publish-images.sh -f ${file_path} -i jenkins -t ${jenkins_version}-$(get_list_of_docker_images ${file_path}) -a "JENKINS_VERSION=${jenkins_version} JENKINS_SHA=${jenkins_sha}" -b "--no-cache --pull" -c . ${dry_run} ${force}
    echo -e "\n\nFinished building jenkins:${jenkins_version}-$(get_list_of_docker_images ${file_path})!"
}

build_images() {
    local os_name=$1
    local jdk_version=$2
    local jvm=$3
    local start_after=$4
    local dry_run=$5
    local force=$6

    echo "Grabbing all Dockerfiles on disk....."
    dockerfile_list=$(filter_dockerfile_list "${os_name}" "${jdk_version}" "${jvm}" "$(get_all_dockerfiles)")
    echo "Dockerfiles that need to be processed: ${dockerfile_list}"

    echo "Grabbing list of Jenkins versions...."
    version_list=$(get-last-x-jenkins-versions ${JENKINS_VERSION_DEPTH})

    # Filter the list if start after is set
    if [ -n "${start_after}" ]; then
        version_list=$(filter_version_list ${start_after} "${version_list}")
    fi

    echo "Jenkins versions the need to be processed: ${version_list}"

    # Loop through all the filtered Dockerfiles to be processed
    for FILE in ${dockerfile_list}; do
        echo "Processing Dockerfile: ${FILE}"
        arch=$(docker-get-arch)
        valid_os_and_arch=true

        # Check if the current architecture and OS are valid
        for OS in ${!arch}; do
            if [[ ${FILE} == *"${OS}"* ]]; then
                valid_os_and_arch=false
            fi
        done

        if [[ ${valid_os_and_arch} = true ]]; then
            echo "Dockerfile has a valid OS and arch combination!"
            for VERSION in ${version_list}; do
                jenkins_sha=$(get-jenkins-version-sha ${VERSION})

                build_image ${FILE} ${VERSION} ${jenkins_sha} ${dry_run} ${force}
            done
        else
            echo "The following Dockerfile was not a valid option for the OS and arch(${arch}): ${FILE}"
        fi
    done
}

# Tag Wrapper
tag_image() {
    local image_name=$1
    local tags=$2
    local dry_run=$3
    local force=$4

    if [ ! "$dry_run" = true ]; then
        dry_run=""
    else
        dry_run="-n"
    fi

    if [ ! "$force" = true ]; then
        force=""
    else
        force="--force"
    fi

    echo "Calling publish-tag.sh with the following command: .ci/publish-tag.sh -i "${image_name}" -t "${tags}" ${dry_run} ${force}"
    .ci/publish-tags.sh -i "${image_name}" -t "${tags}" ${dry_run} ${force}
    echo -e "\nFinished tagging ${image_name}!\n\n"
}

tag_images() {
    local os_name=$1
    local jdk_version=$2
    local jvm=$3
    local start_after=$4
    local dry_run=$5
    local force=$6

    echo "Grabbing all Dockerfiles on disk....."
    dockerfile_list=$(filter_dockerfile_list "${os_name}" "${jdk_version}" "${jvm}" "$(get_all_dockerfiles)")
    echo "Dockerfiles that need to be processed: ${dockerfile_list}"

    echo "Grabbing list of Jenkins versions...."
    version_list=$(get-last-x-jenkins-versions ${JENKINS_VERSION_DEPTH})

    # Filter the list if start after is set
    if [ -n "${start_after}" ]; then
        version_list=$(filter_version_list "${start_after}" "${version_list}")
    fi

    echo "Grabbing LTS version in list...."
    lts_version=$(find-latest-lts-jenkins-version "${version_list}")
    echo "Latest LTS version: ${lts_version}"

    echo "Grabbing latest version in list..."
    latest_version=$(find-latest-jenkins-version "${version_list}")
    echo "Latest version: ${latest_version}"

    echo "Jenkins versions the need to be processed: ${version_list}"

    # Loop through all the filtered Dockerfiles to be processed
    for FILE in ${dockerfile_list}; do
        echo "Processing Dockerfile: ${FILE}"
        arch=$(docker-get-arch)
        valid_os_and_arch=true

        # Check if the current architecture and OS are valid
        for OS in ${!arch}; do
            if [[ ${FILE} == *"${OS}"* ]]; then
                valid_os_and_arch=false
            fi
        done

        if [[ ${valid_os_and_arch} = true ]]; then
            echo "Dockerfile has a valid OS and arch combination!"
            for VERSION in ${version_list}; do
                echo "Generating all the tags for the image......"
                tags=$(get_tags "${FILE}" "${VERSION}" "${lts_version}" "${latest_version}" "${default_image}" "${jdk11_image}")
                echo "Tags needing to be processed: ${tags}"

                tag_image "jenkins:${VERSION}-$(get_list_of_docker_images ${FILE})" "${tags}" "${DRY_RUN}" "${FORCE}"
            done
        else
            echo "The following Dockerfile was not a valid option for the OS and arch(${arch}): ${FILE}"
        fi
    done
}

# Manifest Wrapper
build-manifest() {
    local manifest_name=$1
    local image_name=$2
    local supported_archs=$3
    local dry_run=$4

    if [ ! "$dry_run" = true ]; then
        dry_run=""
    else
        dry_run="-n"
    fi

    echo "Calling publish-manifest.sh with the following command: .ci/publish-manifest.sh -m "${manifest_name}" -i "${image_name}" -a "${supported_archs}" ${dry_run}"
    .ci/publish-manifests.sh -m "${manifest_name}" -i "${image_name}" -a "${supported_archs}" ${dry_run}
    echo -e "\nFinished building manifest for ${manifest_name}!\n\n"

}

build-manifests() {
    local os_name=$1
    local jdk_version=$2
    local jvm=$3
    local start_after=$4
    local dry_run=$5

    echo "Grabbing all Dockerfiles on disk....."
    dockerfile_list=$(filter_dockerfile_list "${os_name}" "${jdk_version}" "${jvm}" "$(get_all_dockerfiles)")
    echo "Dockerfiles that need to be processed: ${dockerfile_list}"

    echo "Grabbing list of Jenkins versions...."
    version_list=$(get-last-x-jenkins-versions ${JENKINS_VERSION_DEPTH})

    # Filter the list if start after is set
    if [ -n "${start_after}" ]; then
        version_list=$(filter_version_list "${start_after}" "${version_list}")
    fi

    echo "Grabbing LTS version in list...."
    lts_version=$(find-latest-lts-jenkins-version "${version_list}")
    echo "Latest LTS version: ${lts_version}"

    echo "Grabbing latest version in list..."
    latest_version=$(find-latest-jenkins-version "${version_list}")
    echo "Latest version: ${latest_version}"

    echo "Jenkins versions the need to be processed: ${version_list}"

    # Loop through all the filtered Dockerfiles to be processed
    for FILE in ${dockerfile_list}; do
        echo "Processing Dockerfile: ${FILE}"

        echo "Processing supported archs...."
        archs="amd64 amr64 s390x ppc64le"
        supported_archs=""

        # Loop through all archs and see if there is a conflict. If not add them to supported_arch var
        for arch in ${archs}; do
            valid_os_and_arch=true
            for OS in ${!arch}; do
                if [[ ${FILE} == *"${OS}"* ]]; then
                    valid_os_and_arch=false
                fi
            done

            if [[ ${valid_os_and_arch} = true ]]; then
                supported_archs="${supported_archs} ${arch}"
            fi
        done

        echo "Supported archs for ${FILE}: ${supported_archs}"

        # Loop through all versions and process them
        for VERSION in ${version_list}; do
            echo "Generating all the tags for the image......"
            tags=$(get_tags "${FILE}" "${VERSION}" "${lts_version}" "${latest_version}" "${default_image}" "${jdk11_image}")
            # Adding in base verbose tag
            tags="${tags} ${VERSION}-$(get_list_of_docker_images ${FILE})"
            echo "Tags needing to be processed: ${tags}"

            # Loop through all tags and build manifest
            for tag in ${tags};do
                build-manifest "jenkins:${tag}" "jenkins:${tag}" "${supported_archs}" "${DRY_RUN}"
            done
        done
    done
}

# Configs

# List OSs to exclude from a given arch
# ARCH-NAME="PARTIAL-DOCKERFILE-PATH OS-NAME ......"
amd64="clefos"
amr64="clefos alpine debian/stretch 8/ubuntu/bionic/openj9"
s390x="centos alpine debian/stretch/hotspot"
ppc64le="clefos alpine debian/stretch/hotspot"

# Default values to tag an image with the OS tag
# OS-NAME="OS-VERSION JVM JDK-VERSION"
alpine="3.12 hotspot 8"
centos="8 hotspot 8"
debian="buster hotspot 8"
ubuntu="bionic openj9 8"

# Default Image
# default_image="OS-NAME OS-VERSION JVM JDK-VERSION"
default_image="debian buster hotspot 8"

# JDK11 Image
# jdk11_image="OS-NAME OS-VERSION JVM JDK-VERSION"
jdk11_image="debian buster hotspot 11"

# Inputs
JENKINS_VERSION_DEPTH=30 # The default number of Jenkins versions to fetch
PUBLISH=""               # The item(image, tag, manifest) to be published
OS_NAME=""               # The name of the OS you want to build for
JDK_VERSIONS=""          # The JDK versions you want to build for
JVM=""                   # The JVM options you want to build for
START_AFTER=""           # Only build images after a certain Jenkins version
DRY_RUN=false            # Builds the images but does not push/publish them
DEBUG=false              # Turns on verbose output
FORCE=false              # Will push/publish no matter what (Will override the dry run flag). Helpful when vulnerabilities are identified and need to push patches

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --publish)
    PUBLISH=$2
    shift
    ;;
    --os-name)
    OS_NAME=$2
    shift
    ;;
    --jdk)
    JDK_VERSIONS=$2
    shift
    ;;
    --jvm)
    JVM=$2
    shift
    ;;
    --start-after)
    START_AFTER=$2
    shift
    ;;
    --debug)
    DEBUG=true
    ;;
    --force)
    FORCE=true
    ;;
    --dry-run)
    DRY_RUN=true
    ;;
    *)
    echo "Unknown option: $key"
    return 1
    ;;
  esac
  shift
done


if [[ "$DRY_RUN" = true ]]; then
    echo "Dry run enabled, will not publish object"
fi

if [[ "$DEBUG" = true ]]; then
    set -x
fi

# Process what the user wants to build
if [[ "${PUBLISH}" == "images" ]]; then
    build_images "${OS_NAME}" "${JDK_VERSIONS}" "${JVM}" "${START_AFTER}" "${DRY_RUN}" "${FORCE}"
elif [[ "${PUBLISH}" == "tags" ]]; then
    tag_images "${OS_NAME}" "${JDK_VERSIONS}" "${JVM}" "${START_AFTER}" "${DRY_RUN}" "${FORCE}"
elif [[ "${PUBLISH}" == "manifests" ]]; then
    build-manifests "${OS_NAME}" "${JDK_VERSIONS}" "${JVM}" "${START_AFTER}" "${DRY_RUN}"
else
    echo "Publish parameter must be set to one of the following: images, tags or manifests!"
fi