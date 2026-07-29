[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$cli = Join-Path $repositoryRoot "node_modules\.bin\supabase.CMD"
$networkName = "thrustline-local"
. (Join-Path $PSScriptRoot "docker-tools.ps1")

function Stop-LocalStackQuietly {
    param(
        [Parameter(Mandatory)]
        [string]$CliPath
    )

    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & $CliPath stop --project-id thrustline-ng *> $null
        return $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
}

if (-not (Test-Path -LiteralPath $cli -PathType Leaf)) {
    throw "Supabase CLI missing. Run pnpm install --frozen-lockfile."
}

$dockerPath = Get-DockerCliPath
Enable-DockerCliForProcess -DockerPath $dockerPath

$serverVersion = & $dockerPath info --format '{{.ServerVersion}}' 2> $null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($serverVersion)) {
    throw "Docker CLI found, but its daemon is unavailable. Start Docker Desktop and wait for the engine."
}

$networkNames = @(& $dockerPath network ls --format '{{.Name}}')
if ($LASTEXITCODE -ne 0) {
    throw "Failed to list Docker networks."
}

if ($networkName -notin $networkNames) {
    & $dockerPath network create `
        --opt "com.docker.network.bridge.host_binding_ipv4=127.0.0.1" `
        $networkName | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create the loopback-only Docker network."
    }
}
else {
    $networkInspection = & $dockerPath network inspect $networkName
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to inspect Docker network '$networkName'."
    }
    $networkData = @($networkInspection | ConvertFrom-Json)
    $networkBinding = $networkData[0].Options.'com.docker.network.bridge.host_binding_ipv4'
    if ($networkBinding -ne "127.0.0.1") {
        throw "Docker network '$networkName' exists without the required loopback binding."
    }
}

Push-Location $repositoryRoot
try {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $cli start `
        --network-id $networkName `
        --exclude "realtime,storage-api,imgproxy,mailpit,edge-runtime,logflare,vector,supavisor" `
        *> $null
    $startExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($startExitCode -ne 0) {
        throw "Supabase local stack failed to start."
    }

    $publishedPorts = @(
        & $dockerPath ps `
            --filter "label=com.supabase.cli.project=thrustline-ng" `
            --format '{{.Ports}}'
    )
    if ($LASTEXITCODE -ne 0) {
        $stopExitCode = Stop-LocalStackQuietly -CliPath $cli
        if ($stopExitCode -ne 0) {
            throw "Failed to verify Supabase ports and failed to stop the local stack."
        }
        throw "Failed to verify Supabase published ports; the local stack was stopped."
    }
    $unsafeBindings = @(
        $publishedPorts | Where-Object { $_ -match '(^|,\s)(0\.0\.0\.0:|\[::\]:)' }
    )
    if ($unsafeBindings.Count -gt 0) {
        $stopExitCode = Stop-LocalStackQuietly -CliPath $cli
        if ($stopExitCode -ne 0) {
            throw "Docker exposed Supabase beyond loopback and the local stack could not be stopped."
        }
        throw "Docker exposed Supabase beyond loopback; the local stack was stopped."
    }

    Write-Output "Supabase local stack started."
}
finally {
    Pop-Location
}
