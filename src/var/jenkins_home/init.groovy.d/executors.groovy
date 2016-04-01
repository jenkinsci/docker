import jenkins.model.*
int executors = System.getenv('EXECUTORS') ? System.getenv('EXECUTORS').toInteger() : 2
Jenkins.instance.setNumExecutors(executors)
