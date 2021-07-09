ROOT_DIR="$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))/"

export DOCKER_BUILDKIT=1
export BUILDKIT_PROGRESS=plain

all: shellcheck build test

DOCKERFILES=$(shell find . -not -path '**/windows/*' -not -path './tests/*' -type f -name Dockerfile)

shellcheck:
	$(ROOT_DIR)/tools/shellcheck -e SC1091 \
	                             jenkins-support \
	                             *.sh
build:
	docker buildx bake -f docker-bake.hcl --set '*.platform=linux/amd64' --load linux

build-arm64:
	docker buildx bake -f docker-bake.hcl --set '*.platform=linux/arm64' --load linux-arm64

build-s390x:
	docker buildx bake -f docker-bake.hcl --set '*.platform=linux/s390x' --load linux-s390x

build-ppc64le:
	docker buildx bake -f docker-bake.hcl --set '*.platform=linux/ppc64le' --load linux-ppc64le

build-multiarch:
	docker buildx bake -f docker-bake.hcl --load linux

build-debian:
	docker buildx bake -f docker-bake.hcl --set '*.platform=linux/amd64' --load debian_jdk8

build-alpine:
	docker buildx bake -f docker-bake.hcl --set '*.platform=linux/amd64' --load alpine_jdk8

build-slim:
	docker buildx bake -f docker-bake.hcl --set '*.platform=linux/amd64' --load debian_slim_jdk8

build-jdk11:
	docker buildx bake -f docker-bake.hcl --set '*.platform=linux/amd64' --load debian_jdk11

build-almalinux:
	docker buildx bake -f docker-bake.hcl --set '*.platform=linux/amd64' --load almalinux_jdk11

build-centos:
	docker buildx bake -f docker-bake.hcl --set '*.platform=linux/amd64' --load centos8_jdk8

build-rhel-ubi8-jdk11:
	docker buildx bake -f docker-bake.hcl --set '*.platform=linux/amd64' --load rhel_ubi8_jdk11

build-centos7:
	docker buildx bake -f docker-bake.hcl --set '*.platform=linux/amd64' --load centos7_jdk8

bats:
	git clone -b v1.3.0 https://github.com/bats-core/bats-core bats

prepare-test: bats
	git submodule update --init --recursive
	mkdir -p target

test-run-%: prepare-test
	DIRECTORY="${DIRECTORY}" bats/bin/bats tests | tee target/results-$*.tap
	docker run --rm -v "${PWD}":/usr/src/app \
					-w /usr/src/app node:12-alpine \
					sh -c "npm install tap-xunit -g && cat target/results-$*.tap | tap-xunit --package='jenkinsci.docker.$*' > target/junit-results-$*.xml"

test-debian: DIRECTORY="8/debian/buster/hotspot"
test-debian: test-run-debian

test-alpine: DIRECTORY=8/alpine/hotspot
test-alpine: test-run-alpine

test-slim: DIRECTORY=8/debian/buster-slim/hotspot
test-slim: test-run-slim

test-jdk11: DIRECTORY=11/debian/buster/hotspot
test-jdk11: test-run-jdk11

test-almalinux: DIRECTORY=11/almalinux/almalinux8/hotspot
test-almalinux: test-run-almalinux

test-centos: DIRECTORY=8/centos/centos8/hotspot
test-centos: test-run-centos

test-rhel-ubi8-jdk11: DIRECTORY=11/rhel/ubi8/hotspot
test-rhel-ubi8-jdk11: test-run-rhel-ubi8-jdk11

test-centos7: DIRECTORY=8/centos/centos7/hotspot
test-centos7: test-run-centos7

test: build prepare-test
	@for d in ${DOCKERFILES} ; do \
		dir=`dirname $$d | sed -e "s_^\./__"` ; \
		DIRECTORY=$${dir} bats/bin/bats tests ; \
	done

test-install-plugins: prepare-test
	DIRECTORY="8/alpine/hotspot" bats/bin/bats tests/install-plugins.bats tests/install-plugins-plugins-cli.bats

publish:
	./.ci/publish.sh

publish-images-variant:
	./.ci/publish-images.sh --variant ${VARIANT} --arch ${ARCH} ;

publish-images-debian:
	./.ci/publish-images.sh --variant debian --arch ${ARCH} ;

publish-images-alpine:
	./.ci/publish-images.sh --variant alpine --arch ${ARCH} ;

publish-images-slim:
	./.ci/publish-images.sh --variant slim --arch ${ARCH} ;

publish-images: publish-images-debian publish-images-alpine publish-images-slim

publish-tags-debian:
	./.ci/publish-tags.sh --tag debian ;

publish-tag-alpine:
	./.ci/publish-tags.sh --tag alpine ;

publish-tags-slim:
	./.ci/publish-tags.sh --tag slim ;

publish-tags-lts-debian:
	./.ci/publish-tags.sh --tag lts-debian ;

publish-tag-lts-alpine:
	./.ci/publish-tags.sh --tag lts-alpine ;

publish-tags-lts-slim:
	./.ci/publish-tags.sh --tag lts-slim ;

publish-tags: publish-tags-debian publish-tag-alpine publish-tags-slim publish-tags-lts-debian publish-tag-lts-alpine publish-tags-lts-slim

publish-manifests-debian:
	./.ci/publish-manifests.sh --variant debian ;

publish-manifests-alpine:
	./.ci/publish-manifests.sh --variant alpine ;

publish-manifests-slim:
	./.ci/publish-manifests.sh --variant slim ;

publish-manifests-lts-debian:
	./.ci/publish-manifests.sh --variant lts-debian ;

publish-manifests-lts-alpine:
	./.ci/publish-manifests.sh --variant lts-alpine ;

publish-manifests-lts-slim:
	./.ci/publish-manifests.sh --variant lts-slim ;

publish-manifests-versions-debian:
	./.ci/publish-manifests.sh --variant versions-debian ;

publish-manifests-versions-alpine:
	./.ci/publish-manifests.sh --variant versions-alpine ;

publish-manifests-versions-slim:
	./.ci/publish-manifests.sh --variant versions-slim ;

publish-manifests: publish-manifests-debian publish-manifests-alpine publish-manifests-slim publish-manifests-lts-debian publish-manifests-lts-alpine publish-manifests-lts-slim publish-manifests-versions-debian publish-manifests-versions-alpine publish-manifests-versions-slim

clean:
	rm -rf tests/test_helper/bats-*; \
	rm -rf bats

.PHONY: shellcheck
