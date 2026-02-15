[CmdletBinding()]
Param(
    [Parameter(Position = 1)]
    # Default script target
    [String] $Target = 'build',
    # Jenkins version to include
    [String] $JenkinsVersion = '2.550',
    # Windows flavor and windows version to build
    [String] $ImageType = 'windowsservercore-ltsc2022',
    # Generate a docker compose file even if it already exists
    [switch] $OverwriteDockerComposeFile = $false,
    # Print the build and publish command instead of executing them if set
    [switch] $DryRun = $false,
    # Output debug info for tests: 'empty' (no additional test output), 'debug' (test cmd & stderr output), 'verbose' (test cmd, stderr, stdout output)
    [String] $TestsDebug = ''
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue' # Disable Progress bar for faster downloads

$Repository = 'jenkins'
$Organisation = 'jenkins'

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_REPO)) {
    $Repository = $env:DOCKERHUB_REPO
}

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_ORGANISATION)) {
    $Organisation = $env:DOCKERHUB_ORGANISATION
}

if(![String]::IsNullOrWhiteSpace($env:JENKINS_VERSION)) {
    $JenkinsVersion = $env:JENKINS_VERSION
}

if(![String]::IsNullOrWhiteSpace($env:IMAGE_TYPE)) {
    $ImageType = $env:IMAGE_TYPE
}

$env:DOCKERHUB_ORGANISATION = "$Organisation"
$env:DOCKERHUB_REPO = "$Repository"
$env:JENKINS_VERSION = "$JenkinsVersion"
$env:COMMIT_SHA = git rev-parse HEAD

# Check for required commands
Function Test-CommandExists {
    Param (
        [String] $command
    )

    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'stop'
    try {
        # Special case to test "docker buildx"
        if ($command.Contains(' ')) {
            Invoke-Expression $command | Out-Null
            Write-Debug "$command exists"
        } else {
            if(Get-Command $command){
                Write-Debug "$command exists"
            }
        }
    }
    Catch {
        "$command does not exist"
    }
    Finally {
        $ErrorActionPreference = $oldPreference
    }
}

function Test-Image {
    param (
        [String] $ImageName
    )

    Write-Host "= TEST: Received ${ImageName} image name"

    $items = $ImageName.split(':')
    $orgRepo = $items[0] -replace 'docker.io/', ''
    $tag = $items[1]

    Write-Host "= TEST: Testing ${tag} tag of ${orgRepo} repository"

    $env:DOCKERHUB_ORG_REPO = $orgRepo
    $env:CONTROLLER_TAG = $tag

    $targetPath = '.\target\{0}' -f $tag
    if (Test-Path $targetPath) {
        Remove-Item -Recurse -Force $targetPath
    }
    New-Item -Path $targetPath -Type Directory | Out-Null
    $configuration.TestResult.OutputPath = '{0}\junit-results.xml' -f $targetPath

    $TestResults = Invoke-Pester -Configuration $configuration
    $failed = $false
    if ($TestResults.FailedCount -gt 0) {
        Write-Host "There were $($TestResults.FailedCount) failed tests in $tag"
        $failed = $true
    } else {
        Write-Host "There were $($TestResults.PassedCount) passed tests out of $($TestResults.TotalCount) in $tag"
    }

    Remove-Item env:\DOCKERHUB_ORG_REPO
    Remove-Item env:\CONTROLLER_TAG

    return $failed
}
function Test-IsLatestJenkinsRelease {
    param (
        [String] $Version
    )

    Write-Host "= PREPARE: Checking if $env:JENKINS_VERSION is latest Weekly or LTS..."

    $metadataUrl = "https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/maven-metadata.xml"
    try {
        [xml]$metadata = Invoke-WebRequest $metadataUrl -UseBasicParsing
    }
    catch {
        Write-Error "Failed to retrieve Jenkins versions from Artifactory"
        exit 1
    }
    $allVersions = $metadata.metadata.versioning.versions.version

    # Weekly
    $weeklyVersions = $allVersions |
        Where-Object { $_ -match '^\d+\.\d+$' } |
        ForEach-Object { [version]$_ } |
        Sort-Object

    # LTS
    $ltsVersions = $allVersions |
        Where-Object { $_ -match '^\d+\.\d+\.\d+$' } |
        ForEach-Object { [version]$_ } |
        Sort-Object

    $latestWeeklyVersion = $weeklyVersions[-1]
    Write-Host "latest Weekly version: $latestWeeklyVersion"
    $latestLTSVersion    = $ltsVersions[-1]
    Write-Host "latest LTS version: $latestLTSVersion"

    $latest = $false
    if ($Version -eq $latestWeeklyVersion) {
        $latest = $true
    }
    if ($Version -eq $latestLTSVersion) {
        $latest = $true
    }
    if (!$latest) {
        Write-Host "WARNING: $JenkinsVersion is neither the lastest Weekly nor the latest LTS version"
    }
    return $latest
}

