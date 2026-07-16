#!/usr/bin/env groovy

def listOfProperties = []
listOfProperties << buildDiscarder(logRotator(numToKeepStr: '50', artifactNumToKeepStr: '5'))

// Only master branch will run on a timer basis
if (env.BRANCH_NAME.trim() == 'master') {
    listOfProperties << pipelineTriggers([cron('''H H/6 * * 0-2,4-6
H 6,21 * * 3''')])
}

properties(listOfProperties)

// Default environment variable set to allow images publication from trusted.ci.jenkins.io
def envVars = ['PUBLISH=true']

// List of dedicated architecture Linux builds and corresponding ci.jenkins.io agent labels
// Note: not taken in account on trusted.ci.jenkins.io as Linux builds are multiarch there
def architecturesAndCiJioAgentLabels = [
    'amd64': 'docker && amd64',
    'arm64': 'arm64docker',
    // Using qemu
    'ppc64le': 'docker && amd64',
    'riscv64': 'docker && amd64',
    's390x': 'docker && amd64',
]
// List of Windows image types to build on ci.jenkins.io and trusted.ci.jenkins.io
def windowsImageTypes = [
    'windowsservercore-ltsc2022',
    'windowsservercore-ltsc2025',
]
// List of Linux targets to build on ci.jenkins.io
// An up to date list can be obtained with make list-linux
// Note: on trusted.ci.jenkins.io, the 'linux' target is used instead
def linuxTargets = [
    'alpine_jdk21',
    'alpine_jdk25',
    'debian_jdk21',
    'debian_jdk25',
    'debian-slim_jdk21',
    'debian-slim_jdk25',
    'rhel_jdk21',
    'rhel_jdk25',
]

stage('Build') {
    def builds = [:]

    withEnv(envVars) {
        for (anImageType in windowsImageTypes) {
            def imageType = anImageType
            builds[imageType] = {
                nodeWithTimeout('windows-2025') {
                    stage('Checkout') {
                        checkout scm
                    }

                    withEnv(["IMAGE_TYPE=${imageType}"]) {
                        if (!infra.isTrusted()) {
                            /* Outside of the trusted.ci environment, we're building and testing
                            * the Dockerfile in this repository, but not publishing to docker hub
                            */
                            stage("Build ${imageType}") {
                                // JDK21 only
                                powershell '''
                                (Get-Content docker-bake.hcl -Raw) -replace '(variable\\s+"jdks_to_build"\\s*{\\s*default\\s*=\\s*)\\[[^\\]]*\\]', '$1[21]' | Set-Content docker-bake.hcl
                                ./make.ps1 build -ImageType ${env:IMAGE_TYPE} -OverwriteDockerComposeFile
                                '''

                                // JDK25 only
                                powershell '''
                                (Get-Content docker-bake.hcl -Raw) -replace '(variable\\s+"jdks_to_build"\\s*{\\s*default\\s*=\\s*)\\[[^\\]]*\\]', '$1[25]' | Set-Content docker-bake.hcl
                                ./make.ps1 build -ImageType ${env:IMAGE_TYPE} -OverwriteDockerComposeFile
                                '''

                                archiveArtifacts artifacts: 'build-windows_*.yaml', allowEmptyArchive: true
                            }

                            stage("Test ${imageType}") {
                                def windowsTestStatus = powershell(
                                    script: '''
                                        (Get-Content docker-bake.hcl -Raw) -replace '(variable\\s+"jdks_to_build"\\s*{\\s*default\\s*=\\s*)\\[[^\\]]*\\]', '$1[21]' | Set-Content docker-bake.hcl
                                        ./make.ps1 test -ImageType ${env:IMAGE_TYPE} -OverwriteDockerComposeFile
                                        (Get-Content docker-bake.hcl -Raw) -replace '(variable\\s+"jdks_to_build"\\s*{\\s*default\\s*=\\s*)\\[[^\\]]*\\]', '$1[25]' | Set-Content docker-bake.hcl
                                        ./make.ps1 test -ImageType ${env:IMAGE_TYPE} -OverwriteDockerComposeFile
                                    ''',
                                    returnStatus: true
                                )
                                junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'target/**/junit-results.xml')
                                if (windowsTestStatus > 0) {
                                    // If something bad happened let's clean up the docker images
                                    error('Windows test stage failed.')
                                }
                            }
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
                                                // JDK21 only
                                                powershell '''
                                                (Get-Content docker-bake.hcl -Raw) -replace '(variable\\s+"jdks_to_build"\\s*{\\s*default\\s*=\\s*)\\[[^\\]]*\\]', '$1[21]' | Set-Content docker-bake.hcl
                                                '''
                                                powershell './make.ps1 build -ImageType ${env:IMAGE_TYPE} -OverwriteDockerComposeFile'
                                                powershell './make.ps1 publish -ImageType ${env:IMAGE_TYPE}'

                                                // JDK25 only
                                                powershell '''
                                                (Get-Content docker-bake.hcl -Raw) -replace '(variable\\s+"jdks_to_build"\\s*{\\s*default\\s*=\\s*)\\[[^\\]]*\\]', '$1[25]' | Set-Content docker-bake.hcl
                                                '''
                                                powershell './make.ps1 build -ImageType ${env:IMAGE_TYPE} -OverwriteDockerComposeFile'
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
            for (t in linuxTargets) {
                def targetToBuild = t

                builds[targetToBuild] = {
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
                        stage("Build linux-${targetToBuild}") {
                            sh "make build-${targetToBuild}"
                            archiveArtifacts artifacts: 'target/build-result-metadata_*.json', allowEmptyArchive: true
                        }

                        stage("Test linux-${targetToBuild}") {
                            sh 'make prepare-test'
                            try {
                                sh "make test-${targetToBuild}"
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
                            sh "make docker-init buildarch-${architecture}"
                            archiveArtifacts artifacts: 'target/build-result-metadata_*.json', allowEmptyArchive: true
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
    int retryCounter = 0
    retry(count: 2, conditions: [agent(), nonresumable()]) {
        String resolvedAgentLabel = label
        
        resolvedAgentLabel = infra.getBuildAgentLabel([
            useContainerAgent: false,
            platform: label,
            spotRetryCounter: retryCounter
        ])
        
        retryCounter++
        node(resolvedAgentLabel) {
            timeout(time: 60, unit: 'MINUTES') {
                body.call()
            }
        }
    }
}
