import hudson.model.*;
import jenkins.model.Jenkins;
import hudson.security.*

// ********************************************************************* //
// Warning: LDAP auth needs correct Manager DN, passwort and all certs.
// # keytool -import -trustcacerts -keystore cacerts.jenkins -storepass \
//   changeit -noprompt -alias ods-cert-ldaps -file /etc/pki/tls/ods.pem 
// # keytool -importcert -alias ods-ldap.itoper.local-2 -keystore \
//   /usr/lib/jvm/java-8-openjdk-amd64/jre/lib/security/cacerts \
//   -storepass changeit -file ods-ldap.itoper.local-2.cer
// Map certs with Dockerfile /etc/ssl/certs/java/cacerts
// ********************************************************************* //

println "Checking if LDAP_JENKINS set: " + System.getenv('LDAP_JENKINS')
//if (System.getenv('PRODUCTION_JENKINS') != 'true') {
if (System.getenv('LDAP_JENKINS') == 'true') {
  println "checking LDAP_JENKINS: " + System.getenv('LDAP_JENKINS') + ", activating LDAP auth"
  enableLDAP()
} else {
  println "checking LDAP_JENKINS: " + System.getenv('LDAP_JENKINS') + ", no need for LDAP auth"
}

def enableLDAP() {
// best guess //
    def instance = Jenkins.getInstance()
    
    if (System.getenv('LDAP_PWD')) {
      /* check with /etc/sssd/sssd.conf */
      String server = 'ldaps://ods-ldap.itoper.local:636'
      String rootDN = ''
      String userSearchBase = 'ou=Person,dc=its,dc=scom'
      String userSearch = 'uid={0}'
      String groupSearchBase = 'ou=Group,dc=sbp,dc=scom'
      String groupSearchFilter = '(& (cn={0}) (objectclass=group) )'
      String managerDN = 'cn=sbpAgent,ou=customerAgent,dc=scom'
      // would be nice to have hash or read from /etc/sssd/sssd.conf
      // until then done with ENV LDAP_PWD
      String managerPasswordSecret =  System.getenv('LDAP_PWD')
      boolean inhibitInferRootDN = true
      SecurityRealm ldap_realm = new LDAPSecurityRealm(server, rootDN, userSearchBase, userSearch, groupSearchBase, groupSearchFilter, groupMembershipStrategy = null, managerDN, managerPasswordSecret, inhibitInferRootDN, disableMailAddressResolver = false, cache = null)

      def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
      instance.setSecurityRealm(ldap_realm)
      instance.setAuthorizationStrategy(strategy)
      instance.save()
    } else {
      println('...missing LDAP_PWD used for binding...not enabling LDAP')
   }
}
