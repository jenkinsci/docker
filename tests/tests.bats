#!/usr/bin/env bats

SUT_IMAGE=bats-jenkins
SUT_CONTAINER=bats-jenkins

load test_helpers

@test "build image" {
	cd $BATS_TEST_DIRNAME/..
	docker build -t $SUT_IMAGE .
}

@test "clean test containers" {
    docker kill $SUT_CONTAINER &>/dev/null ||:
    docker rm -fv $SUT_CONTAINER &>/dev/null ||:
}

@test "create test container" {
    docker run -d --name $SUT_CONTAINER -P $SUT_IMAGE
}

@test "test container is running" {
	sleep 1  # give time to eventually fail to initialize
	retry 3 1 assert "true" docker inspect -f {{.State.Running}} $SUT_CONTAINER
}

@test "Jenkins is initialized" {
    retry 30 5 test_url /api/json
}
