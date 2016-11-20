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
import hudson.security.*;
import hudson.security.csrf.*;

if (!System.getenv('NO_BOOTSTRAP')) {
	def instance = Jenkins.getInstance()

	def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
	strategy.setAllowAnonymousRead(true)
	def realm = new HudsonPrivateSecurityRealm(false, false, null)
	instance.setAuthorizationStrategy(strategy)
	instance.setSecurityRealm(realm)
	instance.setCrumbIssuer(null)

	hudson.model.User admin = hudson.model.User.getById('admin', true)
	admin.setFullName('admin')
	def email_param = new hudson.tasks.Mailer.UserProperty('matthew.arturi@symphony.com')
	admin.addProperty(email_param)
	def pw_param = hudson.security.HudsonPrivateSecurityRealm.Details.fromPlainPassword('w@rpdr1ve')
	admin.addProperty(pw_param)
	admin.save()
}
