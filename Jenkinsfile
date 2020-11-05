pipeline {
    agent none
    options {
        buildDiscarder(logRotator(artifactNumToKeepStr: '5', numToKeepStr: '50'))
        timeout(time: 60, unit: 'MINUTES')
        timestamps()
    }
    triggers {
        cron '''H H/6 * * 0-2,4-6
H 6,21 * * 3'''
    }
    stages {
        stage('Build') {
            parallel {
                stage('Windows') {
                    agent { label 'windock' }
                    stages {
                        stage('Build-Test') {
                            when {
                                not { expression { isTrusted() } }
                            }
                            steps {
                                powershell './make.ps1'
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
                                allOf {
                                    not { expression { isTrusted() } }
                                    branch 'master'
                                }
                            }
                            steps {
                                withDockerCredentials {
                                    withEnv(['DOCKERHUB_ORGANISATION=jenkins4eval','DOCKERHUB_REPO=jenkins']) {
                                        powershell './make.ps1 publish'
                                    }
                                }
                            }
                        }
                        stage('Publish') {
                            when {
                                expression { isTrusted() }
                            }
                            steps {
                                // TODO transform to function to  avoid scripts{}
                                withDockerCredentials {
                                    withEnv(['DOCKERHUB_ORGANISATION=jenkins','DOCKERHUB_REPO=jenkins']) {
                                        powershell './make.ps1 publish'
                                    }
                                }
                            }
                        }
                    }
                    post {
                        always {
                            powershell(script: '& docker system prune --force --all', returnStatus: true)
                        }
                    }
                }
                stage('Linux') {
                    agent { label 'docker&&linux' }
                    when {
                        not { expression { isTrusted() } }
                    }
                    stages {
                        stage('Build-Test') {
                            when {
                                not { expression { isTrusted() } }
                            }
                            steps {
                                sh 'make all'
                            }
                            post {
                                always {
                                    junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'target/*.xml')
                                }
                            }
                        }
                        stage('Publish Experimental') {
                            when {
                                allOf {
                                    not { expression { isTrusted() } }
                                    branch 'master'
                                }
                            }
                            steps {
                                withDockerCredentials {
                                    sh 'make publish-experimental'
                                }
                            }
                        }
                        stage('Publish') {
                            when {
                                expression { isTrusted() }
                            }
                            steps {
                                withDockerCredentials {
                                    sh 'make publish'
                                }
                            }
                        }
                    }
                    post {
                        always {
                            sh(script: 'docker system prune --force --all', returnStatus: true)
                        }
                    }
                }
            }
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