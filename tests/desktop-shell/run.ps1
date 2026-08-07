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
$html = Get-Content -Raw -LiteralPath (Join-Path $desktop 'index.html')
# Récursif : une commande ajoutée dans un sous-module doit être vue aussi.
$rust = (Get-ChildItem -LiteralPath (Join-Path $tauriRoot 'src') -Filter '*.rs' -Recurse | Get-Content -Raw) -join "`n"

Assert-True ($cargo -notmatch '(?m)^\s*tauri-plugin-') 'Aucun plugin Tauri n’est autorisé.'
Assert-True ($cargo -match 'tauri\s*=\s*\{[^}]*version\s*=\s*"=2\.11\.5"') 'Le crate Tauri doit être épinglé à 2.11.5.'
Assert-True ($capability.windows.Count -eq 1 -and $capability.windows[0] -eq 'main') 'La capability doit cibler uniquement main.'
Assert-True ($capability.permissions.Count -eq 0) 'Le shell statique ne requiert aucune permission invitée.'
# F0004 J2 : l’unique commande IPC autorisée est flight_summary — lecture seule,
# asynchrone, sans aucun paramètre fourni par la WebView.
$commandAttributes = [regex]::Matches($rust, '#\s*\[\s*tauri::command')
$commands = [regex]::Matches($rust, '#\s*\[\s*tauri::command\s*\]\s*(?:pub\s+)?async\s+fn\s+(\w+)\s*\(([^)]*)\)')
Assert-True ($commandAttributes.Count -eq 1 -and $commands.Count -eq 1) 'La seule commande IPC applicative autorisée est flight_summary (F0004 J2).'
Assert-True ($commands.Count -eq 1 -and $commands[0].Groups[1].Value -eq 'flight_summary') 'La seule commande IPC applicative autorisée est flight_summary (F0004 J2).'
Assert-True ($commands.Count -eq 1 -and $commands[0].Groups[2].Value -match '^\s*app\s*:\s*tauri::AppHandle\s*,?\s*$') 'flight_summary ne doit accepter aucun paramètre fourni par la WebView.'
Assert-True ($html -notmatch '(?i)(https?:|//[^/])') 'Le HTML ne doit charger aucune ressource distante.'
Assert-True ($html -match '(?i)<script\s+type="module"\s+src="/src/main\.tsx"></script>') 'Le seul script HTML doit être le point d’entrée Vite local.'
Assert-True ($html -notmatch '(?i)<script(?!\s+type="module"\s+src="/src/main\.tsx"></script>)') 'Aucun autre script HTML n’est autorisé.'
Assert-True ($config.build.frontendDist -eq '../dist') 'Tauri doit charger exclusivement le build Vite local.'
Assert-True ($config.build.devUrl -eq 'http://127.0.0.1:1420') 'Le serveur de développement doit rester sur loopback.'

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
