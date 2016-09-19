package pipeline.jobs

import com.camiloribeiro.cdeasy.job.JobHelper
import javaposse.jobdsl.dsl.DslFactory
import javaposse.jobdsl.dsl.Job

Job load_test = JobHelper.createJob(this as DslFactory, "load_test")
JobHelper.addStep(load_test, "sleep \$((RANDOM%10+5))")
JobHelper.addDeliveryPipelineConfiguration(load_test, 'Performance Tests', 'Load Test')

Job stress_test = JobHelper.createJob(this as DslFactory, "stress_test")
JobHelper.addStep(stress_test, "sleep \$((RANDOM%10+5))")
JobHelper.addDeliveryPipelineConfiguration(stress_test, 'Performance Tests', 'Stress Test')
