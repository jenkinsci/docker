# escape=`
# hadolint shell=powershell

ARG JAVA_VERSION=17.0.15_6
ARG WINDOWS_VERSION=ltsc2019
ARG TOOLS_WINDOWS_VERSION=1809

FROM mcr.microsoft.com/windows/servercore:"${WINDOWS_VERSION}" AS jre-build

# $ProgressPreference: https://github.com/PowerShell/PowerShell/issues/2138#issuecomment-251261324
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG JAVA_VERSION=17.0.15_6

# Download and install JDK
RUN New-Item -ItemType Directory -Path C:\temp -Force | Out-Null ; `
    $javaMajorVersion = $env:JAVA_VERSION.substring(0,2) ; `
    $msiUrl = 'https://api.adoptium.net/v3/installer/version/jdk-{0}/windows/x64/jdk/hotspot/normal/eclipse?project=jdk' -f $env:JAVA_VERSION.Replace('_', '%2B') ; `
    Write-Host "Downloading JDK from: $msiUrl" ; `
    try { `
        Invoke-WebRequest $msiUrl -OutFile 'C:\temp\jdk.msi' -UseBasicParsing ; `
        Write-Host "JDK MSI downloaded successfully" ; `
        $proc = Start-Process -FilePath 'msiexec.exe' -ArgumentList '/i', 'C:\temp\jdk.msi', '/L*V', 'C:\temp\OpenJDK.log', '/quiet', 'ADDLOCAL=FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome', "INSTALLDIR=C:\openjdk-${javaMajorVersion}" -Wait -PassThru ; `
        if ($proc.ExitCode -ne 0) { `
            Write-Host "MSI installation failed with exit code: $($proc.ExitCode)" ; `
            Get-Content 'C:\temp\OpenJDK.log' -ErrorAction SilentlyContinue | Write-Host ; `
            throw "JDK installation failed" ; `
        } ; `
        Write-Host "JDK installed successfully" ; `
    } catch { `
        Write-Error "Failed to download or install JDK: $_" ; `
        throw ; `
    } finally { `
        if (Test-Path 'C:\temp') { `
            Remove-Item -Path C:\temp -Recurse -Force | Out-Null ; `
        } ; `
    }

# Verify Java installation (separate RUN to ensure environment variables are loaded)
RUN Write-Host 'Verifying Java installation...' ; `
    $javaPath = "C:\openjdk-$($env:JAVA_VERSION.substring(0,2))\bin" ; `
    if (Test-Path $javaPath) { `
        $env:PATH = "$javaPath;$env:PATH" ; `
        Write-Host 'javac --version:' ; & "$javaPath\javac.exe" --version ; `
        Write-Host 'java --version:' ; & "$javaPath\java.exe" --version ; `
    } else { `
        Write-Error "Java installation path not found: $javaPath" ; `
        throw "Java installation verification failed" ; `
    }

