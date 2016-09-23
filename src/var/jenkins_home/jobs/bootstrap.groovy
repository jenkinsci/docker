job('bootstrap') {
    scm {
        github 'flavioaiello/jenkins'
    }
    triggers {
        scm 'H/5 * * * *'
    }
    steps {
        dsl {
            external 'jobs/**/*.groovy'
            additionalClasspath 'src/main/groovy'
        }
    }
    publishers {
        archiveJunit 'build/test-results/**/*.xml'
    }
}
