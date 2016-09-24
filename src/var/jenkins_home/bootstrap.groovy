job('bootstrap') {
    scm {
      git {
        remote {
          url System.getenv('JENKINS_BOOTSTRAP_REPOSITORY');
          credentials 'git'
        }
        branch 'develop'
      }
    }
    triggers {
        scm 'H/5 * * * *'
    }
    steps {
        dsl {
            external 'dsl/**/*.groovy'
        }
    }
    publishers {
    }
}
