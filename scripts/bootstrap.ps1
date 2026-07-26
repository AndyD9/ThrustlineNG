#requires -Version 7.6
[CmdletBinding()]
param([switch]$CheckOnly)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$checkScript = Join-Path $PSScriptRoot 'check-toolchain.ps1'

& $checkScript
if ($LASTEXITCODE -ne 0) {
    throw 'Toolchain incompatible. Corrigez les erreurs ci-dessus en suivant docs/SETUP.md.'
}

if ($CheckOnly) {
    Write-Host 'Contrôle terminé. Aucun changement effectué.'
    exit 0
}

Push-Location $repositoryRoot
try {
    if (-not (Test-Path -LiteralPath 'pnpm-lock.yaml')) {
        throw 'pnpm-lock.yaml est absent; restauration figée impossible.'
    }
    & pnpm install --frozen-lockfile
    if ($LASTEXITCODE -ne 0) {
        throw "La restauration pnpm a échoué avec le code $LASTEXITCODE."
    }
    Write-Host 'Bootstrap terminé.'
} finally {
    Pop-Location
}
