import jenkins.model.*;
import hudson.model.*;
import com.nirima.jenkins.plugins.docker.DockerCloud
import com.nirima.jenkins.plugins.docker.DockerTemplate
import com.nirima.jenkins.plugins.docker.DockerTemplateBase
import com.nirima.jenkins.plugins.docker.launcher.DockerComputerSSHLauncher
import hudson.plugins.sshslaves.SSHConnector
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.common.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*

def instance = Jenkins.getInstance()

try {
  def domain = Domain.global()
  def store = instance.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()

  // https://github.com/jenkinsci/credentials-plugin/blob/3a9ce5254749da296a76f55e3dfdae3d496b695a/src/main/java/com/cloudbees/plugins/credentials/impl/UsernamePasswordCredentialsImpl.java#L68
  slaveUsernameAndPassword = new UsernamePasswordCredentialsImpl(CredentialsScope.GLOBAL, "docker-slave", "Jenkins Slave with Password Configuration", "jenkins", "jenkins")
  println 'adding credentials for ssh slaves ...'
  store.addCredentials(domain, slaveUsernameAndPassword)

  // https://github.com/jenkinsci/docker-plugin/blob/docker-plugin-parent-0.16.0/docker-plugin/src/main/java/com/nirima/jenkins/plugins/docker/DockerTemplateBase.java#L103
  DockerTemplateBase templateBase = new DockerTemplateBase("", "", "", "", """/var/run/docker.sock:/var/run/docker.sock""", "", "", "", "", 2048, 0, 1024, "", false, false, false, "");
  
  // https://github.com/jenkinsci/ssh-slaves-plugin/blob/ssh-slaves-1.11/src/main/java/hudson/plugins/sshslaves/SSHConnector.java#L178
  SSHConnector connector = new SSHConnector(22, "docker-slave", null, null, null, null, null);
  
  // https://github.com/jenkinsci/docker-plugin/blob/docker-plugin-parent-0.16.0/docker-plugin/src/main/java/com/nirima/jenkins/plugins/docker/launcher/DockerComputerSSHLauncher.java#L43
  DockerComputerSSHLauncher launcher = new DockerComputerSSHLauncher(connector);
	
  // https://github.com/jenkinsci/docker-plugin/blob/docker-plugin-parent-0.16.0/docker-plugin/src/main/java/com/nirima/jenkins/plugins/docker/DockerTemplate.java#L71
  DockerTemplate template = new DockerTemplate(templateBase,"docker","","","")
  template.setLauncher(launcher);
	
  ArrayList<DockerTemplate> templates = new ArrayList<DockerTemplate>();
  templates.add(template);

  // https://github.com/jenkinsci/docker-plugin/blob/docker-plugin-parent-0.16.0/docker-plugin/src/main/java/com/nirima/jenkins/plugins/docker/DockerCloud.java#L122
  ArrayList<DockerCloud> cloud = new ArrayList<DockerCloud>();
  cloud.add(new DockerCloud("localhost", templates, "unix:///var/run/docker.sock", "", 5, 5, "", ""));
  instance.clouds.replaceBy(cloud)
}
catch(Exception e) {
  println("Exception:" + e.message)
}
