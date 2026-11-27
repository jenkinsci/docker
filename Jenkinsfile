#!/usr/bin/env groovy

def listOfProperties = []
listOfProperties << buildDiscarder(logRotator(numToKeepStr: '50', artifactNumToKeepStr: '5'))

// Only master branch will run on a timer basis
if (env.BRANCH_NAME.trim() == 'master') {
    listOfProperties << pipelineTriggers([cron('''H H/6 * * 0-2,4-6
H 6,21 * * 3''')])
}

properties(listOfProperties)

// List of targets to build on ci.jenkins.io and the agent they should use
def allImagesTypes = [
    'alpine_jdk21': [agent: 'linux'],
    'alpine_jdk25': [agent: 'linux'],
    'debian_jdk21': [agent: 'linux'],
    'debian_jdk25': [agent: 'linux'],
    'debian-slim_jdk21': [agent: 'linux'],
    'debian-slim_jdk25': [agent: 'linux'],
    'rhel_jdk21': [agent: 'linux'],
    'rhel_jdk25': [agent: 'linux'],
    'windowsservercore-ltsc2022': [agent: 'windows-2025'],
    'windowsservercore-ltsc2025': [agent: 'windows-2025'],
    // List of other dedicated architecture Linux builds and corresponding ci.jenkins.io agent labels
    // Note: skipped for tests, and for publication on trusted.ci.jenkins.io (Linux builds are multiarch there)
    'multiarch_arm64': [agent: 'arm64docker'],
    // Using qemu
    'multiarch_ppc64le': [agent: 'docker && amd64'],
    'multiarch_riscv64': [agent: 'docker && amd64'],
    'multiarch_s390x': [agent: 'docker && amd64'],
]

def onTrustedCi = infra.isTrustedCiController()
if (onTrustedCi) {
    // No multiarch builds on trusted.ci.jenkins.io
    allImagesTypes = allImagesTypes.findAll { imageType, config ->
        !imageType.startsWith('multiarch_')
    }
}

// Default environment variables
def envVars = []
if (env.TAG_NAME) {
    // Split to ensure any suffix is not taken in account (but allow suffix tags to trigger rebuilds)
    def jenkinsVersion = env.TAG_NAME.split('-')[0]
    envVars += ["JENKINS_VERSION=${jenkinsVersion}"]
    if (onTrustedCi) {
        // Setting WAR_URL to download war from Artifactory instead of mirrors on publication
        envVars += ["WAR_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${jenkinsVersion}/jenkins-war-${jenkinsVersion}.war"]
        // PUBLISH set to allow images publication
        envVars += 'PUBLISH=true'
    }
}

def builds = [:]
allImagesTypes.each { imageType, imageParams ->
    def skipTests
    def buildTarget = 'build-' + imageType
    def multiarchBuild = imageType.startsWith('multiarch_')
    if (multiarchBuild) {
        // Sanity check that proves all images build on declared platforms not already built in other stages
        buildTarget = 'buildarch-' + imageType.replace('multiarch_', '')
        skipTests = 'No tests on multiarch builds'
    }
    if (onTrustedCi) {
        skipTests = 'No tests on trusted.ci.jenkins.io'
    }
    builds[imageType] = {
        nodeWithTimeout(imageParams.agent) {
            withEnv(envVars + [
                "IMAGE_TYPE=${imageType}",
                "BUILD_TARGET=${buildTarget}",
            ]) {
                stage('Checkout') {
                    checkout scm
                }

                stage('Static analysis') {
                    if (isUnix()) {
                        sh 'make hadolint shellcheck'
                    } else {
                        echo 'hadolint executed only from Linux'
                    }
                }

                stage('Build') {
                    if (isUnix()) {
                        if (multiarchBuild || onTrustedCi) {
                            sh 'make docker-init'
                        }
                        sh 'make "${BUILD_TARGET}"'
                        archiveArtifacts artifacts: 'target/build-result-metadata_*.json', allowEmptyArchive: true
                    } else {
                        // JDK21 only
                        powershell '''
                        (Get-Content docker-bake.hcl -Raw) -replace '(variable\\s+"java_releases_to_build"\\s*{\\s*default\\s*=\\s*)\\[[^\\]]*\\]', '$1[21]' | Set-Content docker-bake.hcl
                        ./make.ps1 build -ImageType ${env:IMAGE_TYPE} -OverwriteDockerComposeFile
                        '''

                        // JDK25 only
                        powershell '''
                        (Get-Content docker-bake.hcl -Raw) -replace '(variable\\s+"java_releases_to_build"\\s*{\\s*default\\s*=\\s*)\\[[^\\]]*\\]', '$1[25]' | Set-Content docker-bake.hcl
                        ./make.ps1 build -ImageType ${env:IMAGE_TYPE} -OverwriteDockerComposeFile
                        '''

                        archiveArtifacts artifacts: 'build-windows_*.yaml', allowEmptyArchive: true
                    }
                }

                stage('Test') {
                    if (skipTests) {
                        echo skipTests
                        return
                    }

                    try {
                        if (isUnix()) {
                            sh 'make prepare-test'
                            sh 'make "test-${IMAGE_TYPE}"'
                        } else {
                            def windowsTestStatus = powershell(
                                script: '''
                                (Get-Content docker-bake.hcl -Raw) -replace '(variable\\s+"java_releases_to_build"\\s*{\\s*default\\s*=\\s*)\\[[^\\]]*\\]', '$1[21]' | Set-Content docker-bake.hcl
                                ./make.ps1 test -ImageType ${env:IMAGE_TYPE} -OverwriteDockerComposeFile
                                (Get-Content docker-bake.hcl -Raw) -replace '(variable\\s+"java_releases_to_build"\\s*{\\s*default\\s*=\\s*)\\[[^\\]]*\\]', '$1[25]' | Set-Content docker-bake.hcl
                                ./make.ps1 test -ImageType ${env:IMAGE_TYPE} -OverwriteDockerComposeFile
                                ''',
                                returnStatus: true
                            )
                            if (windowsTestStatus > 0) {
                                // If something bad happened let's clean up the docker images
                                error('Windows test stage failed.')
                            }
                        }
                    } catch (err) {
                        error("${err.toString()}")
                    } finally {
                        junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'target/**/*.xml')
                    }
                }

                if (onTrustedCi) {
                    stage('Publish') {
                        // Only publish when a tag triggered the build
                        if (!env.TAG_NAME) {
                            echo 'No tag: no publication'
                            return
                        }
                        infra.withDockerCredentials {
                            withEnv([
                                'DOCKERHUB_ORGANISATION=jenkins',
                                'DOCKERHUB_REPO=jenkins',
                                "BAKE_TARGET=${imageType}",
                            ]) {
                                if (isUnix()) {
                                    sh 'make publish'
                                } else {
                                    // JDK21 only
                                    powershell '''
                                    (Get-Content docker-bake.hcl -Raw) -replace '(variable\\s+"java_releases_to_build"\\s*{\\s*default\\s*=\\s*)\\[[^\\]]*\\]', '$1[21]' | Set-Content docker-bake.hcl
                                    ./make.ps1 publish -ImageType ${env:IMAGE_TYPE}
                                    '''

                                    // JDK25 only
                                    powershell '''
                                    (Get-Content docker-bake.hcl -Raw) -replace '(variable\\s+"java_releases_to_build"\\s*{\\s*default\\s*=\\s*)\\[[^\\]]*\\]', '$1[25]' | Set-Content docker-bake.hcl
                                    ./make.ps1 publish -ImageType ${env:IMAGE_TYPE}
                                    '''
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

parallel builds

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
