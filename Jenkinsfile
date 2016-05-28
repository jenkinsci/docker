node('docker') {
  stage 'Checkout'
  checkout scm

  stage 'Build'
  docker.build('jenkins')

  stage 'Test'
  sh "git checkout https://github.com/sstephenson/bats.git"
  sh "bats/bin/bats tests/tests.bats"
}
