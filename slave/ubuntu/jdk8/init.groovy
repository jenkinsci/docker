import hudson.model.*;
import hudson.slaves.*;
import jenkins.model.*;

Thread.start {
      sleep 10000
      def env = System.getenv()
      def instance = Jenkins.getInstance()

      // avoid overloading jenkins master
      println "--> setting jenkins master to 0 executors"
      instance.setNumExecutors(0)
      println "--> setting jenkins master to 0 executors... done"

      // modify below to your needs
      println "--> adding JNLP slave(s)"
      List<String> clients = new ArrayList<String>()
      clients.add("slave1")
      // clients.add("...")

      // http://javadoc.jenkins-ci.org/hudson/slaves/DumbSlave.html
      for (String client : clients) {
        println "--> creating 2 executor stub for /computer/" + client + " available via /label/jdk8 based on java:8-jdk"
        instance.addNode(
	  new DumbSlave(
		client,
                "JNLP slave",
                "/root",
                "2",
                Node.Mode.NORMAL,
                "jdk8",
                new JNLPLauncher(),
                new RetentionStrategy.Always(),
                new LinkedList()
          )
        )
      }
      println "--> adding JNLP slave(s)... done"

      instance.save()
      println "--> saving " + env['JENKINS_HOME'] + "/config.xml... done"
}
