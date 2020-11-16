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
        stage('Build') {
            parallel {
                stage('Windows') {
                    agent { label 'windock' }
                    when {
                        beforeAgent true
                        not { expression { isTrusted() } }
                    }
                    stages {
                        stage('Build') {
                            steps {
                                powershell './make.ps1'
                            }
                        }
                        stage('Test') {
                            steps {
                                powershell './make.ps1 test'
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
                            }
                            steps {
                                withDockerCredentials {
                                    withEnv(['DOCKERHUB_ORGANISATION=jenkins4eval','DOCKERHUB_REPO=jenkins']) {
                                        powershell './make.ps1 publish'
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
                stage('Windows-Publish') {
                    agent { label 'windock' }
                    when {
                        beforeAgent true
                        expression { isTrusted() }
                    }
                    steps {
                        withDockerCredentials {
                            withEnv(['DOCKERHUB_ORGANISATION=jenkins','DOCKERHUB_REPO=jenkins']) {
                                powershell './make.ps1 publish'
                            }
                        }
                    }
                    post {
                        always {
                            dockerCleanup()
                        }
                    }
                }
                stage('Linux') {
                    agent { label 'docker&&linux' }
                    when {
                        beforeAgent true
                        not { expression { isTrusted() } }
                    }
                    stages {
                        stage('Build') {
                            steps {
                                sh 'make build'
                            }
                        }
                        stage('Test') {
                            steps {
                                sh 'make test-debian test-slim test-alpine test-jdk11 test-centos test-centos7'
                            }
                            post {
                                always {
                                    junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'target/*.xml')
                                }
                            }
                        }
                        stage('Publish Experimental') {
                            when { branch 'master' }
                            steps {
                                withDockerCredentials {
                                    sh 'make publish-tags'
                                    sh 'make publish-manifests'
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
                stage('Linux-Publish') {
                    agent { label 'docker&&linux' }
                    when {
                        beforeAgent true
                        expression { isTrusted() }
                    }
                    steps {
                        withDockerCredentials {
                            sh 'make publish'
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
}

// Wrapper to cleanup the docker images
def dockerCleanup() {
    if(isUnix()) {
        sh(script: 'docker system prune --force --all', returnStatus: true)
    } else {
        powershell(script: '& docker system prune --force --all', returnStatus: true)
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