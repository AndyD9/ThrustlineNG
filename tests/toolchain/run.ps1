#requires -Version 7.6
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$checkScript = Join-Path $repositoryRoot 'scripts/check-toolchain.ps1'
$failures = [System.Collections.Generic.List[string]]::new()
$testCount = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    $script:testCount++
    if (-not $Condition) { $script:failures.Add($Message) }
}

function New-TestRepository {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ("thrustline-toolchain-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $path | Out-Null
    Copy-Item (Join-Path $repositoryRoot 'eng') $path -Recurse
    Copy-Item (Join-Path $repositoryRoot 'scripts') $path -Recurse
    foreach ($file in @('.node-version', '.nvmrc', 'package.json', 'global.json', 'rust-toolchain.toml')) {
        Copy-Item (Join-Path $repositoryRoot $file) $path
    }
    return $path
}

function Invoke-Check {
    param([string]$Root)
    $versions = Get-Content -Raw (Join-Path $Root 'eng/versions.json') | ConvertFrom-Json
    $overrides = @{
        node = "v$($versions.node)"
        pnpm = "$($versions.pnpm)"
        rustc = "rustc $($versions.rust) (test)"
        cargo = "cargo $($versions.rust) (test)"
        dotnet = "$($versions.dotnetSdk)"
        git = 'git version 2.54.0.windows.1'
    }
    $output = & (Join-Path $Root 'scripts/check-toolchain.ps1') -Json -CommandOverrides $overrides 2>&1
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Text = ($output | Out-String).Trim() }
}

$sensitiveName = 'THRUSTLINE_TEST_SECRET'
$sensitiveValue = 'never-print-this-value-7f938'
[Environment]::SetEnvironmentVariable($sensitiveName, $sensitiveValue, 'Process')

$temporaryRoots = [System.Collections.Generic.List[string]]::new()
try {
    $root = New-TestRepository
    $temporaryRoots.Add($root)
    $first = Invoke-Check $root
    Assert-True ($first.ExitCode -eq 0) 'La configuration conforme doit réussir.'
    $parsed = $first.Text | ConvertFrom-Json
    Assert-True ($parsed.schemaVersion -eq 1 -and $parsed.compliant) 'Le mode JSON doit être valide et conforme.'
    Assert-True (-not $first.Text.Contains($sensitiveValue)) 'La sortie ne doit pas révéler la variable sensible factice.'

    $second = Invoke-Check $root
    Assert-True ($second.Text -eq $first.Text) 'Deux contrôles successifs doivent être déterministes.'

    $invalidRoot = New-TestRepository
    $temporaryRoots.Add($invalidRoot)
    Set-Content -LiteralPath (Join-Path $invalidRoot 'eng/versions.json') -Value '{ invalide'
    $invalid = & (Join-Path $invalidRoot 'scripts/check-toolchain.ps1') -Json 2>&1 | Out-String
    Assert-True ($LASTEXITCODE -eq 2) 'Un JSON invalide doit retourner le code 2.'
    Assert-True (($invalid | ConvertFrom-Json).compliant -eq $false) 'Un JSON invalide doit produire un résultat JSON exploitable.'

    foreach ($case in @(
        @{ File = '.node-version'; Value = '0.0.0'; Tool = '.node-version' },
        @{ File = 'rust-toolchain.toml'; Value = "[toolchain]`nchannel = `"0.0.0`""; Tool = 'rust-toolchain.toml' },
        @{ File = 'global.json'; Value = '{"sdk":{"version":"0.0.0","rollForward":"disable"}}'; Tool = 'global.json' }
    )) {
        $caseRoot = New-TestRepository
        $temporaryRoots.Add($caseRoot)
        Set-Content -LiteralPath (Join-Path $caseRoot $case.File) -Value $case.Value
        $result = Invoke-Check $caseRoot
        Assert-True ($result.ExitCode -eq 1) "$($case.Tool) incohérent doit échouer."
        Assert-True (($result.Text | ConvertFrom-Json).results.tool -contains $case.Tool) "$($case.Tool) doit être identifié."
    }

    $pnpmRoot = New-TestRepository
    $temporaryRoots.Add($pnpmRoot)
    $package = Get-Content -Raw (Join-Path $pnpmRoot 'package.json') | ConvertFrom-Json
    $package.engines.pnpm = '0.0.0'
    $package | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $pnpmRoot 'package.json')
    $pnpmResult = Invoke-Check $pnpmRoot
    Assert-True ($pnpmResult.ExitCode -eq 1) 'Un pin pnpm incohérent doit échouer.'

    $missingDotnetRoot = New-TestRepository
    $temporaryRoots.Add($missingDotnetRoot)
    $versions = Get-Content -Raw (Join-Path $missingDotnetRoot 'eng/versions.json') | ConvertFrom-Json
    $overrides = @{
        node = "v$($versions.node)"; pnpm = "$($versions.pnpm)"
        rustc = "rustc $($versions.rust)"; cargo = "cargo $($versions.rust)"
        dotnet = { return $null }; git = 'git version 2.54.0.windows.1'
    }
    $missingText = & (Join-Path $missingDotnetRoot 'scripts/check-toolchain.ps1') -Json -CommandOverrides $overrides 2>&1 | Out-String
    Assert-True ($LASTEXITCODE -eq 1) '.NET absent doit échouer.'
    Assert-True ((($missingText | ConvertFrom-Json).results | Where-Object tool -eq 'dotnet').status -eq 'missing') '.NET absent doit être classé missing.'
} finally {
    [Environment]::SetEnvironmentVariable($sensitiveName, $null, 'Process')
    foreach ($rootToRemove in $temporaryRoots) {
        if (Test-Path -LiteralPath $rootToRemove) {
            Remove-Item -LiteralPath $rootToRemove -Recurse -Force
        }
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    throw "$($failures.Count) échec(s) sur $testCount assertions."
}

Write-Host "$testCount assertions réussies."
