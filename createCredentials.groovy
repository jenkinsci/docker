import com.cloudbees.jenkins.plugins.sshcredentials.impl.*
import com.cloudbees.jenkins.plugins.sshcredentials.impl.*;
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.*;
import com.cloudbees.plugins.credentials.common.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.domains.*;
import com.cloudbees.plugins.credentials.impl.*
import com.cloudbees.plugins.credentials.impl.*;
import hudson.plugins.sshslaves.*;
import jenkins.model.*;
import org.jenkinsci.plugins.plaincredentials.impl.*;

/////////////////////////
// create credentials
/////////////////////////
def userPwdCreds = [
	[id: 'symphonyjenkinsauto', user: 'symphonyjenkinsauto', env: 'SYMPHONYJENKINSAUTO_GH_PWD']
]

def secretTextCreds = [
	[id: 'symphonyjenkinsauto-token', user: 'symphonyjenkinsauto-token', env: 'SYMPHONYJENKINSAUTO_GH_TOKEN'],
	[id: 'sonar-token', user: 'sonar-token', env: 'SONAR_TOKEN'],
	[id: 'sonar-gh-token', user: 'sonar-gh-token', env: 'SONAR_GH_TOKEN']
]

def global_domain = Domain.global()
def credentials_store = Jenkins.instance.getExtensionList(
							'com.cloudbees.plugins.credentials.SystemCredentialsProvider'
						)[0].getStore()

userPwdCreds.each {
	def credentials = new UsernamePasswordCredentialsImpl(
	  CredentialsScope.GLOBAL,
	  it.id,
	  '',
	  it.user,
	  getSecret(it.env)
	)
	addOrUpdateCreds(it.id, credentials, credentials_store, global_domain)
}

pkCreds.each {
	def key_source
	def private_key = getSecret(it.env)
	if (private_key) {
		if (private_key.startsWith('-----BEGIN')) {
			key_source = new BasicSSHUserPrivateKey.DirectEntryPrivateKeySource(private_key)
		} else {
			key_source = new BasicSSHUserPrivateKey.FileOnMasterPrivateKeySource(private_key)
		}
		def credentials = new BasicSSHUserPrivateKey(
			CredentialsScope.GLOBAL,
			null,
			it.user,
			key_source,
			null,
			''
		)
		addOrUpdateCreds(it.id, credentials, credentials_store, global_domain)
	}
}

secretTextCreds.each {
	hudson.util.Secret secret = hudson.util.Secret.fromString(getSecret(it.env))
	def credentials = new StringCredentialsImpl(
	  CredentialsScope.GLOBAL,
	  it.id,
	  '',
	  secret
	)
	addOrUpdateCreds(it.id, credentials, credentials_store, global_domain)
}

def addOrUpdateCreds(id, credentials, store, domain) {
	if (System.getenv('NO_BOOTSTRAP')) {
		return
	}
	def existing_credentials = credentials_for_id(id)
	if (existing_credentials) {
		store.updateCredentials(domain, existing_credentials, credentials)
	} else {
		store.addCredentials(domain, credentials)
	}
}

def getSecret(id) {
	return System.getenv(id)
}

def credentials_for_id(id) {
	def username_matcher = CredentialsMatchers.withId(id)
	def available_credentials =
		CredentialsProvider.lookupCredentials(
			StandardUsernameCredentials.class,
			Jenkins.getInstance(),
			hudson.security.ACL.SYSTEM,
			new SchemeRequirement("ssh")
		)
    
	return CredentialsMatchers.firstOrNull(
		available_credentials,
		username_matcher
	)
}