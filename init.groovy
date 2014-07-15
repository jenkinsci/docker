import hudson.model.*;
import jenkins.model.*;

println "--> setting agent port for jnlp"
Jenkins.instance.setSlaveAgentPort(50000)
