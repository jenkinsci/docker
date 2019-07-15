[CmdletBinding()]
Param(
    [String] $Target = 'all',
    [String] $Build = '',
    [String] $AdditionalArgs = ''
)

$builds = @{
    'windows' = 'Dockerfile-windows';
    'windows-jdk11' = 'Dockerfile-windows-jdk11';
}

function Build($Target='all') {
    if($Target -eq "all") {
        foreach($build in $builds.Keys) {
            & docker build -f $builds[$build] .
            if($lastExitCode -ne 0) {
                Write-Error "Docker build failed for $build"
                exit -1
            }
        }
    } else {
        & docker build -f $builds[$Target] .
        if($lastExitCode -ne 0) {
            Write-Error "Docker build failed for $Target"
            exit -1
        }
    }
}

function Test($Target='all') {
    if($Target -eq "all") {
        foreach($build in $builds.Keys) {
            $env:DOCKERFILE="Dockerfile-$build"
            pushd tests
            Invoke-Pester 
            popd 
            rm $env:DOCKERFILE
        }
    } else {
        $env:DOCKERFILE="Dockerfile-$Target"
        pushd tests
        Invoke-Pester 
        popd 
        rm $env:DOCKERFILE
    }
}

switch -wildcard ($Target) {
    # release targets
    "all"       { Build }
    "publish"   { Publish }
    "build-*"   { Build $Target.Substring(6) }
    "test"      { Test }
    "test-*"    { Test $target.Substring(5) }

    default { Write-Error "No target '$Target'" ; Exit -1 }
}
