ROOT_DIR="$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))/"

all: shellcheck build test

DOCKERFILES=$(shell find . -type f -not -path "./tests/*" -name Dockerfile)

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
	DIRECTORU="8/entos/centos7/hotspot" bats/bin/bats tests

test-openj9:
	DIRECTORY="8/ubuntu/bionic/openj9" bats/bin/bats tests

test-openj9-jdk11:
	DIRECTORY="11/ubuntu/bionic/openj9" bats/bin/bats tests

test:
	@for d in ${DOCKERFILES} ; do \
		dir=`dirname $$d | sed -e "s_^\./__"` ; \
		DIRECTORY=$${dir} bats/bin/bats tests ; \
	done

test-install-plugins: prepare-test
	DIRECTORY="8/alpine/hotspot" bats/bin/bats tests/install-plugins.bats

publish:
	./publish.sh ; \
	./publish.sh --variant alpine ; \
	./publish.sh --variant slim ; \
	./publish.sh --variant jdk11 --start-after 2.151 ; \
	./publish.sh --variant centos --start-after 2.181 ; \
	./publish.sh --variant centos7 --start-after 2.199 ;

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
