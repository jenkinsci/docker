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

// List of architectures and corresponding ci.jenkins.io agent labels
def architecturesAndCiJioAgentLabels = [
    'amd64': 'docker && amd64',
    'arm64': 'arm64docker',
    // Using qemu
    'ppc64le': 'docker && amd64',
    's390x': 'docker && amd64',
]

// Set to true in a replay to simulate a LTS build on ci.jenkins.io
// It will set the environment variables needed for a LTS
// and disable images publication out of caution
def SIMULATE_LTS_BUILD = false

if (SIMULATE_LTS_BUILD) {
    envVars = [
        'PUBLISH=false',
        'TAG_NAME=2.504.3',
        // TODO: replace by the first LTS based on 2.534+ when available
        'JENKINS_VERSION=2.541.1',
        // Filter out golden file based testing
        // To filter out all tests, set BATS_FLAGS="--filter-tags none"
        'BATS_FLAGS=--filter-tags "\\!test-type:golden-file"'
    ]
}

stage('Build') {
    def builds = [:]

    withEnv(envVars) {
        echo '= bake target: linux'

        def windowsImageTypes = [
            'windowsservercore-ltsc2019',
            'windowsservercore-ltsc2022'
        ]
        for (anImageType in windowsImageTypes) {
            def imageType = anImageType
            builds[imageType] = {
                def windowsVersionNumber = imageType.split('-')[1].replace('ltsc', '')
                def windowsLabel = "windows-${windowsVersionNumber}"
                nodeWithTimeout(windowsLabel) {
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
                                    powershell './make.ps1 build -ImageType ${env:IMAGE_TYPE}'
                                    archiveArtifacts artifacts: 'build-windows_*.yaml', allowEmptyArchive: true
                                }
                            }

                            stage("Test ${imageType}") {
                                infra.withDockerCredentials {
                                    def windowsTestStatus = powershell(script: './make.ps1 test -ImageType ${env:IMAGE_TYPE}', returnStatus: true)
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
                                                powershell './make.ps1 build -ImageType ${env:IMAGE_TYPE}'
                                                powershell './make.ps1 publish -ImageType ${env:IMAGE_TYPE}'
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
            // An up to date list can be obtained with make list-linux
            def images = [
                'alpine_jdk21',
                'alpine_jdk25',
                'debian_jdk21',
                'debian_jdk25',
                'debian-slim_jdk21',
                'debian-slim_jdk25',
                'rhel_jdk21',
                'rhel_jdk25',
            ]
            for (i in images) {
                def imageToBuild = i

                builds[imageToBuild] = {
                    nodeWithTimeout(architecturesAndCiJioAgentLabels["amd64"]) {
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
                                archiveArtifacts artifacts: 'target/build-result-metadata_*.json', allowEmptyArchive: true
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
            // Building every other architectures than amd64 on agents with the corresponding labels if available
            architecturesAndCiJioAgentLabels.findAll { arch, _ -> arch != 'amd64' }.each { architecture, labels ->
                builds[architecture] = {
                    nodeWithTimeout(labels) {
                        stage('Checkout') {
                            deleteDir()
                            checkout scm
                        }
                        // sanity check that proves all images build on declared platforms not already built in other stages
                        stage("Multi arch build - ${architecture}") {
                            infra.withDockerCredentials {
                                sh "make docker-init buildarch-${architecture}"
                                archiveArtifacts artifacts: 'target/build-result-metadata_*.json', allowEmptyArchive: true
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
                                        archiveArtifacts artifacts: 'target/build-result-metadata_*.json', allowEmptyArchive: true
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
