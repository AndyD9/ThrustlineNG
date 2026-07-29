[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$OutputDirectory,
    [ValidateRange(5, 50)]
    [int]$Runs = 5,
    [ValidateRange(1, 600)]
    [int]$DisplayTimeoutSeconds = 30,
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$requestedOutput = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory
} else {
    Join-Path $root $OutputDirectory
}
$output = [System.IO.Path]::GetFullPath($requestedOutput)
$executable = Join-Path $root 'apps/desktop/src-tauri/target/release/thrustline-desktop.exe'
$frontend = Join-Path $root 'apps/desktop/dist'

New-Item -ItemType Directory -Force -Path $output | Out-Null

function Invoke-TimedBuild {
    param([string]$Kind)
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    & corepack pnpm desktop:build
    if ($LASTEXITCODE -ne 0) { throw "$Kind build failed with exit code $LASTEXITCODE." }
    $timer.Stop()
    return [math]::Round($timer.Elapsed.TotalSeconds, 3)
}

function Stop-MeasuredProcess {
    param([System.Diagnostics.Process]$Process)
    if (-not $Process.HasExited) {
        $null = $Process.CloseMainWindow()
        if (-not $Process.WaitForExit(10000)) {
            $Process.Kill($true)
            throw 'The shell did not exit cleanly within ten seconds.'
        }
    }
}

function Measure-Launch {
    param([string]$Kind, [int]$Run)
    $startedAt = Get-Date
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $process = Start-Process -FilePath $executable -PassThru
    try {
        $deadline = (Get-Date).AddSeconds($DisplayTimeoutSeconds)
        do {
            Start-Sleep -Milliseconds 50
            $process.Refresh()
        } until ($process.HasExited -or $process.MainWindowHandle -ne 0 -or (Get-Date) -ge $deadline)
        if ($process.HasExited -or $process.MainWindowHandle -eq 0) {
            throw "No visible window was detected for $Kind run $Run."
        }
        $timer.Stop()
        Start-Sleep -Seconds 30
        $process.Refresh()
        if ($process.HasExited) {
            throw "The shell exited unexpectedly before the 30-second measurement."
        }
        $private30 = $process.PrivateMemorySize64
        $handles30 = $process.HandleCount
        Start-Sleep -Seconds 30
        $process.Refresh()
        if ($process.HasExited) {
            throw "The shell exited unexpectedly before the 60-second measurement."
        }
        $children = Get-CimInstance Win32_Process | Where-Object ParentProcessId -eq $process.Id
        $webViewChildren = @($children | Where-Object Name -Match 'msedgewebview2')
        if ($webViewChildren.Count -eq 0) {
            throw "No associated WebView2 process was detected for $Kind run $Run."
        }
        $webViewWorkingSetBytes = [long]0
        foreach ($webViewChild in $webViewChildren) {
            $webViewWorkingSetBytes += [long]$webViewChild.WorkingSetSize
        }
        [pscustomobject]@{
            kind = $Kind
            run = $Run
            startedAt = $startedAt.ToUniversalTime().ToString('o')
            displayMilliseconds = [math]::Round($timer.Elapsed.TotalMilliseconds, 1)
            privateBytes30Seconds = $private30
            privateBytes60Seconds = $process.PrivateMemorySize64
            handles30Seconds = $handles30
            handles60Seconds = $process.HandleCount
            webView2ProcessCount = $webViewChildren.Count
            webView2WorkingSetBytes = $webViewWorkingSetBytes
        }
    } finally {
        Stop-MeasuredProcess $process
    }
}

function Test-LifecycleCycle {
    param([int]$Cycle)
    $process = Start-Process -FilePath $executable -PassThru
    try {
        $deadline = (Get-Date).AddSeconds($DisplayTimeoutSeconds)
        do {
            Start-Sleep -Milliseconds 50
            $process.Refresh()
        } until ($process.HasExited -or $process.MainWindowHandle -ne 0 -or (Get-Date) -ge $deadline)
        if ($process.HasExited -or $process.MainWindowHandle -eq 0) {
            throw "No visible window was detected for lifecycle cycle $Cycle."
        }
    } finally {
        Stop-MeasuredProcess $process
    }
    return [pscustomobject]@{ cycle = $Cycle; cleanExit = $process.ExitCode -eq 0 }
}

