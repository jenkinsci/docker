[CmdletBinding()]
Param(
    [Parameter(Position=1)]
    [String] $target = "build",
    [String] $TagPrefix = 'latest',
    [String] $AdditionalArgs = '',
    [String] $Build = ''
)

$Repository = 'jenkins'
$Organization = 'jenkins4eval'

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_REPO)) {
    $Repository = $env:DOCKERHUB_REPO
}

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_ORGANISATION)) {
    $Organization = $env:DOCKERHUB_ORGANISATION
}

$builds = @{
    'default' = @{'Dockerfile' = 'Dockerfile-windows' ; 'TagSuffix' = '-windows' };
    'jdk11' = @{'DockerFile' = 'Dockerfile-windows-jdk11'; 'TagSuffix' = '-windows-jdk11' };
    'openj9' = @{'DockerFile' = 'Dockerfile-windows-openj9'; 'TagSuffix' = '-windows-openj9' };
    'openj9-jdk11' = @{'DockerFile' = 'Dockerfile-windows-openj9-jdk11'; 'TagSuffix' = '-windows-openj9-jdk11' };
}

if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
    Write-Host "Building $build => tag=$TagPrefix$($builds[$build]['TagSuffix'])"
    $cmd = "docker build -f {0} -t {1}/{2}:{3}{4} {5} ." -f $builds[$build]['Dockerfile'], $Organization, $Repository, $TagPrefix, $builds[$build]['TagSuffix'], $AdditionalArgs
    Invoke-Expression $cmd
} else {
    foreach($build in $builds.Keys) {
        Write-Host "Building $build => tag=$TagPrefix$($builds[$build]['TagSuffix'])"
        $cmd = "docker build -f {0} -t {1}/{2}:{3}{4} {5} ." -f $builds[$build]['Dockerfile'], $Organization, $Repository, $TagPrefix, $builds[$build]['TagSuffix'], $AdditionalArgs
        Invoke-Expression $cmd
    }
}

if($lastExitCode -ne 0) {
    exit $lastExitCode
}

if($target -eq "publish") {
    if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
        Write-Host "Publishing $build => tag=$TagPrefix$($builds[$build]['TagSuffix'])"
        $cmd = "docker push {0}/{1}:{2}{3}" -f $Organization, $Repository, $TagPrefix, $builds[$build]['TagSuffix']
        Invoke-Expression $cmd
    } else {
        foreach($build in $builds.Keys) {
            Write-Host "Publishing $build => tag=$TagPrefix$($builds[$build]['TagSuffix'])"
            $cmd = "docker push {0}/{1}:{2}{3}" -f $Organization, $Repository, $TagPrefix, $builds[$build]['TagSuffix']
            Invoke-Expression $cmd
        }
    }
}

if($target -eq "test") {
    if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
        Write-Host "Testing $build => tag=$TagPrefix$($builds[$build]['TagSuffix'])"
        $env:DOCKERFILE=$($builds[$build]['Dockerfile'])
        Invoke-Pester -Path tests
        Remove-Item env:\DOCKERFILE
    } else {
        foreach($build in $builds.Keys) {
            Write-Host "Testing $build => tag=$TagPrefix$($builds[$build]['TagSuffix'])"
            $env:DOCKERFILE=$($builds[$build]['Dockerfile'])
            Invoke-Pester -Path tests
            Remove-Item env:\DOCKERFILE
        }
    }
}

if($lastExitCode -ne 0) {
    Write-Error "Build failed!"
} else {
    Write-Host "Build finished successfully"
}
exit $lastExitCode
