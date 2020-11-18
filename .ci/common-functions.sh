docker-login() {
    # Making use of the credentials stored in `config.json`
    docker login
    echo "Docker logged in successfully"
}

docker-enable-experimental() {
    # Enables experimental to utilize `docker manifest` command
    echo "Enabling Docker experimental...."
    export DOCKER_CLI_EXPERIMENTAL="enabled"
}

docker-get-arch() {
    # Uses Docker to get the correct arch
    echo $(docker version -f {{.Server.Arch}})
}

get-local-digest() {
    # Gets the SHA digest of a local image
    local image=$1
    docker inspect --format="{{.Id}}" ${image}
}

get-remote-digest() {
    local image=$1
    docker manifest inspect ${image} | grep -A 10 "config.*" | grep digest | head -1 | cut -d':' -f 2,3 | xargs echo
}

get-digest() {
    local image=$1
    local digest_version=$2

    if [[ "${digest_version}" == "local" ]]; then
        echo $(get-local-digest "${image}")
    elif [[ "${digest_version}" == "remote" ]]; then
        echo $(get-remote-digest "${image}")
    fi
}

compare-digests() {
    local image_1=$1
    local image_2=$2
    local digest_type_1=$3
    local digest_type_2=$4

    # Grabs both digest SHAs
    digest_1=$(get-digest "${image_1}" "${digest_type_1}")
    digest_2=$(get-digest "${image_2}" "${digest_type_2}")

    if [[ "$DEBUG" = true ]]; then
        >&2 echo "DEBUG: Digest 1 ("${digest_type_1}") for ${image_1}: ${digest_1}"
        >&2 echo "DEBUG: Digest 2 ("${digest_type_2}") for ${image_2}: ${digest_2}"
    fi

    # Compare digest SHAs
    if [[ "${digest_1}" == "${digest_2}" ]]; then
        true
    else
        false
    fi
}

get_all_dockerfiles() {
    # Grabs a list of file paths of all the Dockerfiles
    echo $(find . -not -path '**/windows/*' -not -path './tests/*' -type f -name Dockerfile)
}

sort-versions() {
    if [[ "$(uname)" == 'Darwin' ]]; then
        gsort --version-sort
    else
        sort --version-sort
    fi
}

get-jenkins-version-sha() {
    # Grabs the SHA256 of a given Jenkins version
    local version=$1
    curl -q -fsSL "https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/${version}/jenkins-war-${version}.war.sha256"
}

get-last-x-jenkins-versions() {
    # Grab the X(a number) versions of Jenkins
    local x=$1
    curl -q -fsSL https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/maven-metadata.xml | grep '<version>.*</version>' | grep -E -o '[0-9]+(\.[0-9]+)+' | sort-versions | uniq | tail -n ${x}
}

versionLT() {
    # Checks if the Jenkins version is larger than
    local v1; v1=$(echo "$1" | cut -d '-' -f 1 )
    local q1; q1=$(echo "$1" | cut -s -d '-' -f 2- )
    local v2; v2=$(echo "$2" | cut -d '-' -f 1 )
    local q2; q2=$(echo "$2" | cut -s -d '-' -f 2- )
    if [ "$v1" = "$v2" ]; then
        if [ "$q1" = "$q2" ]; then
            return 1
        else
            if [ -z "$q1" ]; then
                return 1
            else
                if [ -z "$q2" ]; then
                    return 0
                else
                    [  "$q1" = "$(echo -e "$q1\n$q2" | sort -V | head -n1)" ]
                fi
            fi
        fi
    else
        [  "$v1" = "$(echo -e "$v1\n$v2" | sort -V | head -n1)" ]
    fi
}

filter_version_list() {
    # Filters the version list to just included the versions the user wants to build for
    local start_after=$1
    local version_list=$2
    local filtered_version_list=""

    for VERSION in ${version_list}; do
        if versionLT "${start_after}" "${VERSION}"; then
            filtered_version_list="${filtered_version_list}\n${VERSION}"
        fi
    done

    echo -e ${filtered_version_list}
}

