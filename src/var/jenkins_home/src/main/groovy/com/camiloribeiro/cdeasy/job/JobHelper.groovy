package com.camiloribeiro.cdeasy.job

import javaposse.jobdsl.dsl.DslFactory
import javaposse.jobdsl.dsl.Job

class JobHelper {

    public static Job createJob(DslFactory dslFactory, String name) {
        def Job job = dslFactory.job(name)
        job
    }

    public static Job addStep(Job job, String command) {
        job.steps() {
            shell(command)
        }
        job
    }

    public static Job addGitRepo(Job job, String repo, String repoBranch) {
        job.scm {
            git {
                remote {
                    name('origin')
                    url(repo)
                }
                branch(repoBranch)
            }
        }
        job
    }

    static Job addJoinTrigger(Job job, ArrayList<String> jobs) {
        job.publishers {
            joinTrigger {
                publishers {
                    downstreamParameterized {
                        trigger(jobs.join(", ")) {
                            triggerWithNoParameters(true) 
                        }
                    }
                }
            }
        }
        job
    }

    static Job addDownstreamParameterized(Job job, ArrayList<String> jobs, String buildConditions) {
        job.publishers {
            downstreamParameterized {
                trigger(jobs.join(", ")) {
                    condition(buildConditions)
                    triggerWithNoParameters(true)
                    parameters {
                        currentBuild()
                    }
                }
            }
        }
        job
    }

    static Job addDeliveryPipelineConfiguration(Job job, String buildStage, String stepName) {
        job.deliveryPipelineConfiguration(buildStage, stepName)
        job
    }

    static Job addDeliveryPipelineTrigger(Job job, ArrayList<String> jobs) {
        job.publishers {
            buildPipelineTrigger(jobs.join(", "))
        }
        job
    }

    static Job addHtmlReport(Job job, String pathToReport, String showName, String fileName) {
        job.publishers {
            publishHtml {
                report(pathToReport) {
                    reportName(showName)
                    reportFiles(fileName)
                    keepAll()
                    allowMissing()
                    alwaysLinkToLastBuild()
                }
            }
        }
        job
    }
}

