import jenkins.model.*
int executors = System.getenv('JENKINS_EXECUTORS') ? System.getenv('JENKINS_EXECUTORS').toInteger() : 2
Jenkins.instance.setNumExecutors(executors)
