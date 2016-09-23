import jenkins.model.*
import hudson.model.*
import hudson.security.*
import org.jenkinsci.plugins.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.common.*
import com.cloudbees.jenkins.plugins.sshcredentials.impl.*

def github_private_key = System.getenv('JENKINS_GITHUB_PRIVATE_KEY')

if(github_private_key) {

  global_domain = Domain.global()
  credentials_store = Jenkins.instance.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()

  mycredentials = new BasicSSHUserPrivateKey(
    CredentialsScope.GLOBAL,
    null,
    "github",
    new BasicSSHUserPrivateKey.DirectEntryPrivateKeySource(github_private_key),
    null,
    "Private key for accessing github"
  )

  username_matcher = CredentialsMatchers.withUsername("github")
  available_credentials =
    CredentialsProvider.lookupCredentials(
      StandardUsernameCredentials.class,
      Jenkins.getInstance(),
      hudson.security.ACL.SYSTEM,
      new SchemeRequirement("ssh")
    )

  existing_credentials =
    CredentialsMatchers.firstOrNull(
      available_credentials,
      username_matcher
    )

  if(existing_credentials != null) {
    credentials_store.updateCredentials(
      global_domain,
      existing_credentials,
      mycredentials
    )
  } else {
    credentials_store.addCredentials(global_domain, mycredentials)
  }
}
