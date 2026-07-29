[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$OutputDirectory,
    [ValidateRange(10, 100)]
    [int]$Runs = 10,
    [ValidateRange(1, 60)]
    [int]$TimeoutSeconds = 10,
    [switch]$SkipPublish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$requestedOutput = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory
}
else {
    Join-Path $root $OutputDirectory
}
$output = [System.IO.Path]::GetFullPath($requestedOutput)
$publishDirectory = Join-Path $root "apps/bridge/bin/Release/net10.0/win-x64/publish"
$executable = Join-Path $publishDirectory "Thrustline.Bridge.exe"

New-Item -ItemType Directory -Force -Path $output | Out-Null

if (-not $SkipPublish) {
    Push-Location $root
    try {
        & corepack pnpm bridge:publish
        if ($LASTEXITCODE -ne 0) {
            throw "Bridge publish failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }
}
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw "Published bridge executable is missing."
}

$durations = [System.Collections.Generic.List[double]]::new()
for ($run = 1; $run -le $Runs; $run++) {
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $executable
    $startInfo.Arguments = "--health-check"
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    if (-not $process.Start()) {
        throw "Bridge health check run $run did not start."
    }
    try {
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $process.Kill()
            throw "Bridge health check run $run timed out."
        }
        $timer.Stop()
        $standardOutput = $process.StandardOutput.ReadToEnd().Trim()
        $standardError = $process.StandardError.ReadToEnd().Trim()
        if ($process.ExitCode -ne 0 -or $standardOutput -cne "Healthy" -or $standardError) {
            throw "Bridge health check run $run returned an invalid result."
        }
        $durations.Add([math]::Round($timer.Elapsed.TotalMilliseconds, 1))
    }
    finally {
        if (-not $process.HasExited) {
            $process.Kill()
        }
        $process.Dispose()
    }
}

$ordered = @($durations | Sort-Object)
$middle = [int][math]::Floor($ordered.Count / 2)
$median = if ($ordered.Count % 2) {
    $ordered[$middle]
}
else {
    ($ordered[$middle - 1] + $ordered[$middle]) / 2
}
$publishBytes = [long]((
    Get-ChildItem -LiteralPath $publishDirectory -File -Recurse |
        Measure-Object Length -Sum
).Sum)

$summary = [pscustomobject]@{
    schemaVersion = 1
    measuredAt = (Get-Date).ToUniversalTime().ToString("o")
    commit = (& git -C $root rev-parse HEAD).Trim()
    dirty = [bool](& git -C $root status --porcelain)
    configuration = "Release"
    runtime = "win-x64 self-contained"
    publish = [pscustomobject]@{
        fileCount = @(
            Get-ChildItem -LiteralPath $publishDirectory -File -Recurse
        ).Count
        totalBytes = $publishBytes
    }
    healthCheck = [pscustomobject]@{
        runs = $Runs
        durationsMilliseconds = $durations
        statistics = [pscustomobject]@{
            minimum = $ordered[0]
            median = $median
            maximum = $ordered[-1]
        }
    }
}

$jsonPath = Join-Path $output "bridge-measurements.json"
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
Write-Output "Bridge measurements written successfully."
