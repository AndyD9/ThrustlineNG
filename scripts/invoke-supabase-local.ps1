[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("Reset", "Test", "Stop")]
    [string]$Action
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$cli = Join-Path $repositoryRoot "node_modules\.bin\supabase.CMD"
. (Join-Path $PSScriptRoot "docker-tools.ps1")

if (-not (Test-Path -LiteralPath $cli -PathType Leaf)) {
    throw "Supabase CLI missing. Run pnpm install --frozen-lockfile."
}

$dockerPath = Get-DockerCliPath
Enable-DockerCliForProcess -DockerPath $dockerPath

$arguments = switch ($Action) {
    "Reset" { @("db", "reset", "--local") }
    "Test" { @("test", "db", "--network-id", "thrustline-local") }
    "Stop" { @("stop", "--project-id", "thrustline-ng") }
}

Push-Location $repositoryRoot
try {
    & $cli @arguments
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
