[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$cli = Join-Path $repositoryRoot "node_modules\.bin\supabase.CMD"
$networkName = "thrustline-local"

$docker = Get-Command docker -CommandType Application -ErrorAction SilentlyContinue
if (-not $docker) {
    throw "Docker-compatible CLI missing. Install and start a supported local container runtime."
}
if (-not (Test-Path -LiteralPath $cli -PathType Leaf)) {
    throw "Supabase CLI missing. Run pnpm install --frozen-lockfile."
}

$networkBinding = & $docker.Source network inspect $networkName `
    --format '{{ index .Options "com.docker.network.bridge.host_binding_ipv4" }}' `
    2> $null
if ($LASTEXITCODE -ne 0) {
    & $docker.Source network create `
        --opt "com.docker.network.bridge.host_binding_ipv4=127.0.0.1" `
        $networkName | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create the loopback-only Docker network."
    }
}
elseif ($networkBinding.Trim() -ne "127.0.0.1") {
    throw "Docker network '$networkName' exists without the required loopback binding."
}

Push-Location $repositoryRoot
try {
    & $cli start `
        --network-id $networkName `
        --exclude "realtime,storage-api,imgproxy,mailpit,edge-runtime,logflare,vector,supavisor"
    if ($LASTEXITCODE -ne 0) {
        throw "Supabase local stack failed to start."
    }
}
finally {
    Pop-Location
}
