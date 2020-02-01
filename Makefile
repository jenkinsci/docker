ROOT_DIR="$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))/"

all: shellcheck build test

shellcheck:
	$(ROOT_DIR)/tools/shellcheck -e SC1091 \
	                             jenkins-support \
	                             *.sh

build: build-debian build-alpine build-slim build-jdk11 build-centos build-openj9 build-openj9-jdk11

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

test-openj9:
	DOCKERFILE=Dockerfile-openj9 bats/bin/bats tests

test-openj9-jdk11:
	DOCKERFILE=Dockerfile-openj9-jdk11 bats/bin/bats tests

test: test-debian test-alpine test-slim test-jdk11 test-centos test-openj9 test-openj9-jdk11

test-install-plugins: prepare-test
	DOCKERFILE=Dockerfile-alpine bats/bin/bats tests/install-plugins.bats

publish:
	./publish.sh ; \
	./publish.sh --variant alpine ; \
	./publish.sh --variant slim ; \
	./publish.sh --variant jdk11 --start-after 2.151 ; \
	./publish.sh --variant centos --start-after 2.181 ;

publish-experimental:
	./publish-experimental.sh ; \
	./publish-experimental.sh --variant alpine ; \
	./publish-experimental.sh --variant slim ; \
	./publish-experimental.sh --variant openj9 ; \
	./publish-experimental.sh --variant openj9-jdk11 ;

clean:
	rm -rf tests/test_helper/bats-*; \
	rm -rf bats

.PHONY: shellcheck
