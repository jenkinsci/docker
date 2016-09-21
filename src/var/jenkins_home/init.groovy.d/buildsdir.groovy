import hudson.model.*;
import jenkins.model.*;

Thread.start {
      sleep 10000
      println "--> setting builds root directory"
      string buildsDir = System.getenv('JENKINS_BUILDSDIR') ? System.getenv('JENKINS_BUILDSDIR').toString() : "${JENKINS_HOME}/builds/${ITEM_FULL_NAME}"
      Jenkins.instance.setRawBuildsDir(buildsDir)
      println "--> setting builds root directory... done"
}