# Create custom JRE with jlink (separate RUN to ensure Java is available)
RUN try { `
        $javaPath = "C:\openjdk-$($env:JAVA_VERSION.substring(0,2))\bin" ; `
        $env:PATH = "$javaPath;$env:PATH" ; `
        $jlinkVersion = (& "$javaPath\jlink.exe" --version 2>&1) | Out-String ; `
        Write-Host "jlink version: $jlinkVersion" ; `
        $compressArg = '--compress=2' ; `
        # More robust version detection
        if ($jlinkVersion -match '21\.') { `
            $compressArg = '--compress=zip-6' ; `
            Write-Host "Using JDK 21 compression format" ; `
        } elseif ($jlinkVersion -match '17\.') { `
            Write-Host "Using JDK 17 compression format" ; `
        } else { `
            Write-Warning "Unknown jlink version, using default compression" ; `
        } ; `
        Write-Host "Creating custom JRE with jlink..." ; `
        & "$javaPath\jlink.exe" `
            --strip-java-debug-attributes `
            $compressArg `
            --add-modules ALL-MODULE-PATH `
            --no-man-pages `
            --no-header-files `
            --output /javaruntime ; `
        if ($LASTEXITCODE -ne 0) { `
            throw "jlink failed with exit code: $LASTEXITCODE" ; `
        } ; `
        Write-Host "Custom JRE created successfully" ; `
    } catch { `
        Write-Error "jlink execution failed: $_" ; `
        throw ; `
    }

FROM mcr.microsoft.com/windows/servercore:"${WINDOWS_VERSION}" AS controller

ARG JAVA_HOME="C:/openjdk-17"
ENV JAVA_HOME=${JAVA_HOME}

COPY --from=jre-build /javaruntime $JAVA_HOME

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Optimize PATH modification with better error handling
RUN try { `
        $CurrentPath = (Get-ItemProperty -Path 'HKLM:\system\currentcontrolset\control\session manager\environment' -Name Path -ErrorAction Stop).Path ; `
        $JavaBinPath = "$env:JAVA_HOME/bin" ; `
        if ($CurrentPath -notlike "*$JavaBinPath*") { `
            $NewPath = "$CurrentPath;$JavaBinPath" ; `
            Set-ItemProperty -Path 'HKLM:\system\currentcontrolset\control\session manager\environment' -Name Path -Value $NewPath -ErrorAction Stop ; `
            Write-Host "Java added to system PATH" ; `
        } else { `
            Write-Host "Java already in PATH" ; `
        } ; `
    } catch { `
        Write-Error "Failed to modify PATH: $_" ; `
        throw ; `
    }

ARG user=jenkins
ARG http_port=8080
ARG agent_port=50000
ARG JENKINS_HOME=C:/ProgramData/Jenkins/JenkinsHome

ARG COMMIT_SHA

ENV JENKINS_HOME=$JENKINS_HOME
ENV JENKINS_AGENT_PORT=${agent_port}

# Jenkins home directory is a volume, so configuration and build history
# can be persisted and survive image upgrades
VOLUME $JENKINS_HOME

# Optimize user creation and permissions setup
# hadolint ignore=DL4006
RUN try { `
        Write-Host "Creating Jenkins user..." ; `
        if (-not (Get-LocalUser -Name $env:user -ErrorAction SilentlyContinue)) { `
            New-LocalUser -Name $env:user -AccountNeverExpires -Description 'Jenkins User' -NoPassword -UserMayNotChangePassword | Out-Null ; `
            Set-LocalUser -Name $env:user -PasswordNeverExpires $true | Out-Null ; `
        } ; `
        Add-LocalGroupMember -Group "Administrators" -Member $env:user -ErrorAction SilentlyContinue ; `
        Write-Host "Setting up Jenkins directories..." ; `
        @('C:/ProgramData/Jenkins', $env:JENKINS_HOME) | ForEach-Object { `
            $dir = $_ ; `
            if (-not (Test-Path $dir)) { `
                New-Item -Type Directory -Force -Path $dir | Out-Null ; `
            } ; `
            icacls.exe $dir /setowner $env:user /T /C | Out-Null ; `
            icacls.exe $dir /inheritance:r /T /C | Out-Null ; `
            icacls.exe $dir /grant:r "$($env:user):(CI)(OI)(F)" /grant "Administrators:(CI)(OI)(F)" /T /C | Out-Null ; `
        } ; `
        Write-Host "Jenkins user and directories configured successfully" ; `
    } catch { `
        Write-Error "Failed to configure Jenkins user: $_" ; `
        throw ; `
    }

USER ${user}

# Create reference directory structure
RUN New-Item -ItemType Directory -Force -Path C:/ProgramData/Jenkins/Reference/init.groovy.d | Out-Null

# jenkins version being bundled in this docker image
ARG JENKINS_VERSION
ENV JENKINS_VERSION=${JENKINS_VERSION:-2.504}

# jenkins.war checksum, download will be validated using it
ARG JENKINS_SHA=efc91d6be8d79dd078e7f930fc4a5f135602d0822a5efe9091808fdd74607d32

# Can be used to customize where jenkins.war get downloaded from
ARG JENKINS_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war

# Optimize Jenkins WAR download with better error handling and retry logic
RUN try { `
        $jenkinsWar = 'C:/ProgramData/Jenkins/jenkins.war' ; `
        Write-Host "Downloading Jenkins WAR from: $env:JENKINS_URL" ; `
        $maxRetries = 3 ; `
        $retryCount = 0 ; `
        do { `
            try { `
                Invoke-WebRequest -Uri $env:JENKINS_URL -OutFile $jenkinsWar -UseBasicParsing -TimeoutSec 300 ; `
                break ; `
            } catch { `
                $retryCount++ ; `
                if ($retryCount -ge $maxRetries) { `
                    throw "Failed to download Jenkins WAR after $maxRetries attempts: $_" ; `
                } ; `
                Write-Warning "Download attempt $retryCount failed, retrying in 5 seconds..." ; `
                Start-Sleep -Seconds 5 ; `
            } ; `
        } while ($retryCount -lt $maxRetries) ; `
        Write-Host "Verifying Jenkins WAR checksum..." ; `
        $actualHash = (Get-FileHash $jenkinsWar -Algorithm SHA256).Hash ; `
        if ($actualHash -ne $env:JENKINS_SHA) { `
            throw "Jenkins WAR checksum mismatch. Expected: $env:JENKINS_SHA, Actual: $actualHash" ; `
        } ; `
        Write-Host "Jenkins WAR downloaded and verified successfully" ; `
    } catch { `
        Write-Error "Jenkins WAR download failed: $_" ; `
        throw ; `
    }

ENV JENKINS_UC=https://updates.jenkins.io
ENV JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental
ENV JENKINS_INCREMENTALS_REPO_MIRROR=https://repo.jenkins-ci.org/incrementals

ARG PLUGIN_CLI_VERSION=2.13.2
ARG PLUGIN_CLI_URL=https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/${PLUGIN_CLI_VERSION}/jenkins-plugin-manager-${PLUGIN_CLI_VERSION}.jar

# Optimize plugin CLI download with better error handling
RUN try { `
        $pluginCliJar = 'C:/ProgramData/Jenkins/jenkins-plugin-manager.jar' ; `
        Write-Host "Downloading Jenkins Plugin CLI..." ; `
        $sha256Url = $env:PLUGIN_CLI_URL + '.sha256' ; `
        $expectedHash = (Invoke-WebRequest -Uri $sha256Url -UseBasicParsing -TimeoutSec 60).Content.Trim() ; `
        Write-Host "Expected SHA256: $expectedHash" ; `
        Invoke-WebRequest -Uri $env:PLUGIN_CLI_URL -OutFile $pluginCliJar -UseBasicParsing -TimeoutSec 300 ; `
        $actualHash = (Get-FileHash -Path $pluginCliJar -Algorithm SHA256).Hash ; `
        if ($actualHash -ne $expectedHash) { `
            throw "Plugin CLI checksum mismatch. Expected: $expectedHash, Actual: $actualHash" ; `
        } ; `
        Write-Host "Jenkins Plugin CLI downloaded and verified successfully" ; `
    } catch { `
        Write-Error "Plugin CLI download failed: $_" ; `
        throw ; `
    }

# for main web interface:
EXPOSE ${http_port}

# will be used by attached agents:
EXPOSE ${agent_port}

ENV COPY_REFERENCE_FILE_LOG=$JENKINS_HOME/copy_reference_file.log

# Copy supporting files
COPY jenkins-support.psm1 C:/ProgramData/Jenkins/
COPY jenkins.ps1 C:/ProgramData/Jenkins/
COPY jenkins-plugin-cli.ps1 C:/ProgramData/Jenkins/

ENTRYPOINT ["powershell.exe", "-f", "C:/ProgramData/Jenkins/jenkins.ps1"]

# metadata labels
LABEL `
    org.opencontainers.image.vendor="Jenkins project" `
    org.opencontainers.image.title="Official Jenkins Docker image" `
    org.opencontainers.image.description="The Jenkins Continuous Integration and Delivery server" `
    org.opencontainers.image.version="${JENKINS_VERSION}" `
    org.opencontainers.image.url="https://www.jenkins.io/" `
    org.opencontainers.image.source="https://github.com/jenkinsci/docker" `
    org.opencontainers.image.revision="${COMMIT_SHA}" `
    org.opencontainers.image.licenses="MIT"