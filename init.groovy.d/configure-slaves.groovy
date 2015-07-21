import hudson.slaves.*;
import hudson.model.*;
import jenkins.model.*;

List<String> clients = new ArrayList<String>();
clients.add("myjnlpclient1");
// clients.add("...");

def instance = Jenkins.getInstance()

Thread.start {
  sleep 10000

  println "--> master should have 0 executors"
  instance.setNumExecutors(0)

  println "--> configure JNLP port"
  instance.setSlaveAgentPort(50000)

  for (String client : clients) {
    println "--> add JNLP slave " + client
      instance.addNode(
	new DumbSlave(
		client,
                "JNLP slave stub for DotCi with docker",
                "",
                "1",
                Node.Mode.NORMAL,
                "docker",
                new JNLPLauncher(),
                new RetentionStrategy.Always(),
                new LinkedList()
        )
      )
  }

  println "--> save /var/jenkins_home/config.xml"
  instance.save()
}
