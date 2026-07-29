function Get-DockerCliPath {
    $commandPaths = @(
        Get-Command docker.exe -CommandType Application -All -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty Path
    )
    $knownPaths = @(
        (Join-Path $env:LOCALAPPDATA "Programs\DockerDesktop\resources\bin\docker.exe"),
        (Join-Path $env:ProgramFiles "Docker\Docker\resources\bin\docker.exe")
    )
    $resolvedPath = @($commandPaths + $knownPaths) |
        Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
        Select-Object -Unique |
        Select-Object -First 1

    if (-not $resolvedPath) {
        throw "Docker-compatible CLI missing. Install and start a supported local container runtime."
    }

    return $resolvedPath
}

function Enable-DockerCliForProcess {
    param(
        [Parameter(Mandatory)]
        [string]$DockerPath
    )

    $dockerDirectory = Split-Path -Parent $DockerPath
    $pathEntries = @($env:Path -split [System.IO.Path]::PathSeparator)
    if ($dockerDirectory -notin $pathEntries) {
        $env:Path = $dockerDirectory + [System.IO.Path]::PathSeparator + $env:Path
    }
}
