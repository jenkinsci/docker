Import-Module -Force -DisableNameChecking C:/ProgramData/Jenkins/jenkins-support.psm1

$JENKINS_WAR = Get-EnvOrDefault 'JENKINS_WAR' 'C:/ProgramData/Jenkins/jenkins.war'
$JENKINS_HOME = Get-EnvOrDefault 'JENKINS_HOME' 'C:/ProgramData/Jenkins/JenkinsHome'
$COPY_REFERENCE_FILE_LOG = Get-EnvOrDefault 'COPY_REFERENCE_FILE_LOG' "$($JENKINS_HOME)/copy_reference_file.log"

try {
  [System.IO.File]::OpenWrite($COPY_REFERENCE_FILE_LOG).Close()
} catch {
  Write-Error "Can not write to $COPY_REFERENCE_FILE_LOG. Wrong volume permissions?`n`n$_"
  exit 1
}

Add-Content -Path $COPY_REFERENCE_FILE_LOG -Value "--- Copying files at $(Get-Date)"
Get-ChildItem -Recurse -File -Path 'C:/ProgramData/Jenkins/Reference' | ForEach-Object { Copy-ReferenceFile $_.FullName }

# if `docker run` first argument starts with `--` the user is passing jenkins launcher arguments
if(($args.Count -eq 0) -or ($args[0] -match "^--.*")) {

  # read JAVA_OPTS and JENKINS_OPTS into arrays to avoid need for eval (and associated vulnerabilities)
  $java_opts_array = $env:JAVA_OPTS -split ' '

  $agent_port_property='jenkins.model.Jenkins.slaveAgentPort'
  if(![System.String]::IsNullOrWhiteSpace($env:JENKINS_AGENT_PORT) -and ($env:JAVA_OPTS -notmatch "$agent_port_property")) {
    $java_opts_array += "-D`"$agent_port_property=$env:JENKINS_AGENT_PORT`""
  }

  if($null -ne $env:DEBUG) {
    $java_opts_array += '-Xdebug'
    $java_opts_array += '-Xrunjdwp:server=y,transport=dt_socket,address=5005,suspend=y'
  }

  $jenkins_opts_array = $env:JENKINS_OPTS -split ' '
  $proc = Start-Process -NoNewWindow -Wait -PassThru -FilePath 'java.exe' -ArgumentList "-D`"user.home='$JENKINS_HOME'`" $java_opts_array -jar $JENKINS_WAR $jenkins_opts_array $args"
  if($null -ne $proc) {
    $proc.WaitForExit()
  }
} else {
  # As argument is not jenkins, assume user wants to run their own process, for example a `powershell` shell to explore this image
  Invoke-Expression "$args"
  exit $lastExitCode
}