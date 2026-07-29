[CmdletBinding()]
param(
    [switch]$Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$cli = Join-Path $repositoryRoot "node_modules\.bin\supabase.CMD"
$target = Join-Path $repositoryRoot "packages\database\src\database.types.ts"
. (Join-Path $PSScriptRoot "docker-tools.ps1")

if (-not (Test-Path -LiteralPath $cli -PathType Leaf)) {
    throw "Supabase CLI missing. Run pnpm install --frozen-lockfile."
}

$dockerPath = Get-DockerCliPath
Enable-DockerCliForProcess -DockerPath $dockerPath

Push-Location $repositoryRoot
try {
    $generatedLines = & $cli gen types typescript `
        --local `
        --schema public `
        --network-id thrustline-local
    if ($LASTEXITCODE -ne 0) {
        throw "Supabase type generation failed. Ensure the local stack is running."
    }
}
finally {
    Pop-Location
}

$generated = (($generatedLines -join "`n").TrimEnd() + "`n")

if ($Check) {
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        throw "Generated database types are missing."
    }

    $current = [System.IO.File]::ReadAllText($target).Replace("`r`n", "`n")
    if ($current -ne $generated) {
        throw "Generated database types are stale. Run pnpm backend:types."
    }

    Write-Output "Database types match the local schema."
    exit 0
}

[System.IO.File]::WriteAllText(
    $target,
    $generated,
    [System.Text.UTF8Encoding]::new($false)
)
Write-Output "Generated packages/database/src/database.types.ts."
