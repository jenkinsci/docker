package pipeline.jobs

import com.camiloribeiro.cdeasy.job.JobHelper
import javaposse.jobdsl.dsl.DslFactory
import javaposse.jobdsl.dsl.Job

Job running_erlang = JobHelper.createJob(this as DslFactory, "running_erlang")
JobHelper.addGitRepo(running_erlang, "https://github.com/ferd/recon.git", "master")
JobHelper.addStep(running_erlang, 'docker pull correl/erlang:latest')
JobHelper.addStep(running_erlang, 'docker run -v $WORKSPACE/:/erlang -w /erlang correl/erlang ./rebar compile')

Job running_java = JobHelper.createJob(this as DslFactory, "running_java")
JobHelper.addGitRepo(running_java, "https://github.com/camiloribeiro/cucumber-gradle-parallel.git", "master")
JobHelper.addStep(running_java, 'docker pull niaquinto/gradle:2.5')
JobHelper.addStep(running_java, 'docker run -v $WORKSPACE/:/gradle -w /gradle niaquinto/gradle:2.5 clean build runInParallel')
JobHelper.addHtmlReport(running_java, "build/reports/cucumber", "Cucumber Report", "feature-overview.html")

Job running_ruby = JobHelper.createJob(this as DslFactory, "running_ruby")
JobHelper.addGitRepo(running_ruby, "https://github.com/camiloribeiro/RestShifter.git", "master")
JobHelper.addStep(running_ruby, 'docker pull ruby:latest')
JobHelper.addStep(running_ruby, 'docker run -v $WORKSPACE/:/icecream -w /icecream ruby:latest  sh -c \'bundle install && RACK_ENV=test rake\'')

Job running_node = JobHelper.createJob(this as DslFactory, "running_node")
JobHelper.addGitRepo(running_node, "https://github.com/conancat/node-test-examples.git", "master")
JobHelper.addStep(running_node, 'docker pull node:latest')
JobHelper.addStep(running_node, 'docker run -v $WORKSPACE/:/node -w /node node:latest npm install mocha -g')

Job running_python = JobHelper.createJob(this as DslFactory, "running_python")
JobHelper.addGitRepo(running_python, "https://github.com/cgoldberg/python-unittest-tutorial.git", "master")
JobHelper.addStep(running_python, 'docker pull python:latest')
JobHelper.addStep(running_python, 'docker run -v $WORKSPACE/:/python -w /python python python test_simple.py')

Job running_compose = JobHelper.createJob(this as DslFactory, "running_docker_compose")
JobHelper.addGitRepo(running_compose, "https://github.com/b00giZm/docker-compose-nodejs-examples.git", "master")
JobHelper.addStep(running_compose, 'cd 02-express-redis-nodemon && docker-compose up -d')
JobHelper.addStep(running_compose, 'sleep 5 && curl http://localhost:3030')