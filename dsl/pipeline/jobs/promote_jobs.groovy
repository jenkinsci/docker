package pipeline.jobs

import com.camiloribeiro.cdeasy.job.JobHelper
import javaposse.jobdsl.dsl.DslFactory
import javaposse.jobdsl.dsl.Job

Job promote_rpm_to_dev = JobHelper.createJob(this as DslFactory, "promote_rpm_to_dev")
JobHelper.addStep(promote_rpm_to_dev, "sleep \$((RANDOM%10+5))")
JobHelper.addDeliveryPipelineConfiguration(promote_rpm_to_dev, 'Build', 'Promote RPM to dev')
JobHelper.addDownstreamParameterized(promote_rpm_to_dev, ["service_level_test_1","service_level_test_2","pen_test","stress_test","load_test"], "SUCCESS")
JobHelper.addJoinTrigger(promote_rpm_to_dev, ["promote_rpm_to_stage"])

Job promote_rpm_to_stage = JobHelper.createJob(this as DslFactory, "promote_rpm_to_stage")
JobHelper.addStep(promote_rpm_to_stage, "sleep \$((RANDOM%10+5))")
JobHelper.addDeliveryPipelineConfiguration(promote_rpm_to_stage, 'Stage', 'Promote RPM to stage')
JobHelper.addDownstreamParameterized(promote_rpm_to_stage, ["deploy_to_stage"], "SUCCESS")

Job promote_rpm_to_production = JobHelper.createJob(this as DslFactory, "promote_rpm_to_production")
JobHelper.addStep(promote_rpm_to_production, "sleep \$((RANDOM%10+5))")
JobHelper.addDeliveryPipelineConfiguration(promote_rpm_to_production, 'Promote RPM', 'Promote RPM to production')
JobHelper.addDeliveryPipelineTrigger(promote_rpm_to_production, ["deploy_to_production", "deploy_to_beta"])
