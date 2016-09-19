package pipeline.jobs

import com.camiloribeiro.cdeasy.job.JobHelper
import javaposse.jobdsl.dsl.DslFactory
import javaposse.jobdsl.dsl.Job

Job code_analysis = JobHelper.createJob(this as DslFactory, "code_analysis")
JobHelper.addStep(code_analysis, "sleep \$((RANDOM%10+5))")
JobHelper.addDownstreamParameterized(code_analysis, ["build_rpm"], "SUCCESS")
JobHelper.addDeliveryPipelineConfiguration(code_analysis, 'Build', 'Code Analysis')

Job build_rpm = JobHelper.createJob(this as DslFactory, "build_rpm")
JobHelper.addStep(build_rpm, "sleep \$((RANDOM%10+5))")
JobHelper.addDownstreamParameterized(build_rpm, ["promote_rpm_to_dev"], "SUCCESS")
JobHelper.addDeliveryPipelineConfiguration(build_rpm, 'Build', 'Build RPM')
