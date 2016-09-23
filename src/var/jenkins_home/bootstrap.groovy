job('bootstrap') {
    scm {
        github build.environment.get("JENKINS_BOOTSTRAP_REPOSITORY")
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
