#!/usr/bin/env groovy

def listOfProperties = []
listOfProperties << buildDiscarder(logRotator(numToKeepStr: '50', artifactNumToKeepStr: '5'))

// Only master branch will run on a timer basis
if (env.BRANCH_NAME.trim() == 'master') {
    listOfProperties << pipelineTriggers([cron('''H H/6 * * 0-2,4-6
H 6,21 * * 3''')])
}

properties(listOfProperties)

// List of targets to build
def allImagesTypes = [
    'alpine_jdk21',
    'alpine_jdk25',
    'debian_jdk21',
    'debian_jdk25',
    'debian-slim_jdk21',
    'debian-slim_jdk25',
    'rhel_jdk21',
    'rhel_jdk25',
    'windowsservercore-ltsc2022',
    'windowsservercore-ltsc2025',
    // List of other dedicated architecture Linux builds
    // Sanity check that proves all images build on declared platforms not already built above
    // Note: skipped for tests, and for publication on trusted.ci.jenkins.io (Linux builds are multiarch there)
    'archcheck_arm64',
    'archcheck_ppc64le',
    'archcheck_riscv64',
    'archcheck_s390x',
]

// Publication only on trusted.ci.jenkins.io
def doPublish = infra.isTrustedCiController()
if (doPublish) {
    // No architecture checks on trusted.ci.jenkins.io
    allImagesTypes = allImagesTypes.findAll { imageType, config ->
        !imageType.startsWith('archcheck_')
    }
}

// Default environment variables
def envVars = []
if (env.TAG_NAME) {
    // Split to ensure any suffix is not taken in account (but allow suffix tags to trigger rebuilds)
    def jenkinsVersion = env.TAG_NAME.split('-')[0]
    envVars += ["JENKINS_VERSION=${jenkinsVersion}"]
    if (doPublish) {
        // Setting WAR_URL to download war from Artifactory instead of mirrors on publication
        envVars += ["WAR_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${jenkinsVersion}/jenkins-war-${jenkinsVersion}.war"]
        // PUBLISH set to allow images publication on Docker Hub
        envVars += 'PUBLISH=true'
    }
}

def builds = [:]
allImagesTypes.each { imageType ->
    def label
    def buildTarget = 'build-' + imageType
    def skip = doPublish ? 'on publication' : ''
    def architecture
    switch (imageType) {
        case ~/windows.*/:
            label = 'windows-2025'
            break
        case ~/archcheck_.*/:
            architecture = imageType.replace('archcheck_', '')
            // arm64 agents available on ci.jenkins.io and trusted.ci, or qemu emulation from amd64 agents
            label = (architecture == 'arm64') ? 'arm64docker' : 'docker && amd64'
            buildTarget = 'buildarch-' + architecture
            skip = skip ?: 'on architecture checks' // if not already skipped with doPublish
            break
        default:
            label = 'linux'
    }
    builds[imageType] = {
        nodeWithTimeout(label) {
            withEnv(envVars + [
                "IMAGE_TYPE=${imageType}",
                "BUILD_TARGET=${buildTarget}",
            ]) {
                stage('Checkout') {
                    checkout scm
                }

                if (skip || !isUnix()) {
                    echo "Skipping static analysis ${skip ? skip : 'on Windows'}"
                } else {
                    stage('Static analysis') {
                        sh 'make hadolint shellcheck'
                    }
                }

                stage('Build') {
                    if (isUnix()) {
                        if (architecture || doPublish) {
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

                if (skip) {
                    echo "Skipping tests ${skip}"
                } else {
                    stage('Test') {
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
                }

                if (doPublish) {
                    stage('Publish') {
                        // Only publish when a tag triggered the build
                        if (!env.TAG_NAME) {
                            echo 'No tag: no publication'
                            return
                        }
                        infra.withContainerRegistry {
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
