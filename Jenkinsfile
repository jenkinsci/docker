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
                agent { label "${PLATFORM.equals('windows') ? 'winlock' : 'docker'}" }
                axes {
                    axis {
                        name 'PLATFORM'
                        values 'almalinux', 'alpine', 'centos7', 'debian8', 'debian_slim', 'rhel_ubi8', 'windows'
                    }
                    axis {
                        name 'FLAVOR'
                        values 'jdk8', 'jdk11', 'jdk17', 'ONCE'
                        // ONCE value helps to exclude the matrix only for windows once
                        // or enabling the the multiarch-build stage only once.
                    }
                }
                excludes {
                    exclude {
                        // This is the trick to allow running windows in the same matrix ONLY once
                        axis {
                            name 'PLATFORM'
                            notValues 'windows'
                        }
                        axis {
                            name 'FLAVOR'
                            values 'ONCE'
                        }
                    }
                    exclude {
                        axis {
                            name 'PLATFORM'
                            values 'almalinux'
                        }
                        axis {
                            name 'FLAVOR'
                            notValues 'jdk11'
                        }
                    }
                    exclude {
                        axis {
                            name 'PLATFORM'
                            values 'alpine'
                        }
                        axis {
                            name 'FLAVOR'
                            notValues 'jdk8', 'jdk11'
                        }
                    }
                    exclude {
                        axis {
                            name 'PLATFORM'
                            values 'centos7'
                        }
                        axis {
                            name 'FLAVOR'
                            notValues 'jdk8', 'jdk11'
                        }
                    }
                    exclude {
                        axis {
                            name 'PLATFORM'
                            values 'debian_slim'
                        }
                        axis {
                            name 'FLAVOR'
                            notValues 'jdk8', 'jdk11'
                        }
                    }
                    exclude {
                        axis {
                            name 'PLATFORM'
                            values 'rhel_ubi8'
                        }
                        axis {
                            name 'FLAVOR'
                            notValues 'jdk11'
                        }
                    }
                }
                stages {
                    stage('Shellcheck') {
                        when {
                            expression { !isTrusted() && PLATFORM.equals('windows') }
                        }
                        steps {
                            cmd(linux: "make shellcheck")
                        }
                    }
                    stage('Build') {
                        when {
                            expression { !isTrusted() }
                        }
                        steps {
                            cmd(linux: "make build-${PLATFORM}_${FLAVOR}", windows: './make.ps1')
                        }
                    }
                    stage('Test') {
                        when {
                            expression { !isTrusted() }
                        }
                        steps {
                            withDockerCredentials {
                                cmd(linux: "make prepare-test test-${PLATFORM}_${FLAVOR}")
                            }
                            cmd(windows: './make.ps1 test')
                        }
                        post {
                            always {
                                junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'target/*.xml,target/**/junit-results.xml')
                            }
                        }
                    }
                    stage('Multiarch-Build') {
                        when {
                            expression { !isTrusted() && FLAVOR.equals('ONCE') }
                        }
                        steps {
                            withDockerCredentials {
                                cmd(linux: '''
                                    docker buildx create --use
                                    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
                                    docker buildx bake --file docker-bake.hcl linux
                                ''')
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
                    stage('Publish Windows') {
                        when {
                            beforeAgent true
                            expression { isTrusted() && PLATFORM.equals('windows') && FLAVOR.equals('ONCE') }
                        }
                        steps {
                            withDockerCredentials {
                                withEnv(['DOCKERHUB_ORGANISATION=jenkins','DOCKERHUB_REPO=jenkins']) {
                                    cmd(windows: './make.ps1 publish')
                                }
                            }
                        }
                    }
                    stage('Publish Linux') {
                        when {
                            beforeAgent true
                            expression { isTrusted() && !PLATFORM.equals('windows') && FLAVOR.equals('ONCE') }
                        }
                        steps {
                            withDockerCredentials {
                                cmd(linux: '''
                                    docker buildx create --use
                                    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
                                    make publish
                                ''')
                            }
                        }
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
        if (args.containsKey('linux')) {
            sh(script: args.linux, returnStatus: returnStatus)
        }
    } else {
        if (args.containsKey('windows')) {
            powershell(script: args.windows, returnStatus: returnStatus)
        }
    }
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
