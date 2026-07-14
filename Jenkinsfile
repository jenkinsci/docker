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

// List of dedicated architecture Linux builds
// Note: not taken in account on trusted.ci.jenkins.io as Linux builds are multiarch there
def architecturesOnCiJioAgentLabels = [
    'amd64',
    'arm64',
    // Using qemu
    'ppc64le',
    'riscv64',
    's390x',
]
// List of Windows image types to build on both ci.jenkins.io and trusted.ci.jenkins.io
def windowsImageTypes = [
    'windowsservercore-ltsc2022',
    'windowsservercore-ltsc2025',
]
// List of Linux targets to build on ci.jenkins.io
// An up to date list can be obtained with make list-linux
def linuxTargetsOnCiJenkinsIo = [
    'alpine_jdk21',
    'alpine_jdk25',
    'debian_jdk21',
    'debian_jdk25',
    'debian-slim_jdk21',
    'debian-slim_jdk25',
    'rhel_jdk21',
    'rhel_jdk25',
]

// List of Linux targets to build on trusted.ci.jenkins.io
def linuxTargetsOnTrustedCiJenkinsIo = [
    'linux',
]

stage('Build') {
    def builds = [:]

    withEnv(envVars) {
        for (anImageType in windowsImageTypes) {
            def imageType = anImageType
            builds[imageType] = {
                nodeWithRetry(image: imageType) {
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
            for (t in linuxTargetsOnCiJenkinsIo) {
                def targetToBuild = t

                builds[targetToBuild] = {
                    nodeWithRetry(image: targetToBuild) {
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
            architecturesOnCiJioAgentLabels.findAll { architecture -> architecture != 'amd64' }.each { architecture ->
                builds[architecture] = {
                    nodeWithRetry(image: targetToBuild) {
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
                for (t in linuxTargetsOnTrustedCiJenkinsIo) {
                    def targetToBuild = t

                    builds[targetToBuild] = {
                        // Setting WAR_URL to download war from Artifactory instead of mirrors on publication from trusted.ci.jenkins.io
                        withEnv([
                            "JENKINS_VERSION=${jenkins_version}",
                            "WAR_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${jenkins_version}/jenkins-war-${jenkins_version}.war"
                        ]) {
                            nodeWithRetry(image: targetToBuild) {
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
        }

        parallel builds
    }
}

void nodeWithRetry(params = [:]) {
    def image
    def platform
    if (params.containsKey('image')) {
        image = params['image']
    }
    switch (image) {
        case ~/.*2022/:
            platform = 'windows-2022'
            break

        case ~/.*2025/:
            platform = 'windows-2025'
            break

        case 'arm64':
            platform = 'arm64docker'
            break

        default:
            // Building everything else than windows or arm64 images from an amd64 agent
            platform = 'docker && amd64'
            break
    }

    int retryCounter = 0
    int maxRetries = 2
    if (params.containsKey('maxRetries')) {
        maxRetries = params['maxRetries']
    }

    retry(count: maxRetries, conditions: [agent(), nonresumable()]) {
        // Use local variable to manage concurrency and increment BEFORE spinning up any agent
        final String label = infra.getBuildAgentLabel([
            useContainerAgent: false,
            platform: platform,
            spotRetryCounter: retryCounter
        ])
        retryCounter++
        node(label) {
            timeout(time: 60, unit: 'MINUTES') {
                body.call()
            }
        }
    }
}
