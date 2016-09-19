package com.camiloribeiro.cdeasy.view

import javaposse.jobdsl.dsl.DslFactory

class ViewHelper {
    def static addView(DslFactory dslFactory, String viewName, String viewDescription, String viewegex) {
        dslFactory.listView(viewName) {
            description(viewDescription)
            filterBuildQueue()
            filterExecutors()
            jobs {
                regex(viewegex)
            }
            columns {
                status()
                weather()
                name()
                lastSuccess()
                lastFailure()
                lastDuration()
                buildButton()
            }
        }
    }
}

