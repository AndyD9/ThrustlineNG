#requires -Version 7.6
[CmdletBinding()]
param(
    [switch]$Json,
    [string]$VersionsFile,
    [hashtable]$CommandOverrides = @{}
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($VersionsFile)) {
    $VersionsFile = Join-Path $repositoryRoot 'eng/versions.json'
}

$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    param(
        [string]$Tool,
        [string]$Status,
        [string]$Expected,
        [string]$Actual,
        [string]$Message
    )
    $results.Add([pscustomobject]@{
        tool = $Tool
        status = $Status
        expected = $Expected
        actual = $Actual
        message = $Message
    })
}

function Get-VersionFromOutput {
    param([string]$Output)
    $match = [regex]::Match($Output, '(?<!\d)(\d+\.\d+\.\d+)(?!\d)')
    if (-not $match.Success) {
        throw "La sortie ne contient pas de version sémantique."
    }
    return $match.Groups[1].Value
}

function Invoke-VersionCommand {
    param([string]$Name, [string[]]$Arguments)
    if ($CommandOverrides.ContainsKey($Name)) {
        $override = $CommandOverrides[$Name]
        if ($override -is [scriptblock]) {
            $overrideOutput = & $override
            if ($null -eq $overrideOutput) {
                return $null
            }
            return $overrideOutput | Out-String
        }
        return [string]$override
    }
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        return $null
    }
    return (& $command.Source @Arguments 2>&1) | Out-String
}

function Test-ExactTool {
    param(
        [string]$Name,
        [string]$Expected,
        [string[]]$Arguments
    )
    try {
        $output = Invoke-VersionCommand -Name $Name -Arguments $Arguments
        if ($null -eq $output) {
            Add-Result $Name 'missing' $Expected '' "$Name est absent. Consultez docs/SETUP.md."
            return
        }
        $actual = Get-VersionFromOutput $output
        if ($actual -eq $Expected) {
            Add-Result $Name 'ok' $Expected $actual "$Name $actual est conforme."
        } else {
            Add-Result $Name 'wrong_version' $Expected $actual "$Name $actual est installé; version requise : $Expected."
        }
    } catch {
        Add-Result $Name 'unexpected_error' $Expected '' "Impossible de vérifier $Name : $($_.Exception.Message)"
    }
}

function Read-TrimmedFile {
    param([string]$RelativePath)
    return (Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot $RelativePath)).Trim()
}

try {
    $rawVersions = Get-Content -Raw -LiteralPath $VersionsFile
    $versions = $rawVersions | ConvertFrom-Json
    $requiredProperties = @('node', 'pnpm', 'rust', 'tauri', 'tauriBuild', 'tauriCli', 'dotnetSdk', 'dotnetRuntime', 'powershellMinimum', 'schemaVersion')
    foreach ($property in $requiredProperties) {
        if ($null -eq $versions.PSObject.Properties[$property] -or [string]::IsNullOrWhiteSpace([string]$versions.$property)) {
            throw "Propriété obligatoire absente : $property"
        }
    }
    if ([int]$versions.schemaVersion -ne 1) {
        throw "schemaVersion non pris en charge : $($versions.schemaVersion)"
    }
} catch {
    Add-Result 'versions' 'unexpected_error' 'JSON valide (schéma 1)' '' "Source de versions invalide : $($_.Exception.Message)"
    $summary = [pscustomobject]@{ compliant = $false; results = $results }
    if ($Json) { $summary | ConvertTo-Json -Depth 5 -Compress } else { Write-Error $results[0].message -ErrorAction Continue }
    exit 2
}

