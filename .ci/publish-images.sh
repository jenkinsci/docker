#!/bin/bash -eu

# Publish any versions of the docker image not yet pushed to jenkins/jenkins
# Arguments:
#   -n dry run, do not build or publish images
#   -d debug

set -eou pipefail

. jenkins-support

: "${DOCKERHUB_ORGANISATION:=jenkins4eval}"
: "${DOCKERHUB_REPO:=jenkins}"

JENKINS_REPO="${DOCKERHUB_ORGANISATION}/${DOCKERHUB_REPO}"

cat <<EOF
Docker repository in Use:
* JENKINS_REPO: ${JENKINS_REPO}
EOF

#This is precautionary step to avoid accidental push to offical jenkins image
if [[ "$DOCKERHUB_ORGANISATION" == "jenkins" ]]; then
    echo "Experimental docker image should not published to jenkins organization , hence exiting with failure";
    exit 1;
fi

BASEIMAGE=

#login-token() {
#    # could use jq .token
#    curl -q -sSL "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${JENKINS_REPO}:pull" | grep -o '"token":"[^"]*"' | cut -d':' -f 2 | xargs echo
#}

docker-login() {
    docker login --username ${DOCKER_USERNAME} --password-stdin ${DOCKER_PASSWORD}
}

sort-versions() {
    if [ "$(uname)" == 'Darwin' ]; then
        gsort --version-sort
    else
        sort --version-sort
    fi
}

get-latest-versions() {
    curl -q -fsSL https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/maven-metadata.xml | grep '<version>.*</version>' | grep -E -o '[0-9]+(\.[0-9]+)+' | sort-versions | uniq | tail -n 5
}

is-published() {
    local tag=$1
    local opts=""
    if [ "$debug" = true ]; then
        opts="-v"
    fi
    local http_code;
    #http_code=$(curl $opts -q -fsL -o /dev/null -w "%{http_code}" -H "Accept: application/vnd.docker.distribution.manifest.v2+json" -H "Authorization: Bearer $TOKEN" "https://index.docker.io/v2/${JENKINS_REPO}/manifests/$tag")
    false
#    if [ "$http_code" -eq "404" ]; then
#        false
#    elif [ "$http_code" -eq "200" ]; then
#        true
#    else
#        echo "Received unexpected http code from Docker hub: $http_code"
#        exit 1
#    fi
}

set-base-image() {
    local variant=$1
    local arch=$2
    local dockerfile

    dockerfile="./multiarch/Dockerfile${variant}-${arch}"


    if [[ "$variant" =~ alpine ]]; then
        /bin/cp -f multiarch/Dockerfile.alpine "$dockerfile"
    elif [[ "$variant" =~ slim ]]; then
        /bin/cp -f multiarch/Dockerfile.slim "$dockerfile"
    elif [[ "$variant" =~ debian ]]; then
        /bin/cp -f multiarch/Dockerfile.debian "$dockerfile"
    fi

    # Parse architectures and variants
    if [[ $arch == amd64 ]]; then
        BASEIMAGE="amd64/openjdk:8-jdk"
    elif [[ $arch == arm ]]; then
        BASEIMAGE="arm32v7/openjdk:8-jdk"
    elif [[ $arch == arm64 ]]; then
        BASEIMAGE="arm64v8/openjdk:8-jdk"
    elif [[ $arch == s390x ]]; then
        BASEIMAGE="s390x/openjdk:8-jdk"
    elif [[ $arch == ppc64le ]]; then
        BASEIMAGE="ppc64le/openjdk:8-jdk"
    fi

    # The Alpine image only supports arm32v6 but should work fine on arm32v7
    # hardware - https://github.com/moby/moby/issues/34875
    if [[ $variant =~ alpine && $arch == arm ]]; then
        BASEIMAGE="arm32v6/openjdk:8-jdk-alpine"
    elif [[ $variant =~ alpine ]]; then
        BASEIMAGE="$BASEIMAGE-alpine"
    elif [[ $variant =~ slim ]]; then
        BASEIMAGE="$BASEIMAGE-slim"
    fi

    # Make the Dockerfile after we set the base image
    if [ "$(uname)" == 'Darwin' ]; then
        sed -i '' "s|BASEIMAGE|${BASEIMAGE}|g" "$dockerfile"
    else
        sed -i "s|BASEIMAGE|${BASEIMAGE}|g" "$dockerfile"
    fi

}

publish() {
    local version=$1
    local variant=$2
    local arch=$3
    local tag="${version}${variant}"
    local sha
    build_opts=(--no-cache --pull)

    if [ "$dry_run" = true ]; then
        build_opts=()
    fi

    sha=$(curl -q -fsSL "https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/${version}/jenkins-war-${version}.war.sha256" )


    set-base-image "$variant" "$arch"

    docker build --file "multiarch/Dockerfile$variant-$arch" \
                 --build-arg "JENKINS_VERSION=$version" \
                 --build-arg "JENKINS_SHA=$sha" \
                 --build-arg "GIT_LFS_VERSION=2.9.2" \
                 --tag "${JENKINS_REPO}:${tag}-${arch}" \
                 "${build_opts[@]+"${build_opts[@]}"}" .

    # " line to fix syntax highlightning
    if [ ! "$dry_run" = true ]; then
        docker push "${JENKINS_REPO}:${tag}-${arch}"
    fi
}

cleanup() {
    echo "Cleaning up"
#    rm -f manifest-tool
#    rm -f ./multiarch/qemu-*
    rm -rf ./multiarch/Dockerfile-*
}

# Process arguments
dry_run=false
debug=false
variant=""
arch=""

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -n)
        dry_run=true
        ;;
        -d)
        debug=true
        ;;
        -v|--variant)
        variant="-"$2
        shift
        ;;
        -a|--arch)
        arch=$2
        shift
        ;;
        *)
        echo "Unknown option: $key"
        return 1
        ;;
    esac
    shift
done


if [ "$dry_run" = true ]; then
    echo "Dry run, will not publish images"
fi

if [ "$debug" = true ]; then
    set -x
fi


#TOKEN=$(login-token)
docker-login

version=""
for version in $(get-latest-versions); do
    if is-published "$version$variant"; then
        echo "Tag is already published: $version$variant"
    else
        echo "Publishing version($arch): $version$variant"
        publish "$version" "$variant" "$arch"
    fi
done

cleanup
