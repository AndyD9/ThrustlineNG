[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("Reset", "Test", "Stop")]
    [string]$Action
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "docker-tools.ps1")
. (Join-Path $PSScriptRoot "supabase-local-runtime.ps1")

$dockerPath = Get-DockerCliPath
Enable-DockerCliForProcess -DockerPath $dockerPath

$runtimeExists = Test-DockerResourceExists `
    -ResourceType container `
    -Name $script:SupabaseEngineContainer `
    -DockerPath $dockerPath

if ($Action -eq "Stop") {
    if (-not $runtimeExists) {
        Write-Output "Supabase local runtime is already stopped."
        exit 0
    }
    try {
        Invoke-IsolatedSupabaseCli `
            -DockerPath $dockerPath `
            -Arguments @("stop", "--project-id", $script:SupabaseProjectId) `
            -SuppressOutput
    }
    finally {
        Remove-SupabaseLocalRuntime -DockerPath $dockerPath -PreserveImageCache
    }
    Write-Output "Supabase local runtime stopped; only its source-free image cache is retained."
    exit 0
}

if (-not $runtimeExists) {
    throw "Supabase local runtime is not running. Run pnpm backend:start first."
}

$arguments = switch ($Action) {
    "Reset" { @("db", "reset", "--local") }
    "Test" { @("test", "db") }
}
Invoke-IsolatedSupabaseCli -DockerPath $dockerPath -Arguments $arguments
