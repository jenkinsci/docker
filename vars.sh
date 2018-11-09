#!/usr/bin/env bash

# Note: Jenkins sha256 values come from:
# http://mirrors.jenkins.io/war/{version}/jenkins.war.sha256

# Keep a running list of versions and SHA256 values here.
# Comment out and add two new lines for each version -- that way, it's easy
# to rebuild an previous version if we need simply by changing the active version/sha:
JENKINS_VERSION=2.150
JENKINS_SHA256=90e827e570d013551157e78249b50806f5c3953f9845b634f5c0fc542bf54b9a
DOCKER_VERSION=18.06.1~ce~3-0~debian

# Docker tag format is JENKINS_TAG-DOCKER_TAG:
# Need to override because chars like ~ are forbidden:
JENKINS_TAG=${JENKINS_VERSION}
DOCKER_TAG=18.06.1
JENKINS_DOCKER_IMAGE_TAG=${JENKINS_TAG}-${DOCKER_TAG}

# Path to local source (for building your local repos):
LOCAL_SRC=~/src

# Export for the build script to use:
export JENKINS_VERSION
export JENKINS_SHA256
export DOCKER_VERSION
export JENKINS_DOCKER_IMAGE_TAG
export LOCAL_SRC
