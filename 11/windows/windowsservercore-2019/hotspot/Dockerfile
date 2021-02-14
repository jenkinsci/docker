# escape=`
FROM jenkins4eval/openjdk:15-hotspot-windowsservercore-ltsc2019

ARG user=jenkins
ARG http_port=8080
ARG agent_port=50000
ARG JENKINS_HOME=C:/ProgramData/Jenkins/JenkinsHome

ENV JENKINS_HOME $JENKINS_HOME
ENV JENKINS_AGENT_PORT ${agent_port}

# Jenkins home directory is a volume, so configuration and build history
# can be persisted and survive image upgrades
VOLUME $JENKINS_HOME

# Jenkins is run with user `jenkins`
# If you bind mount a volume from the host or a data container,
# ensure you use the same uid
RUN New-LocalUser -Name $env:user -AccountNeverExpires -Description 'Jenkins User' -NoPassword -UserMayNotChangePassword | Out-Null ; `
    Set-Localuser -Name $env:user -PasswordNeverExpires $true | Out-Null ; `
    Add-LocalGroupMember -Group "Administrators" -Member "${env:user}" ; `
    New-Item -Type Directory -Force -Path "C:/ProgramData/Jenkins" | Out-Null ; `
    icacls.exe "C:/ProgramData/Jenkins" /setowner ${env:user} | Out-Null ; `
    icacls.exe "C:/ProgramData/Jenkins" /inheritance:r | Out-Null ; `
    icacls.exe "C:/ProgramData/Jenkins" /grant:r $('{0}:(CI)(OI)(F)' -f $env:user) /grant 'Administrators:(CI)(OI)(F)' | Out-Null ; `
    icacls.exe "$env:JENKINS_HOME" /setowner ${env:user} | Out-Null ; `
    icacls.exe "$env:JENKINS_HOME" /grant:r $('{0}:(CI)(OI)(F)' -f $env:user) /grant 'Administrators:(CI)(OI)(F)' | Out-Null

USER ${user}

# `C:/ProgramData/Jenkins/Reference/` contains all reference configuration we want
# to set on a fresh new installation. Use it to bundle additional plugins
# or config file with your custom jenkins Docker image.
RUN New-Item -ItemType Directory -Force -Path C:/ProgramData/Jenkins/Reference/init.groovy.d | Out-Null

# jenkins version being bundled in this docker image
ARG JENKINS_VERSION
ENV JENKINS_VERSION ${JENKINS_VERSION:-2.235.4}

# jenkins.war checksum, download will be validated using it
ARG JENKINS_SHA=e5688a8f07cc3d79ba3afa3cab367d083dd90daab77cebd461ba8e83a1e3c177

# Can be used to customize where jenkins.war get downloaded from
ARG JENKINS_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war

# could use ADD but this one does not check Last-Modified header neither does it allow to control checksum
# see https://github.com/docker/docker/issues/8331
RUN curl.exe -fsSL "$env:JENKINS_URL" -o C:/ProgramData/Jenkins/jenkins.war ; `
    if ((Get-FileHash C:/ProgramData/Jenkins/jenkins.war -Algorithm SHA256).Hash -ne $env:JENKINS_SHA) {exit 1}

ENV JENKINS_UC https://updates.jenkins.io
ENV JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental
ENV JENKINS_INCREMENTALS_REPO_MIRROR=https://repo.jenkins-ci.org/incrementals

ARG PLUGIN_CLI_URL=https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.2.0/jenkins-plugin-manager-2.2.0.jar
RUN curl.exe -fsSL "$env:PLUGIN_CLI_URL" -o C:/ProgramData/Jenkins/jenkins-plugin-manager.jar

# for main web interface:
EXPOSE ${http_port}

# will be used by attached agents:
EXPOSE ${agent_port}

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

COPY jenkins-support.psm1 C:/ProgramData/Jenkins
COPY jenkins.ps1 C:/ProgramData/Jenkins
# See https://github.com/jenkinsci/plugin-installation-manager-tool#cli-options for information on parameters for jenkins-plugin-cli.ps1 for installing plugins into the docker image
COPY jenkins-plugin-cli.ps1 C:/ProgramData/Jenkins

ENTRYPOINT ["powershell.exe", "-f", "C:/ProgramData/Jenkins/jenkins.ps1"]