function Initialize-DockerComposeFile {
    param (
        [String] $ImageType,
        [String] $DockerComposeFile
    )

    Write-Host "= PREPARE: Docker compose file generation for $ImageType"

    $items = $ImageType.Split('-')
    $windowsFlavor = $items[0]
    $windowsVersion = $items[1]

    # Override the list of Windows versions taken defined in docker-bake.hcl by the version from image type
    $env:WINDOWS_VERSION_OVERRIDE = $windowsVersion

    # Retrieve the targets from docker buildx bake --print output
    # Remove the 'output' section (unsupported by docker compose)
    # For each target name as service key, return a map consisting of:
    # - 'image' set to the first tag value
    # - 'build' set to the content of the bake target
    $yqMainQuery = '.target[] | del(.output) | {(. | key): {\"image\": .tags[0], \"build\": .}}'
    # Encapsulate under a top level 'services' map
    $yqServicesQuery = '{\"services\": .}'

    # - Use docker buildx bake to output image definitions from the "<windowsFlavor>" bake target
    # - Convert with yq to the format expected by docker compose
    # - Store the result in the docker compose file
    docker buildx bake --progress=plain --file=docker-bake.hcl $windowsFlavor --print |
        yq --prettyPrint $yqMainQuery |
        yq $yqServicesQuery |
        Out-File -FilePath $DockerComposeFile

    # Remove override
    Remove-Item env:\WINDOWS_VERSION_OVERRIDE
}

Test-CommandExists 'docker'
Test-CommandExists 'docker-compose'
Test-CommandExists 'docker buildx'
Test-CommandExists 'yq'

# Sanity check
yq --version

# Add 'lts-' prefix to LTS tags not including Jenkins version
# Compared to weekly releases, LTS releases include an additional build number in their version
$releaseLine = 'war'
# Determine if the current JENKINS_VERSION corresponds to the latest Weekly or LTS version from Artifactory 
$isJenkinsVersionLatest = Test-IsLatestJenkinsRelease -Version $JenkinsVersion

if ($JenkinsVersion.Split('.').Count -eq 3) {
    $releaseLine = 'war-stable'
    $env:LATEST_LTS = If ($isJenkinsVersionLatest) { "true" } Else { "false" }
} else {
    $env:LATEST_WEEKLY = If ($isJenkinsVersionLatest) { "true" } Else { "false" }
}

# If there is no WAR_URL set, using get.jenkins.io URL depending on the release line
if([String]::IsNullOrWhiteSpace($env:WAR_URL)) {
    $env:WAR_URL = 'https://get.jenkins.io/{0}/{1}/jenkins.war' -f $releaseLine, $JenkinsVersion
}

$dockerComposeFile = 'build-windows_{0}.yaml' -f $ImageType
$baseDockerCmd = 'docker-compose --file={0}' -f $dockerComposeFile
$baseDockerBuildCmd = '{0} build --parallel --pull' -f $baseDockerCmd

# Generate the docker compose file if it doesn't exists or if the parameter OverwriteDockerComposeFile is set
if ((Test-Path $dockerComposeFile) -and -not $OverwriteDockerComposeFile) {
    Write-Host "= PREPARE: The docker compose file '$dockerComposeFile' containing the image definitions already exists."
} else {
    Write-Host "= PREPARE: Initialize the docker compose file '$dockerComposeFile' containing the image definitions."
    Initialize-DockerComposeFile -ImageType $ImageType -DockerComposeFile $dockerComposeFile
}

Write-Host '= PREPARE: List of images and tags to be processed:'
Invoke-Expression "$baseDockerCmd config"

if ($target -eq 'build') {
    Write-Host '= BUILD: Building all images...'

    switch ($DryRun) {
        $true { Write-Host "(dry-run) $baseDockerBuildCmd" }
        $false { Invoke-Expression $baseDockerBuildCmd }
    }

    if ($lastExitCode -ne 0) {
        exit $lastExitCode
    }

    Write-Host '= BUILD: Finished building all images.'
}

if ($target -eq 'test') {
    if ($DryRun) {
        Write-Host '= TEST: (dry-run) test harness skipped'
    } else {
        Write-Host '= TEST: Starting test harness'

        $mod = Get-InstalledModule -Name Pester -MinimumVersion 5.3.0 -MaximumVersion 5.3.3 -ErrorAction SilentlyContinue
        if ($null -eq $mod) {
            Write-Host '= TEST: Pester 5.3.x not found: installing...'
            Install-Module -Force -Name Pester -MaximumVersion 5.3.3 -Scope CurrentUser
        }

        Import-Module Pester
        Write-Host '= TEST: Setting up Pester environment...'
        $configuration = [PesterConfiguration]::Default
        $configuration.Run.PassThru = $true
        $configuration.Run.Path = '.\tests'
        $configuration.Run.Exit = $true
        $configuration.TestResult.Enabled = $true
        $configuration.TestResult.OutputFormat = 'JUnitXml'
        $configuration.Output.Verbosity = 'Diagnostic'
        $configuration.CodeCoverage.Enabled = $false

        Write-Host '= TEST: Testing all images...'
        # Only fail the run afterwards in case of any test failures
        $testFailed = $false
        $imageDefinitions = Invoke-Expression "$baseDockerCmd config" | yq --unwrapScalar --output-format json '.services' | ConvertFrom-Json
        foreach ($imageDefinition in $imageDefinitions.PSObject.Properties) {
            $testFailed = $testFailed -or (Test-Image -ImageName $imageDefinition.Value.image)
        }

        # Fail if any test failures
        if ($testFailed -ne $false) {
            Write-Error '= TEST: Test stage failed'
            exit 1
        } else {
            Write-Host '= TEST: Test stage passed!'
        }
    }
}

if ($target -eq 'publish') {
    Write-Host '= PUBLISH: push all images and tags'
    switch($DryRun) {
        $true { Write-Host "(dry-run) $baseDockerCmd push" }
        $false { Invoke-Expression "$baseDockerCmd push" }
    }

    # Fail if any issues when publishing the docker images
    if ($lastExitCode -ne 0) {
        Write-Error '= PUBLISH: failed!'
        exit 1
    }
}

if ($lastExitCode -ne 0 -and !$DryRun) {
    Write-Error 'Build failed!'
} else {
    Write-Host 'Build finished successfully'
}
exit $lastExitCode
