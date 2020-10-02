#!/usr/bin/env groovy

properties([
    buildDiscarder(logRotator(numToKeepStr: '50', artifactNumToKeepStr: '5')),
    pipelineTriggers([cron('''H H/6 * * 0-2,4-6
H 6,21 * * 3''')])
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

        def configs = [
                      'amd64' : ['debian', 'slim', 'alpine', 'jdk11', 'centos', 'centos7'],
                      'arm64' : ['debian', 'slim', 'alpine', 'jdk11'],
                      's390x' : ['debian', 'slim', 'alpine', 'jdk11'],
                      'ppe64le' : ['debian', 'slim', 'alpine', 'jdk11']
                      ]
        def builders = [:]
        configs.each { k, v -> 
            v.each { label -> 
                def nodeLabel = "${k}&&docker"
                // Create a map to pass in to the 'parallel' step so we can fire all the builds at once
                builders["${k}-${label}] = {
                    node(nodeLabel) {
                        /* Outside of the trusted.ci environment, we're building and testing
                         * the Dockerfile in this repository, but not publishing to docker hub
                        */
                        stage("Build ${k} - ${label}") {
                            sh "make build-${label}"
                        }

                        stage("Prepare Test ${k} - ${label}") {
                            sh "make prepare-test"
                        }
                  
                        stage("Test ${k} - ${label}") {
                            sh "make test-${label}"
                        }
                    }
                }
            }
        }

        parallel builders

        def branchName = "${env.BRANCH_NAME}"
        if (branchName ==~ 'master'){
            stage('Publish Experimental') {
                infra.withDockerCredentials {
                    sh 'make publish-tags'
                    sh 'make publish-manifests'
                }
            }
        }
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
    node(label) {
        timeout(time: 60, unit: 'MINUTES') {
            body.call()
        }
    }
}
