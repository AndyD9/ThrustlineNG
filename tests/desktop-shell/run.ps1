[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$desktop = Join-Path $root 'apps/desktop'
$tauriRoot = Join-Path $desktop 'src-tauri'
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { $failures.Add($Message) }
}

$cargo = Get-Content -Raw -LiteralPath (Join-Path $tauriRoot 'Cargo.toml')
$config = Get-Content -Raw -LiteralPath (Join-Path $tauriRoot 'tauri.conf.json') | ConvertFrom-Json
$capability = Get-Content -Raw -LiteralPath (Join-Path $tauriRoot 'capabilities/default.json') | ConvertFrom-Json
$html = Get-Content -Raw -LiteralPath (Join-Path $desktop 'web/index.html')
$rust = (Get-ChildItem -LiteralPath (Join-Path $tauriRoot 'src') -Filter '*.rs' | Get-Content -Raw) -join "`n"

Assert-True ($cargo -notmatch '(?m)^\s*tauri-plugin-') 'Aucun plugin Tauri n’est autorisé.'
Assert-True ($cargo -match 'tauri\s*=\s*\{[^}]*version\s*=\s*"=2\.11\.5"') 'Le crate Tauri doit être épinglé à 2.11.5.'
Assert-True ($capability.windows.Count -eq 1 -and $capability.windows[0] -eq 'main') 'La capability doit cibler uniquement main.'
Assert-True ($capability.permissions.Count -eq 0) 'Le shell statique ne requiert aucune permission invitée.'
Assert-True ($rust -notmatch '#\s*\[\s*tauri::command') 'Aucune commande IPC applicative n’est autorisée.'
Assert-True ($html -notmatch '(?i)(https?:|//[^/])') 'Le HTML ne doit charger aucune ressource distante.'
Assert-True ($html -notmatch '(?i)<script') 'Le baseline ne doit contenir aucun script.'

$csp = [string]$config.app.security.csp
foreach ($directive in @(
    "default-src 'self'", "script-src 'self'", "style-src 'self'",
    "connect-src 'none'", "object-src 'none'", "frame-src 'none'",
    "frame-ancestors 'none'", "base-uri 'self'", "form-action 'self'"
)) {
    Assert-True ($csp.Contains($directive)) "Directive CSP manquante : $directive"
}
Assert-True ($csp -notmatch '(?i)(https?:|wss?:|\*|unsafe-inline|unsafe-eval)') 'La CSP ne doit autoriser aucune origine réseau ou directive dangereuse.'

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    throw "$($failures.Count) invariant(s) du shell ont échoué."
}

Write-Host 'Tous les invariants de sécurité du shell sont conformes.'
