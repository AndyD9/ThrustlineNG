[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$OutputDirectory,
    [ValidateRange(5, 50)]
    [int]$Runs = 5,
    [switch]$SkipRuntime
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$desktop = Join-Path $root 'apps/desktop'
$dist = [System.IO.Path]::GetFullPath((Join-Path $desktop 'dist'))
$expectedDist = [System.IO.Path]::GetFullPath((Join-Path $root 'apps/desktop/dist'))
$requestedOutput = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory
} else {
    Join-Path $root $OutputDirectory
}
$output = [System.IO.Path]::GetFullPath($requestedOutput)

if ($dist -ne $expectedDist) {
    throw "Refusing to clean unexpected output directory: $dist"
}

New-Item -ItemType Directory -Force -Path $output | Out-Null

function Invoke-TimedCommand {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [scriptblock]$Command
    )

    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    & $Command | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE."
    }
    $timer.Stop()
    return [math]::Round($timer.Elapsed.TotalSeconds, 3)
}

function Get-GzipSize {
    param([Parameter(Mandatory)][string]$Path)

    $input = [System.IO.File]::OpenRead($Path)
    $buffer = [System.IO.MemoryStream]::new()
    try {
        $gzip = [System.IO.Compression.GZipStream]::new(
            $buffer,
            [System.IO.Compression.CompressionLevel]::Optimal,
            $true
        )
        try {
            $input.CopyTo($gzip)
        } finally {
            $gzip.Dispose()
        }
        return $buffer.Length
    } finally {
        $input.Dispose()
        $buffer.Dispose()
    }
}

Push-Location $root
try {
    $typecheckSeconds = Invoke-TimedCommand 'Frontend typecheck' {
        & corepack pnpm frontend:typecheck
    }
    $testSeconds = Invoke-TimedCommand 'Frontend tests' {
        & corepack pnpm frontend:test
    }

    if (Test-Path -LiteralPath $dist) {
        Remove-Item -LiteralPath $dist -Recurse -Force
    }
    $cleanBuildSeconds = Invoke-TimedCommand 'Clean Vite build' {
        & corepack pnpm frontend:build
    }
    $incrementalBuildSeconds = Invoke-TimedCommand 'Incremental Vite build' {
        & corepack pnpm frontend:build
    }
    if (-not $SkipRuntime) {
        Invoke-TimedCommand 'Tauri release build' {
            & corepack pnpm desktop:build
        } | Out-Null

        & powershell -NoProfile -ExecutionPolicy Bypass `
            -File (Join-Path $PSScriptRoot 'measure-tauri-shell.ps1') `
            -OutputDirectory $output `
            -Runs $Runs `
            -SkipBuild
        if ($LASTEXITCODE -ne 0) {
            throw "Tauri runtime measurement failed with exit code $LASTEXITCODE."
        }
    }
} finally {
    Pop-Location
}

$bundleFiles = @(
    Get-ChildItem -LiteralPath $dist -File -Recurse |
        Where-Object Extension -In @('.html', '.css', '.js') |
        ForEach-Object {
            [pscustomobject]@{
                path = $_.FullName.Substring($dist.Length).TrimStart('\', '/').Replace('\', '/')
                extension = $_.Extension
                bytes = $_.Length
                gzipBytes = Get-GzipSize $_.FullName
            }
        }
)

$tauriMeasurementsPath = Join-Path $output 'tauri-shell-measurements.json'
$tauri = Get-Content -Raw -LiteralPath $tauriMeasurementsPath | ConvertFrom-Json
$desktopPackage = Get-Content -Raw -LiteralPath (Join-Path $desktop 'package.json') | ConvertFrom-Json
$baselineExecutableBytes = 2687488
$baselineFrontendBytes = 1529

$summary = [pscustomobject]@{
    schemaVersion = 1
    measuredAt = (Get-Date).ToUniversalTime().ToString('o')
    commit = (& git -C $root rev-parse HEAD).Trim()
    dirty = [bool](& git -C $root status --porcelain)
    tools = [pscustomobject]@{
        node = (& node --version).Trim()
        pnpm = (& corepack pnpm --version).Trim()
        typescript = $desktopPackage.devDependencies.typescript
        vite = $desktopPackage.devDependencies.vite
        vitest = $desktopPackage.devDependencies.vitest
    }
    durations = [pscustomobject]@{
        typecheckSeconds = $typecheckSeconds
        testsSeconds = $testSeconds
        cleanViteBuildSeconds = $cleanBuildSeconds
        incrementalViteBuildSeconds = $incrementalBuildSeconds
    }
    bundle = [pscustomobject]@{
        files = $bundleFiles
        chunkCount = @($bundleFiles | Where-Object extension -eq '.js').Count
        totalBytes = [long](($bundleFiles | Measure-Object bytes -Sum).Sum)
        totalGzipBytes = [long](($bundleFiles | Measure-Object gzipBytes -Sum).Sum)
    }
    runtime = $tauri
    deltaFromT0007 = [pscustomobject]@{
        frontendBytes = [long](($bundleFiles | Measure-Object bytes -Sum).Sum) - $baselineFrontendBytes
        executableBytes = [long]$tauri.sizes.executableBytes - $baselineExecutableBytes
        note = 'Runtime timings and memory are reported side by side; no causal claim is made.'
    }
}

$jsonPath = Join-Path $output 'frontend-measurements.json'
$summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding utf8
Write-Host "Frontend measurements written to $jsonPath"