filter_dockerfile_list() {
    # Filters out any Dockerfiles that no match what the user wants to build
    local os_name=$1
    local jdk_version=$2
    local jvm=$3
    local dockerfile_list=$4
    local filtered_dockerfile_list=""

    # Check if all was passed in for os_name, jdk_version and jvm, if so skip filtering
    if [[ ! ${os_name} == "all" ]] || [[ ! ${jdk_version} == "all" ]] || [[ ! ${jvm} == "all" ]]; then
        # Loop though all Dockerfiles and filter out ones that do match the users options
        for FILE in ${dockerfile_list}; do
            local flag=true

            if [[ ! ${FILE} == *"/${os_name}/"* ]] && [[ ! ${os_name} == "all" ]]; then
                flag=false
            fi

            if [[ ! ${FILE} == *"/${jdk_version}/"* ]] && [[ ! ${jdk_version} == "all" ]]; then
                flag=false
            fi

            if [[ ! ${FILE} == *"/${jvm}/"* ]]  && [[ ! ${jvm} == "all" ]]; then
                flag=false
            fi

            # If flag is set to true then the Dockerfile meets the filter requirements
            if [[ ${flag} = true ]]; then
                filtered_dockerfile_list="${filtered_dockerfile_list} ${FILE}"
            fi
        done
    else
        filtered_dockerfile_list=${dockerfile_list}
    fi

    echo ${filtered_dockerfile_list}
}

get_list_of_docker_images() {
    # Takes in a list list of Dockerfile paths and converts them into their verbose tag
    local list_of_dockerfiles=$1
    local list_of_images=""

    # Loop through all Dockerfiles
    for FILE in ${list_of_dockerfiles}; do
        IFS="/" read -ra image_info <<< "$FILE"

        # Grab the individual parts of the file path
        jdk_version=${image_info[1]}
        os_name=${image_info[2]}
        os_version=${image_info[3]}
        jvm=${image_info[4]}

        list_of_images="${list_of_images} jdk${jdk_version}-${jvm}-${os_name}-${os_version}"
    done

    echo ${list_of_images}
}

find-latest-lts-jenkins-version() {
    local list_of_versions=$1
    version=$(echo "${list_of_versions}" | grep -E -o '^[0-9]+\.[0-9]+\.[0-9]+$' | sort-versions | uniq | tail -n 1)
    echo "${version}"
}

find-latest-jenkins-version() {
    local list_of_versions=$1
    version=$(echo "${list_of_versions}" | sort-versions | uniq | tail -n 1)
    echo "${version}"
}

