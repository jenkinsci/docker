#!/usr/bin/env groovy

properties([
    buildDiscarder(logRotator(numToKeepStr: '50', artifactNumToKeepStr: '5')),
    pipelineTriggers([cron('H H/6 * * *')]),
])

node('docker') {
    deleteDir()

    stage('Checkout') {
        checkout scm
    }

    if (!infra.isTrusted()) {

        stage('shellcheck') {
            // newer versions of the image don't have cat installed and docker pipeline fails
            docker.image('koalaman/shellcheck:v0.4.6').inside() {
                // run shellcheck ignoring error SC1091
                // Not following: /usr/local/bin/jenkins-support was not specified as input
                sh "shellcheck -e SC1091 *.sh"
            }
        }

        /* Outside of the trusted.ci environment, we're building and testing
         * the Dockerfile in this repository, but not publishing to docker hub
         */
        stage('Build') {
            docker.build('jenkins')
            docker.build('jenkins:alpine', '--file Dockerfile-alpine .')
        }

        stage('Test') {
            sh """
            git submodule update --init --recursive
            git clone https://github.com/sstephenson/bats.git
            """
        }

        def labels = ['debian', 'slim', 'alpine']
        def builders = [:]
        for (x in labels) {
            def label = x

            // Create a map to pass in to the 'parallel' step so we can fire all the builds at once
            builders[label] = {
                stage("Test ${label}") {
                    def dockerfile = label == 'debian' ? 'Dockerfile' : "Dockerfile-${label}"
                    sh "DOCKERFILE=${dockerfile} bats/bin/bats tests"
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
                sh './publish.sh'
                sh './publish.sh --variant alpine'
                sh './publish.sh --variant slim'
            }
        }
    }
}
