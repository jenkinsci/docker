#!/usr/bin/env groovy

properties([
    buildDiscarder(logRotator(numToKeepStr: '50', artifactNumToKeepStr: '5')),
    pipelineTriggers([cron('H H/6 * * *')]),
])

nodeWithTimeout('docker') {
    deleteDir()

    stage('Checkout') {
        checkout scm
    }

    if (!infra.isTrusted()) {

        stage('shellcheck') {
            // run shellcheck ignoring error SC1091
            // Not following: /usr/local/bin/jenkins-support was not specified as input
            sh 'make shellcheck'
        }

        /* Outside of the trusted.ci environment, we're building and testing
         * the Dockerfile in this repository, but not publishing to docker hub
         */
        stage('Build') {
            sh 'make build'
        }

        stage('Prepare Test') {
            sh "make prepare-test"
        }

        def labels = ['debian', 'slim', 'alpine']
        def builders = [:]
        for (x in labels) {
            def label = x

            // Create a map to pass in to the 'parallel' step so we can fire all the builds at once
            builders[label] = {
                stage("Test ${label}") {
                    sh "make test-$label"
                }
            }
        }

        parallel builders

    } else {
        /* In our trusted.ci environment we only want to be publishing our
         * containers from artifacts
         */
        stage('Publish') {
            infra.withDockerCredentials {
                sh 'make publish'
            }
        }
    }
}

void nodeWithTimeout(String label, def body) {
    timeout(time: 40, unit: 'MINUTES') {
        node(label) {
            body.call()
        }
    }
}