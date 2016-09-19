import com.camiloribeiro.cdeasy.view.ViewHelper
import javaposse.jobdsl.dsl.DslFactory

ViewHelper.addView(this as DslFactory, "Service Level tests", "All service level test jobs", "service_level_test.+")
