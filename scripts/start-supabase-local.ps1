[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "docker-tools.ps1")
. (Join-Path $PSScriptRoot "supabase-local-runtime.ps1")

$dockerPath = Get-DockerCliPath
Enable-DockerCliForProcess -DockerPath $dockerPath

$serverVersion = & $dockerPath info --format '{{.ServerVersion}}' 2> $null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($serverVersion)) {
    throw "Docker CLI found, but its daemon is unavailable. Start Docker Desktop and wait for the engine."
}
if (Test-DockerResourceExists -ResourceType container -Name $script:SupabaseEngineContainer -DockerPath $dockerPath) {
    throw "The isolated Supabase runtime already exists. Stop it before starting a new stack."
}

try {
    Initialize-SupabaseCliImage -DockerPath $dockerPath -RepositoryRoot $repositoryRoot

    & $dockerPath network create $script:SupabaseControlNetwork | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create the isolated Supabase control network."
    }
    & $dockerPath volume create $script:SupabaseProjectVolume | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create the isolated Supabase project volume."
    }
    & $dockerPath volume create $script:SupabaseEngineCacheVolume | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create the isolated Supabase image cache."
    }

    & $dockerPath run `
        --detach `
        --privileged `
        --name $script:SupabaseEngineContainer `
        --network $script:SupabaseControlNetwork `
        --network-alias $script:SupabaseEngineContainer `
        --env "DOCKER_TLS_CERTDIR=" `
        --label "com.thrustline.local-runtime=true" `
        --publish "127.0.0.1:54321:54321" `
        --publish "127.0.0.1:54322:54322" `
        --publish "127.0.0.1:54323:54323" `
        --volume "${script:SupabaseProjectVolume}:/workspace" `
        --volume "${script:SupabaseEngineCacheVolume}:/var/lib/docker" `
        $script:SupabaseDindImage | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to start the isolated Docker engine."
    }

    Wait-SupabaseEngine -DockerPath $dockerPath
    Copy-SupabaseProjectToEngine -DockerPath $dockerPath -RepositoryRoot $repositoryRoot

    Invoke-IsolatedSupabaseCli `
        -DockerPath $dockerPath `
        -Arguments @(
            "start",
            "--exclude", "realtime,storage-api,imgproxy,mailpit,edge-runtime,logflare,vector,supavisor"
        ) `
        -SuppressOutput

    Assert-SupabaseOuterBindings -DockerPath $dockerPath
    Write-Output "Supabase local stack started on IPv4 loopback in an isolated Docker engine."
}
catch {
    $failure = $_
    try {
        Remove-SupabaseLocalRuntime -DockerPath $dockerPath
    }
    catch {
        throw "$($failure.Exception.Message) Cleanup also failed: $($_.Exception.Message)"
    }
    throw $failure
}
