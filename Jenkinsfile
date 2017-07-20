#!/usr/bin/env groovy

properties([
    buildDiscarder(logRotator(numToKeepStr: '5', artifactNumToKeepStr: '5')),
    pipelineTriggers([cron('@daily')]),
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
            bats/bin/bats tests
            """
        }
    } else {
        /* In our trusted.ci environment we only want to be publishing our
         * containers from artifacts
         */
        stage('Publish') {
            infra.withDockerCredentials {
                sh './publish.sh'
                sh './publish.sh --variant alpine'
            }
        }
    }
}
