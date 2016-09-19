package pipeline.jobs

import com.camiloribeiro.cdeasy.job.JobHelper
import javaposse.jobdsl.dsl.DslFactory
import javaposse.jobdsl.dsl.Job

Job e2e_test = JobHelper.createJob(this as DslFactory, "e2e_test")
JobHelper.addStep(e2e_test, "sleep \$((RANDOM%10+5))")
JobHelper.addDeliveryPipelineConfiguration(e2e_test, 'Stage Testing', 'End to End Test')
JobHelper.addDownstreamParameterized(e2e_test, ["promote_rpm_to_production"], 'SUCCESS')

Job pen_test = JobHelper.createJob(this as DslFactory, "service_level_test_2")
JobHelper.addStep(pen_test, "sleep \$((RANDOM%10+5))")
JobHelper.addDeliveryPipelineConfiguration(pen_test, 'Security Tests', 'Penetration Tests')

Job unit_test = JobHelper.createJob(this as DslFactory, "unit_test")
JobHelper.addStep(unit_test, "sleep \$((RANDOM%10+5))")
JobHelper.addDeliveryPipelineConfiguration(unit_test, 'Build', 'Unit Tests')
JobHelper.addDownstreamParameterized(unit_test,["code_analysis"], "SUCCESS")
