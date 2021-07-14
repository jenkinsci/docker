ROOT_DIR="$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))/"

export DOCKER_BUILDKIT=1
export BUILDKIT_PROGRESS=plain

all: shellcheck build test

DOCKERFILES ?= $(shell find . -not -path '**/windows/*' -not -path './tests/*' -type f -name Dockerfile)

# Set to 'true' to disable parellel tests
DISABLE_PARALLEL_TESTS ?= false

# Set to the path of a specific test suite to restrict execution only to this
# default is "all test suites in the "tests/" directory
TEST_SUITES ?= $(CURDIR)/tests

# No additional flags by default (used to add --print)
BAKE_ADDITIONAL_FLAGS ?=

## Macro to check for the presence of a CLI in the current PATH
check_cli = type "$(1)" >/dev/null 2>&1 || { echo "Error: command '$(1)' required but not found. Exiting." ; exit 1 ; }
check-reqs:
## Build requirements
	@$(call check_cli,bash)
	@$(call check_cli,git)
	@$(call check_cli,docker)
	@docker info | grep 'buildx:' >/dev/null 2>&1 || { echo "Error: Docker BuildX plugin required but not found. Exiting." ; exit 1 ; }
## Test requirements
	@$(call check_cli,curl)
	@$(call check_cli,jq)

shellcheck:
	$(ROOT_DIR)/tools/shellcheck -e SC1091 jenkins-support *.sh

build: check-reqs
	docker buildx bake -f docker-bake.hcl --set '*.platform=linux/amd64' --load linux $(BAKE_ADDITIONAL_FLAGS)

build-arm64: check-reqs
	docker buildx bake -f docker-bake.hcl --set '*.platform=linux/arm64' --load linux-arm64 $(BAKE_ADDITIONAL_FLAGS)

build-s390x: check-reqs
	docker buildx bake -f docker-bake.hcl --set '*.platform=linux/s390x' --load linux-s390x $(BAKE_ADDITIONAL_FLAGS)

build-ppc64le: check-reqs
	docker buildx bake -f docker-bake.hcl --set '*.platform=linux/ppc64le' --load linux-ppc64le $(BAKE_ADDITIONAL_FLAGS)

build-multiarch: check-reqs
	docker buildx bake -f docker-bake.hcl --load linux

build-debian: check-reqs
	docker buildx bake -f docker-bake.hcl --set '*.platform=linux/amd64' --load debian_jdk8 $(BAKE_ADDITIONAL_FLAGS)

build-alpine: check-reqs
	docker buildx bake -f docker-bake.hcl --set '*.platform=linux/amd64' --load alpine_jdk8 $(BAKE_ADDITIONAL_FLAGS)

build-slim: check-reqs
	docker buildx bake -f docker-bake.hcl --set '*.platform=linux/amd64' --load debian_slim_jdk8 $(BAKE_ADDITIONAL_FLAGS)

build-jdk11: check-reqs
	docker buildx bake -f docker-bake.hcl --set '*.platform=linux/amd64' --load debian_jdk11 $(BAKE_ADDITIONAL_FLAGS)

build-almalinux: check-reqs
	docker buildx bake -f docker-bake.hcl --set '*.platform=linux/amd64' --load almalinux_jdk11 $(BAKE_ADDITIONAL_FLAGS)

build-centos: check-reqs
	docker buildx bake -f docker-bake.hcl --set '*.platform=linux/amd64' --load centos8_jdk8 $(BAKE_ADDITIONAL_FLAGS)

build-rhel-ubi8-jdk11: check-reqs
	docker buildx bake -f docker-bake.hcl --set '*.platform=linux/amd64' --load rhel_ubi8_jdk11 $(BAKE_ADDITIONAL_FLAGS)

build-centos7: check-reqs
	docker buildx bake -f docker-bake.hcl --set '*.platform=linux/amd64' --load centos7_jdk8 $(BAKE_ADDITIONAL_FLAGS)

bats:
	git clone https://github.com/bats-core/bats-core bats ;\
	cd bats ;\
	git checkout eac1e9d047b2b8137d85307fc94439c90bdc25ae

prepare-test: bats check-reqs
	git submodule update --init --recursive
	mkdir -p target

## Both 'docker' and GNU 'parallel' command lines are required to enable parallel tests
parallel_cli := $(shell command -v parallel 2>/dev/null)
bats_flags := $(TEST_SUITES)
ifneq (true,$(DISABLE_PARALLEL_TESTS))
ifneq (,$(parallel_cli))
## Two tests per core available to the Docker Engine as most of the workload is network
PARALLEL_JOBS ?= $(shell echo $$(( $(shell docker run --rm alpine grep -c processor /proc/cpuinfo) * 2)))
bats_flags += --jobs $(PARALLEL_JOBS)
endif
endif

test-run-%: prepare-test
	make --silent -C $(CURDIR) build-$*
	IMAGE=$* bats/bin/bats $(bats_flags) | tee target/results-$*.tap
	docker run --rm -v "$(CURDIR)":/usr/src/app \
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
		DIRECTORY=$${dir} bats/bin/bats --jobs $(PARALLEL_JOBS) tests ; \
	done

test-install-plugins: prepare-test
	DIRECTORY="8/alpine/hotspot" bats/bin/bats --jobs $(PARALLEL_JOBS) tests/install-plugins.bats tests/install-plugins.bats

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

.PHONY: shellcheck check-reqs build clean test
