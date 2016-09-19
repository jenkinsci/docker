import jenkins.model.*;
import hudson.model.FreeStyleProject;
import hudson.tasks.Shell;
import javaposse.jobdsl.plugin.*;

def scm = System.getenv('SEEDJOB_GIT')

project = Jenkins.instance.createProject(FreeStyleProject, "bootstrap")
project.getBuildersList().clear()

project.getBuildersList().add(new ExecuteDslScripts(
  new ExecuteDslScripts.ScriptLocation("false","dsl/**/*.groovy",null),
  false,
  RemovedJobAction.DELETE,
  RemovedViewAction.DELETE,
  LookupStrategy.JENKINS_ROOT,
  "src/main/groovy")
);

project.save()