function Get-Statistics {
    param([object[]]$Values)
    $ordered = @($Values | Sort-Object)
    $middle = [int][math]::Floor($ordered.Count / 2)
    $median = if ($ordered.Count % 2) {
        $ordered[$middle]
    } else {
        ($ordered[$middle - 1] + $ordered[$middle]) / 2
    }
    return [pscustomobject]@{
        minimum = $ordered[0]
        median = $median
        maximum = $ordered[-1]
    }
}

$cleanBuildSeconds = $null
$incrementalBuildSeconds = $null
if (-not $SkipBuild) {
    & cargo clean --manifest-path (Join-Path $root 'apps/desktop/src-tauri/Cargo.toml')
    if ($LASTEXITCODE -ne 0) { throw 'cargo clean failed.' }
    $cleanBuildSeconds = Invoke-TimedBuild 'Clean'
    $incrementalBuildSeconds = Invoke-TimedBuild 'Incremental'
}
if (-not (Test-Path -LiteralPath $executable)) { throw "Release executable not found: $executable" }

$measurements = [System.Collections.Generic.List[object]]::new()
foreach ($kind in @('cold', 'warm')) {
    for ($run = 1; $run -le $Runs; $run++) {
        $measurements.Add((Measure-Launch $kind $run))
    }
}

$cycles = [System.Collections.Generic.List[object]]::new()
for ($cycle = 1; $cycle -le 10; $cycle++) {
    $cycles.Add((Test-LifecycleCycle $cycle))
}
$orphanCount = @(Get-Process -Name 'thrustline-desktop' -ErrorAction SilentlyContinue).Count
if ($orphanCount -ne 0) { throw "$orphanCount orphan Thrustline process(es) remain." }

$webViewEntry = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\EdgeUpdate\Clients\{F1E7E85E-3B6B-4B05-B7D7-2B0E604E9AB5}' -ErrorAction SilentlyContinue
$webViewVersion = if ($null -ne $webViewEntry -and $null -ne $webViewEntry.PSObject.Properties['pv']) {
    $webViewEntry.PSObject.Properties['pv'].Value
} else {
    $null
}
if (-not $webViewVersion) {
    $webViewEntry = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F1E7E85E-3B6B-4B05-B7D7-2B0E604E9AB5}' -ErrorAction SilentlyContinue
    $webViewVersion = if ($null -ne $webViewEntry -and $null -ne $webViewEntry.PSObject.Properties['pv']) {
        $webViewEntry.PSObject.Properties['pv'].Value
    } else {
        'not detected in registry'
    }
}

$summary = [pscustomobject]@{
    schemaVersion = 1
    measuredAt = (Get-Date).ToUniversalTime().ToString('o')
    commit = (& git -C $root rev-parse HEAD).Trim()
    dirty = [bool](& git -C $root status --porcelain)
    configuration = 'release'
    tools = [pscustomobject]@{
        node = (& node --version).Trim()
        pnpm = (& corepack pnpm --version).Trim()
        rustc = (& rustc --version).Trim()
        cargo = (& cargo --version).Trim()
        tauriCli = (& corepack pnpm --dir (Join-Path $root 'apps/desktop') tauri --version).Trim()
        webView2Evergreen = $webViewVersion
    }
    build = [pscustomobject]@{
        cleanSeconds = $cleanBuildSeconds
        incrementalSeconds = $incrementalBuildSeconds
    }
    sizes = [pscustomobject]@{
        frontendBytes = [long]((Get-ChildItem -LiteralPath $frontend -File -Recurse | Measure-Object Length -Sum).Sum)
        executableBytes = (Get-Item -LiteralPath $executable).Length
        launchArtifactsBytes = [long]((Get-ChildItem -LiteralPath (Split-Path $executable) -File | Measure-Object Length -Sum).Sum)
    }
    measurements = $measurements
    statistics = [pscustomobject]@{
        coldDisplayMilliseconds = Get-Statistics @($measurements | Where-Object kind -eq 'cold' | ForEach-Object displayMilliseconds)
        warmDisplayMilliseconds = Get-Statistics @($measurements | Where-Object kind -eq 'warm' | ForEach-Object displayMilliseconds)
        privateBytes30Seconds = Get-Statistics @($measurements | ForEach-Object privateBytes30Seconds)
        privateBytes60Seconds = Get-Statistics @($measurements | ForEach-Object privateBytes60Seconds)
        webView2WorkingSetBytes = Get-Statistics @($measurements | ForEach-Object webView2WorkingSetBytes)
    }
    lifecycleCycles = $cycles
    orphanProcessCount = $orphanCount
}

$jsonPath = Join-Path $output 'tauri-shell-measurements.json'
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding utf8
Write-Host "Measurements written to $jsonPath"
