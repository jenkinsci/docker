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
	docker build --file 8/alpine/3.12/hotspot/Dockerfile .

build-slim:
	docker build --file 8/debian/busterslim/hotspot/Dockerfile .

build-jdk11:
	docker build --file 11/debian/buster/hotspot/Dockerfile .

build-centos:
	docker build --file 8/centos/8/hotspot/Dockerfile .

build-centos7:
	docker build --file 8/centos/7/hotspot/Dockerfile .

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
	DIRECTORY="8/debian/busterslim/hotspot" bats/bin/bats tests

test-jdk11: prepare-test
	DIRECTORY="11/debian/buster/hotspot" bats/bin/bats tests

test-centos: prepare-test
	DIRECTORY="8/centos/8/hotspot" bats/bin/bats tests

test-centos7: prepare-test
	DIRECTORY="8/centos/7/hotspot" bats/bin/bats tests

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
	DIRECTORY="8/alpine/3.12/hotspot" bats/bin/bats tests/install-plugins.bats tests/install-plugins-plugins-cli.bats

publish-images-alpine:
	./.ci/publish.sh --publish images --os-name alpine --jdk all --jvm all

publish-images-centos:
	./.ci/publish.sh --publish images --os-name centos --jdk all --jvm all

publish-images-debian:
	./.ci/publish.sh --publish images --os-name debian --jdk all --jvm all

publish-images-ubuntu:
	./.ci/publish.sh --publish images --os-name ubuntu --jdk all --jvm all

publish-images: publish-images-alpine publish-images-centos publish-images-debian publish-images-ubuntu

publish-tags-alpine:
	./.ci/publish.sh --publish tags --os-name alpine --jdk all --jvm all

publish-tags-centos:
	./.ci/publish.sh --publish tags --os-name centos --jdk all --jvm all

publish-tags-debian:
	./.ci/publish.sh --publish tags --os-name debian --jdk all --jvm all

publish-tags-ubuntu:
	./.ci/publish.sh --publish tags --os-name ubuntu --jdk all --jvm all

publish-tags: publish-tags-alpine publish-tags-centos publish-tags-debian publish-tags-ubuntu

publish-manifests-alpine:
	./.ci/publish.sh --publish manifests --os-name alpine --jdk all --jvm all

publish-manifests-centos:
	./.ci/publish.sh --publish manifests --os-name centos --jdk all --jvm all

publish-manifests-debian:
	./.ci/publish.sh --publish manifests --os-name debian --jdk all --jvm all

publish-manifests-ubuntu:
	./.ci/publish.sh --publish manifests --os-name ubuntu --jdk all --jvm all

publish-manifests: publish-manifests-alpine publish-manifests-centos publish-manifests-debian publish-manifests-ubuntu

clean:
	rm -rf tests/test_helper/bats-*; \
	rm -rf bats

.PHONY: shellcheck
