package com.camiloribeiro.cdeasy.view

import spock.lang.Specification
import spock.lang.Unroll

import static com.camiloribeiro.cdeasy.support.SupportTestHelper.getJobParent

@Unroll
class PipelineHelperTest extends Specification{

    def "Should create a a pipeline"() {

        given:
        def pipeline = new PipelineHelper()

        when:
        def view = pipeline.addPipeline(getJobParent(), "foo")

        then:
        with(view.node.'componentSpecs'[0].'se.diabol.jenkins.pipeline.DeliveryPipelineView_-ComponentSpec'[0]) {
            it.'name'[0].value() == "foo"
            it.'firstJob'[0].value() == "unit-test"
        }

    }
}
