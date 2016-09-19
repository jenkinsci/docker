package com.camiloribeiro.cdeasy.view;

import javaposse.jobdsl.dsl.DslFactory

public class PipelineHelper {

    def addPipeline(DslFactory dslFactory, String pipelineName) {
        dslFactory.deliveryPipelineView(pipelineName) {
            pipelines {
                component(pipelineName, 'unit-test')
            }
        }
    }

}
