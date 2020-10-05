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
                    powershell './make.ps1 test'
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

                def configs = [
                    'amd64' : ['debian', 'slim', 'alpine', 'jdk11', 'centos', 'centos7'],
                    'arm64' : ['debian', 'slim', 'jdk11'],
                    's390x' : ['debian', 'slim', 'jdk11'],
                    // re-enable once the ppc64le agent is back up
                    //'ppe64le' : ['debian', 'slim', 'jdk11']
                ]
                def builders = [:]
                configs.each { k, v -> 
                    v.each { label -> 
                        def dockerLabel="${k}docker"
                        if(k == "amd64") {
                            dockerLabel="docker"
                        }
                        // Create a map to pass in to the 'parallel' step so we can fire all the builds at once
                        builders["${k}-${label}"] = {
                            nodeWithTimeout("${k}&&${dockerLabel}") {
                                stage("Checkout ${k} - ${label}") {
                                    checkout scm
                                }

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
