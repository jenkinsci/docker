import jenkins.model.*
import hudson.model.*
import hudson.security.*
import org.jenkinsci.plugins.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.common.*
import com.cloudbees.jenkins.plugins.sshcredentials.impl.*

try
{
  global_domain = Domain.global()
  credentials_store = Jenkins.instance.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()
  mycredentials = new BasicSSHUserPrivateKey(CredentialsScope.GLOBAL, "git", "git", new BasicSSHUserPrivateKey.UsersPrivateKeySource(), null, "Private key for accessing git")
  username_matcher = CredentialsMatchers.withUsername("git")
  available_credentials = CredentialsProvider.lookupCredentials( StandardUsernameCredentials.class, Jenkins.getInstance(), hudson.security.ACL.SYSTEM, new SchemeRequirement("ssh"))
  existing_credentials = CredentialsMatchers.firstOrNull(available_credentials, username_matcher)

  if(existing_credentials != null) {
    credentials_store.updateCredentials(global_domain, existing_credentials, mycredentials)
  } 
  else {
    credentials_store.addCredentials(global_domain, mycredentials)
  }
}
catch(Exception e) {
  println("Exception:" + e.message)
}
