#!/usr/bin/env groovy

properties([
    buildDiscarder(logRotator(numToKeepStr: '50', artifactNumToKeepStr: '5')),
    pipelineTriggers([cron('''H H/6 * * 0-2,4-6
H 6,21 * * 3''')])
])


stage('Build') {
    def builds = [:]
    builds['windows'] = {
        nodeWithTimeout('windock') {
            stage('Checkout') {
                checkout scm
            }

            if (!infra.isTrusted()) {

                /* Outside of the trusted.ci environment, we're building and testing
                * the Dockerfile in this repository, but not publishing to docker hub
                */
                stage('Build') {
                    powershell './make.ps1'
                }

                stage('Test') {
                    def windowsTestStatus = powershell(script: './make.ps1 test', returnStatus: true)
                    junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'target/**/junit-results.xml')
                    if (windowsTestStatus > 0) {
                        error('Windows test stage failed.')
                    }
                }

                def branchName = "${env.BRANCH_NAME}"
                if (branchName ==~ 'master'){
                    stage('Publish Experimental') {
                        infra.withDockerCredentials {
                            withEnv(['DOCKERHUB_ORGANISATION=jenkins4eval','DOCKERHUB_REPO=jenkins']) {
                                powershell './make.ps1 publish'
                            }
                        }
                    }
                }
            } else {
                /* In our trusted.ci environment we only want to be publishing our
                * containers from artifacts
                */
                stage('Publish') {
                    infra.withDockerCredentials {
                        withEnv(['DOCKERHUB_ORGANISATION=jenkins','DOCKERHUB_REPO=jenkins']) {
                            powershell './make.ps1 publish'
                        }
                    }
                }
            }
        }
    }

    builds['linux'] = {
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

                def labels = ['debian', 'slim', 'alpine', 'jdk11', 'centos', 'centos7']
                def builders = [:]
                for (x in labels) {
                    def label = x

                    // Create a map to pass in to the 'parallel' step so we can fire all the builds at once
                    builders[label] = {
                        stage("Test ${label}") {
                            sh "make test-$label"
                            junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'target/*.xml')
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
    }

    parallel builds
}


void nodeWithTimeout(String label, def body) {
    node(label) {
        timeout(time: 60, unit: 'MINUTES') {
            body.call()
        }
    }
}
