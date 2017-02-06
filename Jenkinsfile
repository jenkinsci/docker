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

    stage('Build') {
        docker.build('jenkins')
    }

    stage('Test') {
        sh """
        git submodule update --init --recursive
        git clone https://github.com/sstephenson/bats.git
        bats/bin/bats tests
        """
    }

    if (infra.isTrusted()) {
        stage('Publish') {
            sh './publish.sh'
        }
    }
}
