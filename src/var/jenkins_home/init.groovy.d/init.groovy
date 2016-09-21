import jenkins.model.*

def instance = Jenkins.getInstance()

Jenkins.instance.setRawBuildsDir(System.getenv('JENKINS_BUILDSDIR'))
