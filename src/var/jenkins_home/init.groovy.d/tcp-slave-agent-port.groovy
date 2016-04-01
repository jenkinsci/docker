import hudson.model.*;
import jenkins.model.*;

Thread.start {
      sleep 10000
      println "--> setting agent port for jnlp"
      int port = System.getenv('JENKINS_SLAVE_AGENT_PORT') ? System.getenv('JENKINS_SLAVE_AGENT_PORT').toInteger() : 50000
      Jenkins.instance.setSlaveAgentPort(port)
      println "--> setting agent port for jnlp... done"
}
