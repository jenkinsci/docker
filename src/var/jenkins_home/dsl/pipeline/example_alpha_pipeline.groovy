pipelineJob('example_pipeline_jenkins2') {
  definition {
    cpsScm {
      scm {
        git{
          remote{
            url("https://github.com/camiloribeiro/cdeasy.git")
          }
          branch("master")
        }
      }
      scriptPath("Jenkinsfile")
    }
  }
}