try {
    $package = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'package.json') | ConvertFrom-Json
    $globalJson = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'global.json') | ConvertFrom-Json
    $rustToolchain = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'rust-toolchain.toml')
    $desktopPackage = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'apps/desktop/package.json') | ConvertFrom-Json
    $desktopCargo = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'apps/desktop/src-tauri/Cargo.toml')
    $nativePins = @(
        @{ Name = '.node-version'; Expected = $versions.node; Actual = Read-TrimmedFile '.node-version' },
        @{ Name = '.nvmrc'; Expected = $versions.node; Actual = Read-TrimmedFile '.nvmrc' },
        @{ Name = 'package engines.node'; Expected = $versions.node; Actual = [string]$package.engines.node },
        @{ Name = 'package engines.pnpm'; Expected = $versions.pnpm; Actual = [string]$package.engines.pnpm },
        @{ Name = 'global.json'; Expected = $versions.dotnetSdk; Actual = [string]$globalJson.sdk.version }
    )
    foreach ($pin in $nativePins) {
        if ($pin.Actual -eq $pin.Expected) {
            Add-Result $pin.Name 'ok' $pin.Expected $pin.Actual 'Pin cohérent.'
        } else {
            Add-Result $pin.Name 'wrong_version' $pin.Expected $pin.Actual 'Pin incohérent avec eng/versions.json.'
        }
    }
    $packageManagerExpected = "pnpm@$($versions.pnpm)+sha512.<intégrité>"
    $packageManagerPattern = '^pnpm@' + [regex]::Escape([string]$versions.pnpm) + '\+sha512\.[0-9a-f]{128}$'
    if ([string]$package.packageManager -match $packageManagerPattern) {
        Add-Result 'packageManager' 'ok' $packageManagerExpected ([string]$package.packageManager) 'Version et intégrité pnpm cohérentes.'
    } else {
        Add-Result 'packageManager' 'wrong_version' $packageManagerExpected ([string]$package.packageManager) 'Pin pnpm ou intégrité incohérent.'
    }
    $rustMatch = [regex]::Match($rustToolchain, '(?m)^\s*channel\s*=\s*"([^"]+)"')
    $rustPin = if ($rustMatch.Success) { $rustMatch.Groups[1].Value } else { '' }
    if ($rustPin -eq $versions.rust) {
        Add-Result 'rust-toolchain.toml' 'ok' $versions.rust $rustPin 'Pin cohérent.'
    } else {
        Add-Result 'rust-toolchain.toml' 'wrong_version' $versions.rust $rustPin 'Pin incohérent avec eng/versions.json.'
    }
    foreach ($tauriPin in @(
        @{ Name = 'tauri crate'; Expected = "=$($versions.tauri)"; Pattern = 'tauri\s*=\s*\{[^}]*version\s*=\s*"([^"]+)"' },
        @{ Name = 'tauri-build crate'; Expected = "=$($versions.tauriBuild)"; Pattern = 'tauri-build\s*=\s*(?:\{[^}]*version\s*=\s*)?"([^"]+)"' }
    )) {
        $match = [regex]::Match($desktopCargo, $tauriPin.Pattern)
        $actual = if ($match.Success) { $match.Groups[1].Value } else { '' }
        if ($actual -eq $tauriPin.Expected) {
            Add-Result $tauriPin.Name 'ok' $tauriPin.Expected $actual 'Pin Tauri cohérent.'
        } else {
            Add-Result $tauriPin.Name 'wrong_version' $tauriPin.Expected $actual 'Pin Tauri incohérent.'
        }
    }
    $tauriCliActual = [string]$desktopPackage.devDependencies.'@tauri-apps/cli'
    if ($tauriCliActual -eq [string]$versions.tauriCli) {
        Add-Result 'Tauri CLI' 'ok' $versions.tauriCli $tauriCliActual 'Pin Tauri CLI cohérent.'
    } else {
        Add-Result 'Tauri CLI' 'wrong_version' $versions.tauriCli $tauriCliActual 'Pin Tauri CLI incohérent.'
    }
} catch {
    Add-Result 'native_pins' 'unexpected_error' 'pins lisibles' '' "Impossible de contrôler les pins : $($_.Exception.Message)"
}

$powerShellActual = $PSVersionTable.PSVersion.ToString()
if ($PSVersionTable.PSVersion -ge [version]$versions.powershellMinimum) {
    Add-Result 'pwsh' 'ok' "$($versions.powershellMinimum)+" $powerShellActual 'PowerShell est compatible.'
} else {
    Add-Result 'pwsh' 'wrong_version' "$($versions.powershellMinimum)+" $powerShellActual 'Installez PowerShell depuis https://learn.microsoft.com/powershell/.'
}

Test-ExactTool 'node' $versions.node @('--version')
Test-ExactTool 'pnpm' $versions.pnpm @('--version')
Test-ExactTool 'rustc' $versions.rust @('--version')
Test-ExactTool 'cargo' $versions.rust @('--version')
Test-ExactTool 'dotnet' $versions.dotnetSdk @('--version')

try {
    $gitOutput = Invoke-VersionCommand 'git' @('--version')
    if ($null -eq $gitOutput) {
        Add-Result 'git' 'missing' 'présent' '' 'Git pour Windows est requis.'
    } else {
        $gitVersion = Get-VersionFromOutput $gitOutput
        Add-Result 'git' 'ok' 'présent' $gitVersion 'Git est disponible.'
    }
} catch {
    Add-Result 'git' 'unexpected_error' 'présent' '' "Impossible de vérifier Git : $($_.Exception.Message)"
}

$compliant = -not ($results | Where-Object { $_.status -ne 'ok' })
$summary = [pscustomobject]@{
    schemaVersion = 1
    compliant = $compliant
    results = $results
}

if ($Json) {
    $summary | ConvertTo-Json -Depth 5 -Compress
} else {
    foreach ($result in $results) {
        $marker = if ($result.status -eq 'ok') { '[OK]' } else { '[ERREUR]' }
        Write-Host "$marker $($result.tool): $($result.message)"
    }
}

if ($compliant) { exit 0 } else { exit 1 }
