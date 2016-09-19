package com.camiloribeiro.cdeasy.view

import spock.lang.*
import static com.camiloribeiro.cdeasy.support.SupportTestHelper.getJobParent

@Unroll
class ViewHelperTest extends Specification {


    def "Should create a view"() {

        given:
        def baseView = new ViewHelper()
        def viewName = 'Test'
        def viewDescription = 'Testing'
        def viewRegex = 'foo.+'

        when:
        def view = baseView.addView(getJobParent(), viewName, viewDescription, viewRegex)

        then:
        with(view.node) {
            view.name == viewName
            view.node.description[0].value() == viewDescription
            view.node.includeRegex[0].value() == viewRegex
        }

    }
}

