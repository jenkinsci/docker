job('bootstrap') {
    scm {
        github(System.getenv('JENKINS_BOOTSTRAP_REPOSITORY'))
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
