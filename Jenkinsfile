#!/usr/bin/env groovy

def listOfProperties = []
listOfProperties << buildDiscarder(logRotator(numToKeepStr: '50', artifactNumToKeepStr: '5'))

// Only master branch will run on a timer basis
if (env.BRANCH_NAME.trim() == 'master') {
    listOfProperties << pipelineTriggers([cron('''H H/6 * * 0-2,4-6
H 6,21 * * 3''')])
}

properties(listOfProperties)

// Default environment variable set to allow images publication
def envVars = ["PUBLISH=true"]

// Set to true in a replay to simulate a LTS build on ci.jenkins.io
// It will set the environment variables needed for a LTS
// and disable images publication out of caution
def SIMULATE_LTS_BUILD = false

if (SIMULATE_LTS_BUILD) {
    envVars = [
        "PUBLISH=false",
        "TAG_NAME=2.452.2",
        "JENKINS_VERSION=2.452.2",
        "JENKINS_SHA=360efc8438db9a4ba20772981d4257cfe6837bf0c3fb8c8e9b2253d8ce6ba339"
    ]
}

stage('Build') {
    def builds = [:]

    withEnv (envVars) {
        // Determine if the tag name (ie Jenkins version) correspond to a LTS (3 groups of digits)
        // to use the appropriate bake target and set of images to build (including or not Java 11)
        def isLTS
        if (env.TAG_NAME && env.TAG_NAME =~ /^\d+\.\d+\.\d+$/) {
            isLTS = true
            target = 'linux-lts-with-jdk11'
        } else {
            isLTS = false
            target = 'linux'
        }
        echo "= bake target: $target"
        echo "= isLTS: $isLTS"

        withEnv (["TARGET=${target}"]) {
            def windowsImageTypes = [
                'windowsservercore-ltsc2019',
            ]
            for (anImageType in windowsImageTypes) {
                def imageType = anImageType
                builds[imageType] = {
                    nodeWithTimeout('windows-2019') {
                        stage('Checkout') {
                            checkout scm
                        }

                        withEnv(["IMAGE_TYPE=${imageType}"]) {
                            if (!infra.isTrusted()) {
                                /* Outside of the trusted.ci environment, we're building and testing
                                * the Dockerfile in this repository, but not publishing to docker hub
                                */
                                stage("Build ${imageType}") {
                                    infra.withDockerCredentials {
                                        powershell './make.ps1'
                                    }
                                }

                                stage("Test ${imageType}") {
                                    infra.withDockerCredentials {
                                        def windowsTestStatus = powershell(script: './make.ps1 test', returnStatus: true)
                                        junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'target/**/junit-results.xml')
                                        if (windowsTestStatus > 0) {
                                            // If something bad happened let's clean up the docker images
                                            error('Windows test stage failed.')
                                        }
                                    }
                                }

                                // disable until we get the parallel changes merged in
                                // def branchName = "${env.BRANCH_NAME}"
                                // if (branchName ==~ 'master'){
                                //    stage('Publish Experimental') {
                                //        infra.withDockerCredentials {
                                //            withEnv(['DOCKERHUB_ORGANISATION=jenkins4eval','DOCKERHUB_REPO=jenkins']) {
                                //                powershell './make.ps1 publish'
                                //            }
                                //        }
                                //    }
                                // }
                            } else {
                                // Only publish when a tag triggered the build & the publication is enabled (ie not simulating a LTS)
                                if (env.TAG_NAME && (env.PUBLISH == "true")) {
                                    // Split to ensure any suffix is not taken in account (but allow suffix tags to trigger rebuilds)
                                    jenkins_version = env.TAG_NAME.split('-')[0]
                                    withEnv(["JENKINS_VERSION=${jenkins_version}"]) {
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
                        }
                    }
                }
            }

            if (!infra.isTrusted()) {
                def images

                def imagesWithoutJava11 = [
                    'alpine_jdk17',
                    'alpine_jdk21',
                    'debian_jdk17',
                    'debian_jdk21',
                    'debian_slim_jdk17',
                    'debian_slim_jdk21',
                    'rhel_ubi9_jdk17',
                    'rhel_ubi9_jdk21',
                ]
                def imagesWithJava11 = [
                    'almalinux_jdk11',
                    'alpine_jdk11',
                    'alpine_jdk17',
                    'alpine_jdk21',
                    'debian_jdk11',
                    'debian_jdk17',
                    'debian_jdk21',
                    'debian_slim_jdk11',
                    'debian_slim_jdk17',
                    'debian_slim_jdk21',
                    'rhel_ubi8_jdk11',
                    'rhel_ubi9_jdk17',
                    'rhel_ubi9_jdk21',
                ]
                if (isLTS) {
                    images = imagesWithJava11
                } else {
                    images = imagesWithoutJava11
                }
                // Build all images including Java 11 if the version match a LTS versioning pattern
                // TODO: remove when Java 11 is removed from LTS line
                // See https://github.com/jenkinsci/docker/issues/1890
                for (i in images) {
                    def imageToBuild = i

                    builds[imageToBuild] = {
                        nodeWithTimeout('docker') {
                            deleteDir()

                            stage('Checkout') {
                                checkout scm
                            }

                            stage('Static analysis') {
                                sh 'make hadolint shellcheck'
                            }

                            /* Outside of the trusted.ci environment, we're building and testing
                            * the Dockerfile in this repository, but not publishing to docker hub
                            */
                            stage("Build linux-${imageToBuild}") {
                                infra.withDockerCredentials {
                                    sh "make build-${imageToBuild}"
                                }
                            }

                            stage("Test linux-${imageToBuild}") {
                                sh "make prepare-test"
                                try {
                                    infra.withDockerCredentials {
                                        sh "make test-${imageToBuild}"
                                    }
                                } catch (err) {
                                    error("${err.toString()}")
                                } finally {
                                    junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'target/*.xml')
                                }
                            }
                        }
                    }
                }
                builds['multiarch-build'] = {
                    nodeWithTimeout('docker') {
                        stage('Checkout') {
                            deleteDir()
                            checkout scm
                        }

                        // sanity check that proves all images build on declared platforms
                        stage('Multi arch build') {
                            infra.withDockerCredentials {
                                sh '''
                                    docker buildx create --use
                                    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
                                    docker buildx bake --file docker-bake.hcl "${TARGET}"
                                '''
                            }
                        }
                    }
                }
            } else {
                // Only publish when a tag triggered the build
                if (env.TAG_NAME) {
                    // Split to ensure any suffix is not taken in account (but allow suffix tags to trigger rebuilds)
                    jenkins_version = env.TAG_NAME.split('-')[0]
                    builds['linux'] = {
                        withEnv(["JENKINS_VERSION=${jenkins_version}"]) {
                            nodeWithTimeout('docker') {
                                stage('Checkout') {
                                    checkout scm
                                }

                                stage('Publish') {
                                    // Publication is enabled by default, disabled when simulating a LTS
                                    if (env.PUBLISH == "true") {
                                        infra.withDockerCredentials {
                                            sh '''
                                                docker buildx create --use
                                                docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
                                                make publish
                                                '''
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            parallel builds
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