get_tags() {
    local dockerfile_path=$1
    local jenkins_version=$2
    local lts_version=$3
    local latest_version=$4
    local default_image=$5
    local jdk11_image=$6

    tags=""
    IFS="/" read -ra image_info <<< "${dockerfile_path}"

    # Grab the individual parts of the file path
    jdk_version=${image_info[1]}
    os_name=${image_info[2]}
    os_version=${image_info[3]}
    jvm=${image_info[4]}

    # Split up OS var into parts
    IFS=" " read -ra os_tag_info <<< "${!os_name}"
    os_tag_version=${os_tag_info[0]}
    os_tag_jvm=${os_tag_info[1]}
    os_tag_jdk=${os_tag_info[2]}

    # Split up Default OS var into parts
    IFS=" " read -ra default_image_info <<< "${default_image}"
    default_image_name=${default_image_info[0]}
    default_image_version=${default_image_info[1]}
    default_image_jvm=${default_image_info[2]}
    default_image_jdk=${default_image_info[3]}

    # Delete after JDK11 variant is removed
    # Split up JDK11 var into parts
    IFS=" " read -ra jdk11_image_info <<< "${jdk11_image}"
    jdk11_image_name=${jdk11_image_info[0]}
    jdk11_image_version=${jdk11_image_info[1]}
    jdk11_image_jvm=${jdk11_image_info[2]}
    jdk11_image_jdk=${jdk11_image_info[3]}

    # Delete after JDK11 variant is removed
    # Check if OS info matches JDK11 image info, if so process tags
    if [[ "${os_name}" == "${jdk11_image_name}" ]] && [[ "${os_version}" == "${jdk11_image_version}" ]] && [[ "${jvm}" == "${jdk11_image_jvm}" ]] && [[ "${jdk_version}" == "${jdk11_image_jdk}" ]];then
        tags="${tags} ${jenkins_version}-jdk11"

        # Check if the current Jenkins version is a LTS version
        if [[ -n $(find-latest-lts-jenkins-version "${jenkins_version}") ]]; then
            tags="${tags} ${jenkins_version}-lts-jdk11"
        fi

        # Check if the latest version matches, if so process for OS tags
        if [[ "${jenkins_version}" == "${latest_version}" ]]; then
            tags="${tags} jdk11"
        fi

        # Check if the LTS version matches, if so process LTS tags
        if [[ "${jenkins_version}" == "${lts_version}" ]]; then
            tags="${tags} lts-jdk11"
        fi
    fi

    # Check if OS version matches the OS version, then apply version + OS tag and OS tag
    if [[ "${os_version}" == "${os_tag_version}" ]] && [[ "${jvm}" == "${os_tag_jvm}" ]] && [[ "${jdk_version}" == "${os_tag_jdk}" ]]; then
        tags="${tags} ${jenkins_version}-${os_name}-${os_version}"
        tags="${tags} ${jenkins_version}-${os_name}"

        # Check if the current Jenkins version is a LTS version
        if [[ -n $(find-latest-lts-jenkins-version "${jenkins_version}") ]]; then
            tags="${tags} ${jenkins_version}-lts-${os_name}-${os_version}"
            tags="${tags} ${jenkins_version}-lts-${os_name}"
        fi
    fi

    # Check if the latest version matches, if so process for OS tags
    if [[ "${jenkins_version}" == "${latest_version}" ]]; then
        # If the OS version, JDK, and jvm matches, then apply the OS tag
        if [[ "${os_version}" == "${os_tag_version}" ]] && [[ "${jvm}" == "${os_tag_jvm}" ]] && [[ "${jdk_version}" == "${os_tag_jdk}" ]]; then
            tags="${tags} ${os_name}-${os_version}-${jvm}"
            tags="${tags} ${os_name}"
        fi

        # If the default image info matches, then process for version and latest tag
        if [[ "${os_name}" == "${default_image_name}" ]] && [[ "${os_version}" == "${default_image_version}" ]] && [[ "${jvm}" == "${default_image_jvm}" ]] && [[ "${jdk_version}" == "${default_image_jdk}" ]];then
            tags="${tags} ${jenkins_version}"
            tags="${tags} latest"
        fi
    fi

    # Check if the LTS version matches, if so process LTS tags
    if [[ "${jenkins_version}" == "${lts_version}" ]]; then
        # If the OS version, JDK, and jvm matches, then apply the OS tag
        if [[ "${os_version}" == "${os_tag_version}" ]] && [[ "${jvm}" == "${os_tag_jvm}" ]] && [[ "${jdk_version}" == "${os_tag_jdk}" ]]; then
            tags="${tags} lts-${os_name}-${os_version}"
            tags="${tags} lts-${os_name}"
        fi

        # If the default image info matches, then process for LTS tag
        if [[ "${os_name}" == "${default_image_name}" ]] && [[ "${os_version}" == "${default_image_version}" ]] && [[ "${jvm}" == "${default_image_jvm}" ]] && [[ "${jdk_version}" == "${default_image_jdk}" ]];then
            tags="${tags} lts"
        fi
    fi

    # Return the built tags
    echo "${tags}"
}