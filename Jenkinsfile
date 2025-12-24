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
def envVars = ['PUBLISH=true']

// Set to true in a replay to simulate a LTS build on ci.jenkins.io
// It will set the environment variables needed for a LTS
// and disable images publication out of caution
def SIMULATE_LTS_BUILD = false

if (SIMULATE_LTS_BUILD) {
    envVars = [
        'PUBLISH=false',
        'TAG_NAME=2.504.3',
        'JENKINS_VERSION=2.504.3',
        'WAR_SHA=ea8883431b8b5ef6b68fe0e5817c93dc0a11def380054e7de3136486796efeb0',
        'SIMULATED_BUILD=true'
    ]
}

stage('Build') {
    def builds = [:]

    withEnv(envVars) {
        echo '= bake target: linux'

        def windowsImageTypes = ['windowsservercore-ltsc2019']
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
                                    powershell './make.ps1 build'
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
                            if (env.TAG_NAME && (env.PUBLISH == 'true')) {
                                // Split to ensure any suffix is not taken in account (but allow suffix tags to trigger rebuilds)
                                String jenkins_version = env.TAG_NAME.split('-')[0]
                                // Setting WAR_URL to download war from Artifactory instead of mirrors on publication from trusted.ci.jenkins.io
                                withEnv([
                                    "JENKINS_VERSION=${jenkins_version}",
                                    "WAR_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${jenkins_version}/jenkins-war-${jenkins_version}.war"
                                ]) {
                                    stage('Publish') {
                                        infra.withDockerCredentials {
                                            withEnv(['DOCKERHUB_ORGANISATION=jenkins', 'DOCKERHUB_REPO=jenkins']) {
                                                powershell './make.ps1 build'
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
            def images = [
                'alpine_jdk17',
                'alpine_jdk21',
                'debian_jdk17',
                'debian_jdk21',
                'debian-slim_jdk17',
                'debian-slim_jdk21',
                'rhel_ubi9_jdk17',
                'rhel_ubi9_jdk21',
            ]
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
                            sh 'make prepare-test'
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
            def allArchitectures = [
                'amd64',
                'arm64',
                'ppc64le',
                's390x'
            ]
            for (a in allArchitectures) {
                def architecture = a
                builds[architecture] = {
                    nodeWithTimeout('docker') {
                        stage('Checkout') {
                            deleteDir()
                            checkout scm
                        }

                        def currentArchitecture
                        stage('Retrieve current architecture') {
                            script {
                                currentArchitecture = sh(script: '''
                                    current_arch="$(uname -m)"
                                    case "${current_arch}" in
                                        x86_64)
                                            echo amd64
                                            ;;
                                        aarch64|arm64)
                                            echo arm64
                                            ;;
                                        s390*|ppc64le|riscv*)
                                            echo "${current_arch}"
                                            ;;
                                        *)
                                            echo "Unsupported architecture: ${current_arch}" >&2
                                            exit 1
                                            ;;
                                    esac
                                ''', returnStdout: true).trim()
                            }
                        }

                        if (architecture == currentArchitecture) {
                            echo "Current architecture ${currentArchitecture} skipped as already build in other stages"
                            return
                        }
                        // sanity check that proves all images build on declared platforms not already built in other stages
                        stage("Multi arch build - ${architecture}") {
                            infra.withDockerCredentials {
                                withEnv(['DEFAULT_JDK_ONLY=true']) {
                                    sh "make docker-init listarch-${architecture} buildarch-${architecture}"
                                }
                            }
                        }
                    }
                }
            }
        } else {
            // Only publish when a tag triggered the build
            if (env.TAG_NAME) {
                // Split to ensure any suffix is not taken in account (but allow suffix tags to trigger rebuilds)
                String jenkins_version = env.TAG_NAME.split('-')[0]
                builds['linux'] = {
                    // Setting WAR_URL to download war from Artifactory instead of mirrors on publication from trusted.ci.jenkins.io
                    withEnv([
                        "JENKINS_VERSION=${jenkins_version}",
                        "WAR_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${jenkins_version}/jenkins-war-${jenkins_version}.war"
                    ]) {
                        nodeWithTimeout('docker') {
                            stage('Checkout') {
                                checkout scm
                            }

                            stage('Publish') {
                                // Publication is enabled by default, disabled when simulating a LTS
                                if (env.PUBLISH == 'true') {
                                    infra.withDockerCredentials {
                                        sh 'make docker-init'
                                        sh 'make publish'
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

void nodeWithTimeout(String label, def body) {
    node(label) {
        timeout(time: 60, unit: 'MINUTES') {
            body.call()
        }
    }
}
