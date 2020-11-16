pipeline {
    agent none
    options {
        buildDiscarder(logRotator(artifactNumToKeepStr: '5', numToKeepStr: '50'))
        timeout(time: 60, unit: 'MINUTES')
        timestamps()
    }
    triggers {
        cron(env.BRANCH_NAME == 'master' ? '''H H/6 * * 0-2,4-6
H 6,21 * * 3''' : '')
    }
    stages {
        stage('BuildAndTest') {
            matrix {
                agent { label "${PLATFORM.equals('windows') ? 'winlock' : 'linux'}" }
                axes {
                    axis {
                        name 'PLATFORM'
                        values 'amd64', 'arm64', 's390x', 'ppc64le', 'windows'
                    }
                    axis {
                        name 'FLAVOR'
                        values 'debian', 'slim', 'alpine', 'jdk11', 'centos', 'centos7', 'windows'
                    }
                }
                excludes {
                    exclude {
                        axis {
                            name 'PLATFORM'
                            notValues 'windows'
                        }
                        axis {
                            name 'FLAVOR'
                            values 'windows'
                        }
                    }
                    exclude {
                        axis {
                            name 'PLATFORM'
                            values 'arm64'
                        }
                        axis {
                            name 'FLAVOR'
                            notValues 'debian', 'slim', 'jdk11'
                        }
                    }
                    exclude {
                        axis {
                            name 'PLATFORM'
                            values 's390x'
                        }
                        axis {
                            name 'FLAVOR'
                            notValues 'jdk11'
                        }
                    }
                    exclude {
                        axis {
                            name 'PLATFORM'
                            values 'ppc64le'
                        }
                        axis {
                            name 'FLAVOR'
                            notValues 'jdk11'
                        }
                    }
                }
                stages {
                    stage('Build') {
                        when {
                            expression { !isTrusted() }
                        }
                        steps {
                            cmd(linux: "make build-${FLAVOR}", windows: './make.ps1')
                        }
                    }
                    stage('Test') {
                        when {
                            expression { !isTrusted() }
                        }
                        steps {
                            cmd(linux: "make prepare-test test-${FLAVOR}", windows: './make.ps1 test')
                        }
                        post {
                            always {
                                junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'target/**/junit-results.xml')
                            }
                        }
                    }
                    stage('Publish Experimental') {
                        when {
                            branch 'master'
                            expression { !isTrusted() }
                        }
                        steps {
                            withDockerCredentials {
                                withEnv(['DOCKERHUB_ORGANISATION=jenkins4eval','DOCKERHUB_REPO=jenkins']) {
                                    cmd(linux: 'make publish-tags publish-manifests', windows: './make.ps1 publish')
                                }
                            }
                        }
                    }
                    stage('Publish') {
                        when {
                            beforeAgent true
                            expression { isTrusted() }
                        }
                        steps {
                            withDockerCredentials {
                                withEnv(['DOCKERHUB_ORGANISATION=jenkins','DOCKERHUB_REPO=jenkins']) {
                                    cmd(linux: 'make publish', windows: './make.ps1 publish')
                                }
                            }
                        }
                    }
                }
                post {
                    always {
                        dockerCleanup()
                    }
                }
            }
        }
    }
}

// Wrapper to call a command OS agnostic
def cmd(args) {
    def returnStatus = args.get('returnStatus', false)
    if(isUnix) {
        sh(script: args.linux, returnStatus: returnStatus)
    } else {
        powershell(script: args.windows, returnStatus: returnStatus)
    }
}

// Wrapper to cleanup the docker images
def dockerCleanup() {
    cmd(linux: 'docker system prune --force --all',
        windows: '& docker system prune --force --all',
        returnStatus: true)
}

// Wrapper to avoid the script closure in the declarative pipeline
def isTrusted() {
    return infra.isTrusted()
}

// Wrapper to avoid the script closure in the declarative pipeline
def withDockerCredentials(body) {
    infra.withDockerCredentials {
        body()
    }
}