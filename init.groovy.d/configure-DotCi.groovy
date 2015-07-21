import com.groupon.jenkins.SetupConfig;

Thread.start {
  sleep 10000
  println "--> configure DotCi"

  SetupConfig config = SetupConfig.get()

  // your mongo (based on docker-compose.yml)
  config.setDbHost("mongodb")
  config.setDbPort(27017)
  config.setDbName("dotci")

  // your github
  config.setGithubWebUrl("https://github.com")
  config.setGithubApiUrl("https://github.com/api/v3")

  // create your DotCi github authorization via github Account settings => Applications => Register new application => callback url:http://xx.xx.xx.xx:port/dotci/finishLogin
  // For example: https://github.com/settings/[applications|connections]/xxx
  // config.setGithubClientID("...")
  // config.setGithubClientSecret("...")
  // config.setGithubCallbackUrl("http://xx.xx.xx.xx:port/githook/")
  config.setPrivateRepoSupport(false)
  // config.setFromEmailAddress("...")

  // set defaults configuration for new DotCi project
  config.setLabel("docker")
  config.setDefaultBuildType("com.groupon.jenkins.buildtype.dockercompose.DockerComposeBuild")

  println "--> save /var/jenkins_home/com.groupon.jenkins.SetupConfig.xml"
  config.save()
}
