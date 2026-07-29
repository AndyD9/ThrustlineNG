[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$checker = Join-Path $root "scripts/check-performance-budgets.ps1"
$budgets = Join-Path $root "eng/stability-performance-budgets.json"
$shellPath = (Get-Process -Id $PID).Path
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    "thrustline-t0015-" + [Guid]::NewGuid().ToString("N")
)

function Write-JsonFixture {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [object]$Value
    )
    $Value | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Invoke-Checker {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $shellPath -NoProfile -File $checker -BudgetsPath $budgets @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = ($output -join "`n")
    }
}

function Assert-Result {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [object]$Result,
        [Parameter(Mandatory)]
        [int]$ExpectedExitCode,
        [string]$ExpectedText
    )
    if ($Result.ExitCode -ne $ExpectedExitCode) {
        throw "$Name returned $($Result.ExitCode), expected $ExpectedExitCode.`n$($Result.Output)"
    }
    if ($ExpectedText -and $Result.Output -notmatch [regex]::Escape($ExpectedText)) {
        throw "$Name did not report '$ExpectedText'.`n$($Result.Output)"
    }
}

New-Item -ItemType Directory -Force -Path $temporaryRoot | Out-Null
try {
    $frontendPath = Join-Path $temporaryRoot "frontend.json"
    $desktopPath = Join-Path $temporaryRoot "desktop.json"
    $bridgePath = Join-Path $temporaryRoot "bridge.json"

    $frontend = [pscustomobject]@{
        schemaVersion = 1
        bundle = [pscustomobject]@{ totalGzipBytes = 100000 }
    }
    $cycles = @(
        1..10 | ForEach-Object {
            [pscustomobject]@{ cycle = $_; cleanExit = $true }
        }
    )
    $desktop = [pscustomobject]@{
        schemaVersion = 1
        sizes = [pscustomobject]@{ launchArtifactsBytes = 6000000 }
        measurements = @(
            1..10 | ForEach-Object {
                [pscustomobject]@{ run = $_; webView2ProcessCount = 1 }
            }
        )
        statistics = [pscustomobject]@{
            coldDisplayMilliseconds = [pscustomobject]@{ median = 100; maximum = 200 }
            warmDisplayMilliseconds = [pscustomobject]@{ median = 90; maximum = 150 }
            privateBytes30Seconds = [pscustomobject]@{ median = 8000000 }
            privateBytes60Seconds = [pscustomobject]@{ median = 9000000 }
            webView2WorkingSetBytes = [pscustomobject]@{ median = 130000000 }
        }
        lifecycleCycles = $cycles
        orphanProcessCount = 0
    }
    $bridge = [pscustomobject]@{
        schemaVersion = 1
        publish = [pscustomobject]@{ totalBytes = 90000000 }
        healthCheck = [pscustomobject]@{
            runs = 10
            statistics = [pscustomobject]@{ median = 150; maximum = 250 }
        }
    }
    Write-JsonFixture $frontendPath $frontend
    Write-JsonFixture $desktopPath $desktop
    Write-JsonFixture $bridgePath $bridge

    $valid = Invoke-Checker @(
        "-FrontendMeasurementsPath", $frontendPath,
        "-DesktopMeasurementsPath", $desktopPath,
        "-BridgeMeasurementsPath", $bridgePath
    )
    Assert-Result "valid measurements" $valid 0 "Performance budgets passed"

    $frontend.bundle.totalGzipBytes = 300000
    Write-JsonFixture $frontendPath $frontend
    $frontendFailure = Invoke-Checker @("-FrontendMeasurementsPath", $frontendPath)
    Assert-Result "frontend overrun" $frontendFailure 1 "frontend.totalGzipBytes exceeded"
    $frontend.bundle.totalGzipBytes = 100000
    Write-JsonFixture $frontendPath $frontend

    $bridge.publish.totalBytes = 140000000
    Write-JsonFixture $bridgePath $bridge
    $bridgeFailure = Invoke-Checker @("-BridgeMeasurementsPath", $bridgePath)
    Assert-Result "bridge overrun" $bridgeFailure 1 "bridge.publishBytes exceeded"
    $bridge.publish.totalBytes = 90000000
    Write-JsonFixture $bridgePath $bridge

    $unknownSchema = [pscustomobject]@{
        schemaVersion = 2
        bundle = [pscustomobject]@{ totalGzipBytes = 100000 }
    }
    Write-JsonFixture $frontendPath $unknownSchema
    $schemaFailure = Invoke-Checker @("-FrontendMeasurementsPath", $frontendPath)
    Assert-Result "unknown schema" $schemaFailure 1 "Unsupported frontend measurement schemaVersion"

    $incomplete = [pscustomobject]@{ schemaVersion = 1 }
    Write-JsonFixture $desktopPath $incomplete
    $incompleteFailure = Invoke-Checker @("-DesktopMeasurementsPath", $desktopPath)
    Assert-Result "incomplete measurements" $incompleteFailure 1 "desktop sizes is missing"
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}

Write-Output "T0015 performance budget checks passed (1 valid and 4 negative scenarios)."
