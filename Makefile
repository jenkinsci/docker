ROOT_DIR="$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))/"

all: shellcheck build test

DOCKERFILES=$(shell find . -not -path '**/windows/*' -not -path './tests/*' -type f -name Dockerfile)

shellcheck:
	$(ROOT_DIR)/tools/shellcheck -e SC1091 \
	                             jenkins-support \
	                             *.sh
build:
	@for d in ${DOCKERFILES} ; do \
		docker build --file "$${d}" . ; \
	done

build-debian:
	docker build --file 8/debian/buster/hotspot/Dockerfile .

build-alpine:
	docker build --file 8/alpine/hotspot/Dockerfile .

build-slim:
	docker build --file 8/debian/buster-slim/hotspot/Dockerfile .

build-jdk11:
	docker build --file 11/debian/buster/hotspot/Dockerfile .

build-centos:
	docker build --file 8/centos/centos8/hotspot/Dockerfile .

build-centos7:
	docker build --file 8/centos/centos7/hotspot/Dockerfile .

build-openj9:
	docker build --file 8/ubuntu/bionic/openj9/Dockerfile .

build-openj9-jdk11:
	docker build --file 11/ubuntu/bionic/openj9/Dockerfile .

bats:
	# Latest tag is unfortunately 0.4.0 which is quite older than the latest master tip.
	# So we clone and reset to this well known current sha:
	git clone https://github.com/sstephenson/bats.git ; \
	cd bats; \
	git reset --hard 03608115df2071fff4eaaff1605768c275e5f81f

prepare-test: bats
	git submodule update --init --recursive

test-debian: prepare-test
	DIRECTORY="8/debian/buster/hotspot" bats/bin/bats tests

test-alpine: prepare-test
	DIRECTORY="8/alpine/hotspot" bats/bin/bats tests

test-slim: prepare-test
	DIRECTORY="8/debian/buster-slim/hotspot" bats/bin/bats tests

test-jdk11: prepare-test
	DIRECTORY="11/debian/buster/hotspot" bats/bin/bats tests

test-centos: prepare-test
	DIRECTORY="8/centos/centos8/hotspot" bats/bin/bats tests

test-centos7: prepare-test
	DIRECTORY="8/centos/centos7/hotspot" bats/bin/bats tests

test-openj9:
	DIRECTORY="8/ubuntu/bionic/openj9" bats/bin/bats tests

test-openj9-jdk11:
	DIRECTORY="11/ubuntu/bionic/openj9" bats/bin/bats tests

test: build prepare-test
	@for d in ${DOCKERFILES} ; do \
		dir=`dirname $$d | sed -e "s_^\./__"` ; \
		DIRECTORY=$${dir} bats/bin/bats tests ; \
	done

test-install-plugins: prepare-test
	DIRECTORY="8/alpine/hotspot" bats/bin/bats tests/install-plugins.bats tests/install-plugins-plugins-cli.bats

publish:
	./.ci/publish.sh ; \
	./.ci/publish.sh --variant alpine ; \
	./.ci/publish.sh --variant slim ; \
	./.ci/publish.sh --variant jdk11 --start-after 2.151 ; \
	./.ci/publish.sh --variant centos --start-after 2.181 ; \
	./.ci/publish.sh --variant centos7 --start-after 2.199 ;

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

publish-tag-latest:
	./.ci/publish-tags.sh --tag latest ;

publish-tags: publish-tags-debian publish-tag-alpine publish-tags-slim publish-tags-lts-debian publish-tag-lts-alpine publish-tags-lts-slim publish-tags-latest

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

publish-manifests-latest:
	./.ci/publish-manifests.sh --variant latest ;

publish-manifests-versions-debian:
	./.ci/publish-manifests.sh --variant versions-debian ;

publish-manifests-versions-alpine:
	./.ci/publish-manifests.sh --variant versions-alpine ;

publish-manifests-versions-slim:
	./.ci/publish-manifests.sh --variant versions-slim ;

publish-manifests: publish-manifests-debian publish-manifests-alpine publish-manifests-slim publish-manifests-lts-debian publish-manifests-lts-alpine publish-manifests-lts-slim publish-manifests-latest publish-manifests-versions-debian publish-manifests-versions-alpine publish-manifests-versions-slim

clean:
	rm -rf tests/test_helper/bats-*; \
	rm -rf bats

.PHONY: shellcheck
