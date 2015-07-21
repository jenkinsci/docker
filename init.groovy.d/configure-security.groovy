import hudson.model.*;
import jenkins.model.*;
import org.jenkinsci.plugins.GithubSecurityRealm;

def instance = Jenkins.getInstance()

// based on plugins.dotci use of https://github.com/jenkinsci/github-oauth-plugin/blob/github-oauth-0.20/src/main/java/org/jenkinsci/plugins/GithubSecurityRealm.java#L115-L116
// create via github Account settings => Applications => Register new application => callback url:https://xx.xx.xx.xx:port/securityRealm/finishLogin
// For example: https://github.com/settings/[applications|connections]/xxx

println "--> configure securityRealm"
// instance.setSecurityRealm( new GithubSecurityRealm( "https://github.com", "https://github.com/api/v3",
//		"...your_clientId...",
//		"...your_clientSecret..."))

println "--> save /var/jenkins_home/config.xml"
instance.save()
