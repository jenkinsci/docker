job('bootstrap') {
    scm {
        github 'flavioaiello/jenkins'
    }
    triggers {
        scm 'H/5 * * * *'
    }
    steps {
        dsl {
            external 'src/var/jenkins_home/jobs/**/*.groovy'
        }
    }
    publishers {
    }
}
