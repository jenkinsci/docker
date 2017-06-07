import hudson.model.*;
import jenkins.model.*;

Thread.start {
      sleep 11000

      def instance = Jenkins.getInstance()
      def env = System.getenv()

      // avoid overloading CPU on jenkins master, use slaves for executors
      instance.setNumExecutors(0)
      println "--> set jenkins master to 0 executors"

      instance.save()
      println "--> saved " + env['JENKINS_HOME'] + "/config.xml"
}
