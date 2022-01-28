ROOT_DIR="$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))/"

## For Docker <=20.04
export DOCKER_BUILDKIT=1
## For Docker <=20.04
export DOCKER_CLI_EXPERIMENTAL=enabled
## Required to have docker build output always printed on stdout
export BUILDKIT_PROGRESS=plain
## Required to have the commit SHA added as a Docker image label
export COMMIT_SHA=$(shell git rev-parse HEAD)

current_arch := $(shell uname -m)
export ARCH ?= $(shell case $(current_arch) in (x86_64) echo "amd64" ;; (i386) echo "386";; (aarch64|arm64) echo "arm64" ;; (armv6*) echo "arm/v6";; (armv7*) echo "arm/v7";; (ppc64*|s390*|riscv*) echo $(current_arch);; (*) echo "UNKNOWN-CPU";; esac)

all: shellcheck build test

# Set to 'true' to disable parellel tests
DISABLE_PARALLEL_TESTS ?= false

# Set to the path of a specific test suite to restrict execution only to this
# default is "all test suites in the "tests/" directory
TEST_SUITES ?= $(CURDIR)/tests

##### Macros
## Check the presence of a CLI in the current PATH
check_cli = type "$(1)" >/dev/null 2>&1 || { echo "Error: command '$(1)' required but not found. Exiting." ; exit 1 ; }
## Check if a given image exists in the current manifest docker-bake.hcl
check_image = make --silent list | grep -w '$(1)' >/dev/null 2>&1 || { echo "Error: the image '$(1)' does not exist in manifest for the platform 'linux/$(ARCH)'. Please check the output of 'make list'. Exiting." ; exit 1 ; }
## Base "docker buildx base" command to be reused everywhere
bake_base_cli := docker buildx bake -f docker-bake.hcl --load

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
	@set -x; $(bake_base_cli) --set '*.platform=linux/$(ARCH)' $(shell make --silent list)

build-%: check-reqs
	@$(call check_image,$*)
	@set -x; $(bake_base_cli) --set '*.platform=linux/$(ARCH)' '$*'

show:
	@$(bake_base_cli) linux --print

list: check-reqs
	@set -x; make --silent show | jq -r '.target | path(.. | select(.platforms[] | contains("linux/$(ARCH)"))?) | add'

bats:
	git clone https://github.com/bats-core/bats-core bats ;\
	cd bats ;\
	git checkout eac1e9d047b2b8137d85307fc94439c90bdc25ae

prepare-test: bats check-reqs
	git submodule update --init --recursive
	mkdir -p target

## Define bats options based on environment
# common flags for all tests
bats_flags := $(TEST_SUITES)
# if DISABLE_PARALLEL_TESTS true, then disable parallel execution
ifneq (true,$(DISABLE_PARALLEL_TESTS))
# If the GNU 'parallel' command line is absent, then disable parallel execution
parallel_cli := $(shell command -v parallel 2>/dev/null)
ifneq (,$(parallel_cli))
# If parallel execution is enabled, then set 2 tests per core available for the Docker Engine
test-%: PARALLEL_JOBS ?= $(shell echo $$(( $(shell docker run --rm alpine grep -c processor /proc/cpuinfo) * 2)))
test-%: bats_flags += --jobs $(PARALLEL_JOBS)
endif
endif
test-%: prepare-test
# Check that the image exists in the manifest
	@$(call check_image,$*)
# Ensure that the image is built
	@make --silent build-$*
# Execute the test harness and write result to a TAP file
	IMAGE=$* bats/bin/bats $(bats_flags) | tee target/results-$*.tap
# convert TAP to JUNIT
	docker run --rm -v "$(CURDIR)":/usr/src/app -w /usr/src/app node:12-alpine \
		sh -c "npm install tap-xunit -g && cat target/results-$*.tap | tap-xunit --package='jenkinsci.docker.$*' > target/junit-results-$*.xml"

test: prepare-test
	@make --silent list | while read image; do make --silent "test-$${image}"; done

test-install-plugins: prepare-test
	@make --silent test TEST_SUITES=tests/install-plugins.bats tests/plugins-cli.bats

publish:
	./.ci/publish.sh

clean:
	rm -rf tests/test_helper/bats-*; \
	rm -rf bats

.PHONY: shellcheck check-reqs build clean test list test-install-plugins show
