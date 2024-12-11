#!/usr/bin/env groovy

def createEnvironmentVariables(simulateLtsBuild) {
    return simulateLtsBuild ? [
        "PUBLISH=false",
        "TAG_NAME=2.462.3",
        "JENKINS_VERSION=2.462.3",
        "JENKINS_SHA=3e53b52a816405e3b10ad07f1c48cd0cb5cb3f893207ef7f9de28415806b93c1"
    ] : ["PUBLISH=true"]
}

def buildWindowsImages(windowsImageTypes, envVars) {
    def builds = [:]
    windowsImageTypes.each { imageType ->
        builds[imageType] = {
            nodeWithTimeout('windows-2019') {
                stage("Checkout ${imageType}") { checkout scm }
                withEnv(["IMAGE_TYPE=${imageType}"] + envVars) {
                    stage("Build ${imageType}") {
                        infra.withDockerCredentials { powershell './make.ps1' }
                    }
                    stage("Test ${imageType}") {
                        infra.withDockerCredentials {
                            def testStatus = powershell(script: './make.ps1 test', returnStatus: true)
                            junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'target/**/junit-results.xml')
                            if (testStatus > 0) error('Windows test stage failed.')
                        }
                    }
                }
            }
        }
    }
    return builds
}

def buildLinuxImages(images, envVars) {
    def builds = [:]
    images.each { imageToBuild ->
        builds[imageToBuild] = {
            nodeWithTimeout('docker') {
                stage("Checkout ${imageToBuild}") { checkout scm }
                stage('Static Analysis') { sh 'make hadolint shellcheck' }
                stage("Build ${imageToBuild}") {
                    infra.withDockerCredentials { sh "make build-${imageToBuild}" }
                }
                stage("Test ${imageToBuild}") {
                    try {
                        infra.withDockerCredentials { sh "make test-${imageToBuild}" }
                    } catch (err) {
                        error("${err.toString()}")
                    } finally {
                        junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'target/*.xml')
                    }
                }
            }
        }
    }
    return builds
}

def buildMultiArch(envVars) {
    return {
        nodeWithTimeout('docker') {
            stage('Checkout') { checkout scm }
            stage('Multi-Arch Build') {
                infra.withDockerCredentials {
                    sh '''
                        docker buildx create --use
                        docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
                        docker buildx bake --file docker-bake.hcl linux
                    '''
                }
            }
        }
    }
}

def buildAndPublishLinux(tagName, publish, envVars) {
    return {
        if (tagName) {
            def jenkinsVersion = tagName.split('-')[0]
            withEnv(["JENKINS_VERSION=${jenkinsVersion}"] + envVars) {
                nodeWithTimeout('docker') {
                    stage('Checkout') { checkout scm }
                    if (publish) {
                        stage('Publish') {
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

def envVars = createEnvironmentVariables(false)
def builds = [:]

if (!infra.isTrusted()) {
    builds += buildWindowsImages(['windowsservercore-ltsc2019'], envVars)
    builds += buildLinuxImages(['alpine_jdk17', 'debian_jdk17', 'rhel_ubi9_jdk21'], envVars)
    builds['multiarch-build'] = buildMultiArch(envVars)
} else {
    builds['linux'] = buildAndPublishLinux(env.TAG_NAME, env.PUBLISH == "true", envVars)
}

parallel builds

void nodeWithTimeout(String label, def body) {
    node(label) {
        timeout(time: 60, unit: 'MINUTES') { body.call() }
    }
}
