ROOT_DIR="$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))/"

all: shellcheck build test

shellcheck:
	$(ROOT_DIR)/tools/shellcheck -e SC1091 \
	                             jenkins-support \
	                             *.sh
build: build-debian build-alpine build-slim build-jdk11 build-centos build-centos7 build-openj9 build-openj9-jdk11

build-debian:
	docker build --file Dockerfile .

build-alpine:
	docker build --file Dockerfile-alpine .

build-slim:
	docker build --file Dockerfile-slim .

build-jdk11:
	docker build --file Dockerfile-jdk11 .

build-centos:
	docker build --file Dockerfile-centos .

build-centos7:
	docker build --file Dockerfile-centos7 .

build-openj9:
	docker build --file Dockerfile-openj9 .

build-openj9-jdk11:
	docker build --file Dockerfile-openj9-jdk11 .

bats:
	# Latest tag is unfortunately 0.4.0 which is quite older than the latest master tip.
	# So we clone and reset to this well known current sha:
	git clone https://github.com/sstephenson/bats.git ; \
	cd bats; \
	git reset --hard 03608115df2071fff4eaaff1605768c275e5f81f

prepare-test: bats
	git submodule update --init --recursive

test-debian: prepare-test
	DOCKERFILE=Dockerfile bats/bin/bats tests

test-alpine: prepare-test
	DOCKERFILE=Dockerfile-alpine bats/bin/bats tests

test-slim: prepare-test
	DOCKERFILE=Dockerfile-slim bats/bin/bats tests

test-jdk11: prepare-test
	DOCKERFILE=Dockerfile-jdk11 bats/bin/bats tests

test-centos: prepare-test
	DOCKERFILE=Dockerfile-centos bats/bin/bats tests

test-centos7: prepare-test
	DOCKERFILE=Dockerfile-centos7 bats/bin/bats tests

test-openj9:
	DOCKERFILE=Dockerfile-openj9 bats/bin/bats tests

test-openj9-jdk11:
	DOCKERFILE=Dockerfile-openj9-jdk11 bats/bin/bats tests

test: test-debian test-alpine test-slim test-jdk11 test-centos test-centos7 test-openj9 test-openj9-jdk11

test-install-plugins: prepare-test
	DOCKERFILE=Dockerfile-alpine bats/bin/bats tests/install-plugins.bats tests/install-plugins-plugins-cli.bats

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
