import hudson.model.*;
import jenkins.model.*;


Thread.start {
      sleep 10000
      println "--> setting agent port for jnlp"
      Jenkins.instance.setSlaveAgentPort(50000)
}
