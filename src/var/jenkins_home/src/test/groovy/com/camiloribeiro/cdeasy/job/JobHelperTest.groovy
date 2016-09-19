package com.camiloribeiro.cdeasy.view

import com.camiloribeiro.cdeasy.job.JobHelper
import javaposse.jobdsl.dsl.Job
import spock.lang.*

import static com.camiloribeiro.cdeasy.job.JobHelper.createJob
import static com.camiloribeiro.cdeasy.support.SupportTestHelper.getJobParent

@Unroll
class JobHelperTest extends Specification {

    private Job getDefaultJob() {
        createJob(getJobParent(), "foo")
    }

    def "Should create a job"() {
        when:
        def Job newJob = getDefaultJob()

        then:
        newJob.name == "foo"
    }

    def "Should add shell commands to a existing job"() {
        given:
        def Job newJob = getDefaultJob()

        when:
        newJob = JobHelper.addStep(newJob, "echo 'shell'")

        then:
        newJob.node.builders.toString().contains("echo 'shell'")

        when:
        newJob = JobHelper.addStep(newJob, "echo 'new'")

        then:
        newJob.node.builders.toString().contains("echo 'shell'")
        newJob.node.builders.toString().contains("echo 'new'")
    }

    def "Should add a git repository to a job"() {
        given:
        def Job newJob = getDefaultJob()

        when:
        newJob = JobHelper.addGitRepo(newJob, "git@foo.bar", "master")

        then:
        with(newJob.node.scm) {
            it.branches.'hudson.plugins.git.BranchSpec'.name.text() == "master"
            it.userRemoteConfigs.'hudson.plugins.git.UserRemoteConfig'.url.text() == "git@foo.bar"
        }
    }

    def "Should add join trigger"() {
        given:
        def Job newJob = getDefaultJob()

        when:
        newJob = JobHelper.addJoinTrigger(newJob, ["jobA", "jobB", "jobC"])

        then:
        with(newJob.node.'publishers'[0].'join.JoinTrigger'[0].'joinPublishers'[0].'hudson.plugins.parameterizedtrigger.BuildTrigger'[0].'configs'[0].'hudson.plugins.parameterizedtrigger.BuildTriggerConfig'[0]) {
            it.'projects'[0].value() == "jobA, jobB, jobC"
        }
    }

    def "Should add parametrized build"() {
        given:
        def Job newJob = getDefaultJob()

        when:
        newJob = JobHelper.addDownstreamParameterized(newJob, ["jobA", "jobB", "jobC"], "SUCCESS")

        then:
        with(newJob.node.'publishers'[0].'hudson.plugins.parameterizedtrigger.BuildTrigger'[0].'configs'[0].'hudson.plugins.parameterizedtrigger.BuildTriggerConfig'[0]) {
            it.'projects'[0].value() == "jobA, jobB, jobC"
            it.'condition'[0].value() == "SUCCESS"
        }
    }

    def "Should set delivery pipeline configuration"() {
        given:
        def Job newJob = getDefaultJob()

        when:
        newJob = JobHelper.addDeliveryPipelineConfiguration(newJob, "build stage", "step name")

        then:
        with(newJob.node.'properties'[0].'se.diabol.jenkins.pipeline.PipelineProperty'[0]) {
            it.taskName[0].value() == "step name"
            it.stageName[0].value() == "build stage"
        }
    }

    def "Should set delivery pipeline trigger"() {
        given:
        def Job newJob = getDefaultJob()

        when:
        newJob = JobHelper.addDeliveryPipelineTrigger(newJob, ["foo", "bar"])

        then:
        newJob.node.'publishers'[0]
                .'au.com.centrumsystems.hudson.plugin.buildpipeline.trigger.BuildPipelineTrigger'[0]
                .downstreamProjectNames[0].value() == "foo, bar"
    }

    def "Should set publisher html plugin"() {
        given:
        def Job newJob = getDefaultJob()

        when:
        newJob = JobHelper.addHtmlReport(newJob, "path/to/report", "Report Show Name", "report_file.name")

        then:
        with(newJob.node.'publishers'[0].'htmlpublisher.HtmlPublisher'[0].'reportTargets'[0].'htmlpublisher.HtmlPublisherTarget'[0]) {
            it.'reportName'[0].value() == "Report Show Name"
            it.'reportDir'[0].value() == "path/to/report"
            it.'reportFiles'[0].value() == "report_file.name"
        }
    }
}
