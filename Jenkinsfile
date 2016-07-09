node {
	timestamps {
	  stage 'Checkout'
	  checkout scm

	  stage 'Build'
	  def dockerImageName = "docker-registry.elium.io:5001/elium/jenkins:${JENKINS_VERSION}"
    sh "docker --version"
    sh "docker build --build-arg JENKINS_VERSION=\"${JENKINS_VERSION}\" --build-arg JENKINS_SHA=\"${JENKINS_SHA}\" -t ${dockerImageName} ."

	  stage 'Test'
    sh "rm -Rf bats && git clone git@github.com:sstephenson/bats.git"
    sh "bats/bin/bats tests/tests.bats"
    
    stage 'Publish'
    sh "docker push ${dockerImageName}"
	}
}