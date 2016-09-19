package pipeline.jobs

import com.camiloribeiro.cdeasy.job.JobHelper
import javaposse.jobdsl.dsl.DslFactory
import javaposse.jobdsl.dsl.Job

Job slt_1 = JobHelper.createJob(this as DslFactory, "service_level_test_1")
JobHelper.addStep(slt_1, "sleep \$((RANDOM%10+5))")
JobHelper.addDeliveryPipelineConfiguration(slt_1, 'Service Level Tests', 'service level test 1')

Job slt_2 = JobHelper.createJob(this as DslFactory, "service_level_test_2")
JobHelper.addStep(slt_2, "sleep \$((RANDOM%10+5))")
JobHelper.addDeliveryPipelineConfiguration(slt_2, 'Service Level Tests', 'service level test 2')
