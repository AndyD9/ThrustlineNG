[CmdletBinding()]
param(
    [switch]$Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$target = Join-Path $repositoryRoot "packages\database\src\database.types.ts"
. (Join-Path $PSScriptRoot "docker-tools.ps1")
. (Join-Path $PSScriptRoot "supabase-local-runtime.ps1")

$dockerPath = Get-DockerCliPath
Enable-DockerCliForProcess -DockerPath $dockerPath

if (-not (Test-DockerResourceExists -ResourceType container -Name $script:SupabaseEngineContainer -DockerPath $dockerPath)) {
    throw "Supabase local runtime is not running. Run pnpm backend:start first."
}

$generatedLines = @(
    Invoke-IsolatedSupabaseCli `
        -DockerPath $dockerPath `
        -Arguments @(
            "gen", "types", "typescript",
            "--local",
            "--schema", "public"
        )
)

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
