import com.camiloribeiro.cdeasy.view.ViewHelper
import javaposse.jobdsl.dsl.DslFactory

ViewHelper.addView(this as DslFactory,"Deploys", "All Deploy Jobs", "deploy.+")
