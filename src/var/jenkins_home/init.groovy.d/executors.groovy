import jenkins.model.*
Jenkins.instance.setNumExecutors(System.getenv('EXECUTORS').toInteger())
