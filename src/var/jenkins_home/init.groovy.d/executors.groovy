import hudson.model.*;
import jenkins.model.*;

Thread.start {
      sleep 10000
      println "--> setting executors"
      int executors = System.getenv('JENKINS_EXECUTORS') ? System.getenv('JENKINS_EXECUTORS').toInteger() : 2
      Jenkins.instance.setNumExecutors(executors)
      println "--> setting executors... done"
}
