ROOT_DIR="$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))/"

all: shellcheck build

build: build-arm build-slim

build-arm:
	docker buildx build --platform linux/arm64 .

build-slim:
	docker buildx build --platform linux/arm64 --file Dockerfile-slim .

#bats:
#	# Latest tag is unfortunately 0.4.0 which is quite older than the latest master tip.
#	# So we clone and reset to this well known current sha:
#	git clone https://github.com/sstephenson/bats.git ; \
#	cd bats; \
#	git reset --hard 03608115df2071fff4eaaff1605768c275e5f81f
#
#prepare-test: bats
#	git submodule update --init --recursive
#
#test-arm: prepare-test
#	DOCKERFILE=Dockerfile bats/bin/bats tests
#
#test-slim: prepare-test
#	DOCKERFILE=Dockerfile-slim bats/bin/bats tests
#
#test: test-arm test-slim
#
#test-install-plugins: prepare-test
#	DOCKERFILE=Dockerfile-alpine bats/bin/bats tests/install-plugins.bats

shellcheck:
	$(ROOT_DIR)/tools/shellcheck -e SC1091 \
	                             jenkins-support \
	                             *.sh
publish:
	./publish.sh ; #\
#    ./publish.sh --variant slim ;

clean:
	rm -rf tests/test_helper/bats-*; \
	rm -rf bats

.PHONY: shellcheck
