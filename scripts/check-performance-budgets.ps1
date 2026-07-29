[CmdletBinding()]
param(
    [string]$BudgetsPath,
    [string]$FrontendMeasurementsPath,
    [string]$DesktopMeasurementsPath,
    [string]$BridgeMeasurementsPath,
    [switch]$BuiltArtifacts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
if (-not $BudgetsPath) {
    $BudgetsPath = Join-Path $root "eng/stability-performance-budgets.json"
}

function Read-JsonObject {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label file is missing."
    }
    try {
        $value = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
    }
    catch {
        throw "$Label is not valid JSON."
    }
    if ($null -eq $value) {
        throw "$Label is empty."
    }
    return $value
}

function Get-RequiredProperty {
    param(
        [Parameter(Mandatory)]
        [object]$Object,
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$Label
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        throw "$Label is missing."
    }
    return $property.Value
}

function Get-RequiredNumber {
    param(
        [Parameter(Mandatory)]
        [object]$Object,
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$Label
    )

    $value = Get-RequiredProperty -Object $Object -Name $Name -Label $Label
    if ($value -isnot [ValueType] -or $value -is [bool]) {
        throw "$Label must be numeric."
    }
    return [double]$value
}

function Get-GzipSize {
    param([Parameter(Mandatory)][string]$Path)

    $inputStream = [System.IO.File]::OpenRead($Path)
    $buffer = [System.IO.MemoryStream]::new()
    try {
        $gzip = [System.IO.Compression.GZipStream]::new(
            $buffer,
            [System.IO.Compression.CompressionLevel]::Optimal,
            $true
        )
        try {
            $inputStream.CopyTo($gzip)
        }
        finally {
            $gzip.Dispose()
        }
        return [long]$buffer.Length
    }
    finally {
        $inputStream.Dispose()
        $buffer.Dispose()
    }
}

$budgets = Read-JsonObject -Path $BudgetsPath -Label "Budget configuration"
$budgetSchema = Get-RequiredNumber $budgets "schemaVersion" "Budget schemaVersion"
if ($budgetSchema -ne 1) {
    throw "Unsupported budget schemaVersion."
}
$automated = Get-RequiredProperty $budgets "automated" "automated budgets"
$frontendBudget = Get-RequiredProperty $automated "frontend" "frontend budgets"
$desktopBudget = Get-RequiredProperty $automated "desktop" "desktop budgets"
$bridgeBudget = Get-RequiredProperty $automated "bridge" "bridge budgets"
$releaseTargets = Get-RequiredProperty $budgets "releaseTargets" "releaseTargets"
if ((Get-RequiredProperty $releaseTargets "status" "releaseTargets.status") -ne "Not measured") {
    throw "Release targets must remain explicitly Not measured."
}
foreach ($field in @(
    "totalGzipBytesMax"
)) {
    $null = Get-RequiredNumber $frontendBudget $field "frontend.$field"
}
foreach ($field in @(
    "launchArtifactsBytesMax",
    "coldDisplayMedianMillisecondsMax",
    "coldDisplayMaximumMillisecondsMax",
    "warmDisplayMedianMillisecondsMax",
    "warmDisplayMaximumMillisecondsMax",
    "privateBytes60MedianMax",
    "webView2WorkingSetBytesMedianMax",
    "privateBytesMedianGrowth30To60Max",
    "lifecycleCyclesMin",
    "orphanProcessCountMax"
)) {
    $null = Get-RequiredNumber $desktopBudget $field "desktop.$field"
}
foreach ($field in @(
    "publishBytesMax",
    "healthCheckRunsMin",
    "healthCheckMedianMillisecondsMax",
    "healthCheckMaximumMillisecondsMax"
)) {
    $null = Get-RequiredNumber $bridgeBudget $field "bridge.$field"
}
foreach ($field in @(
    "usableStartupP50MillisecondsMax",
    "usableStartupP95MillisecondsMax",
    "idleDesktopWebViewBridgeBytesP50Max",
    "fourHourMemoryGrowthBytesMax",
    "installedBytesMax",
    "crashFreeSessionsPercentMin",
    "crashFreeWindowDays",
    "crashFreeSampleSizeMin",
    "orphanProcessesMax",
    "doubleFlightClosuresMax",
    "silentDataLossEventsMax",
    "financialMutationsWithoutLedgerMax"
)) {
    $null = Get-RequiredNumber $releaseTargets $field "releaseTargets.$field"
}

$issues = [System.Collections.Generic.List[string]]::new()
$checkedGroups = [System.Collections.Generic.List[string]]::new()

function Assert-Maximum {
    param(
        [string]$Name,
        [double]$Actual,
        [double]$Maximum
    )
    if ($Actual -gt $Maximum) {
        $issues.Add("$Name exceeded: $Actual > $Maximum.")
    }
}

function Assert-Minimum {
    param(
        [string]$Name,
        [double]$Actual,
        [double]$Minimum
    )
    if ($Actual -lt $Minimum) {
        $issues.Add("$Name below minimum: $Actual < $Minimum.")
    }
}

if ($FrontendMeasurementsPath) {
    $frontend = Read-JsonObject $FrontendMeasurementsPath "Frontend measurements"
    if ((Get-RequiredNumber $frontend "schemaVersion" "Frontend schemaVersion") -ne 1) {
        throw "Unsupported frontend measurement schemaVersion."
    }
    $bundle = Get-RequiredProperty $frontend "bundle" "frontend bundle"
    Assert-Maximum `
        "frontend.totalGzipBytes" `
        (Get-RequiredNumber $bundle "totalGzipBytes" "frontend.bundle.totalGzipBytes") `
        (Get-RequiredNumber $frontendBudget "totalGzipBytesMax" "frontend budget")
    $checkedGroups.Add("frontend measurements")
}

if ($DesktopMeasurementsPath) {
    $desktop = Read-JsonObject $DesktopMeasurementsPath "Desktop measurements"
    if ((Get-RequiredNumber $desktop "schemaVersion" "Desktop schemaVersion") -ne 1) {
        throw "Unsupported desktop measurement schemaVersion."
    }
    $sizes = Get-RequiredProperty $desktop "sizes" "desktop sizes"
    $statistics = Get-RequiredProperty $desktop "statistics" "desktop statistics"
    $cold = Get-RequiredProperty $statistics "coldDisplayMilliseconds" "desktop cold statistics"
    $warm = Get-RequiredProperty $statistics "warmDisplayMilliseconds" "desktop warm statistics"
    $private30 = Get-RequiredProperty $statistics "privateBytes30Seconds" "desktop private 30 statistics"
    $private60 = Get-RequiredProperty $statistics "privateBytes60Seconds" "desktop private 60 statistics"
    $webView = Get-RequiredProperty $statistics "webView2WorkingSetBytes" "desktop WebView2 statistics"
    $measurements = @(Get-RequiredProperty $desktop "measurements" "desktop measurements")
    $cycles = @(Get-RequiredProperty $desktop "lifecycleCycles" "desktop lifecycleCycles")

    Assert-Maximum "desktop.launchArtifactsBytes" `
        (Get-RequiredNumber $sizes "launchArtifactsBytes" "desktop.sizes.launchArtifactsBytes") `
        (Get-RequiredNumber $desktopBudget "launchArtifactsBytesMax" "desktop launch budget")
    Assert-Maximum "desktop.coldDisplayMedianMilliseconds" `
        (Get-RequiredNumber $cold "median" "desktop cold median") `
        (Get-RequiredNumber $desktopBudget "coldDisplayMedianMillisecondsMax" "desktop cold median budget")
    Assert-Maximum "desktop.coldDisplayMaximumMilliseconds" `
        (Get-RequiredNumber $cold "maximum" "desktop cold maximum") `
        (Get-RequiredNumber $desktopBudget "coldDisplayMaximumMillisecondsMax" "desktop cold maximum budget")
    Assert-Maximum "desktop.warmDisplayMedianMilliseconds" `
        (Get-RequiredNumber $warm "median" "desktop warm median") `
        (Get-RequiredNumber $desktopBudget "warmDisplayMedianMillisecondsMax" "desktop warm median budget")
    Assert-Maximum "desktop.warmDisplayMaximumMilliseconds" `
        (Get-RequiredNumber $warm "maximum" "desktop warm maximum") `
        (Get-RequiredNumber $desktopBudget "warmDisplayMaximumMillisecondsMax" "desktop warm maximum budget")
    Assert-Maximum "desktop.privateBytes60Median" `
        (Get-RequiredNumber $private60 "median" "desktop private 60 median") `
        (Get-RequiredNumber $desktopBudget "privateBytes60MedianMax" "desktop private memory budget")
    Assert-Maximum "desktop.webView2WorkingSetBytesMedian" `
        (Get-RequiredNumber $webView "median" "desktop WebView2 median") `
        (Get-RequiredNumber $desktopBudget "webView2WorkingSetBytesMedianMax" "desktop WebView2 budget")
    if ($measurements.Count -lt 10 -or @($measurements | Where-Object {
        $null -eq $_.PSObject.Properties["webView2ProcessCount"] -or
        [int]$_.webView2ProcessCount -lt 1
    }).Count -gt 0) {
        $issues.Add("desktop measurements must contain ten runs with an associated WebView2 process.")
    }
    if (@($measurements | Where-Object {
        $null -eq $_.PSObject.Properties["bridgeProcessCount"] -or
        [int]$_.bridgeProcessCount -ne 1
    }).Count -gt 0) {
        $issues.Add("desktop measurements must contain exactly one associated bridge process per run.")
    }
    $privateGrowth = (
        (Get-RequiredNumber $private60 "median" "desktop private 60 median") -
        (Get-RequiredNumber $private30 "median" "desktop private 30 median")
    )
    Assert-Maximum "desktop.privateBytesMedianGrowth30To60" `
        $privateGrowth `
        (Get-RequiredNumber $desktopBudget "privateBytesMedianGrowth30To60Max" "desktop growth budget")
    Assert-Minimum "desktop.lifecycleCycles" `
        $cycles.Count `
        (Get-RequiredNumber $desktopBudget "lifecycleCyclesMin" "desktop cycle budget")
    if (@($cycles | Where-Object {
        $null -eq $_.PSObject.Properties["cleanExit"] -or
        $_.cleanExit -ne $true -or
        $null -eq $_.PSObject.Properties["cleanBridgeExit"] -or
        $_.cleanBridgeExit -ne $true
    }).Count -gt 0) {
        $issues.Add("desktop lifecycle contains an unclean desktop or bridge exit.")
    }
    Assert-Maximum "desktop.orphanProcessCount" `
        (Get-RequiredNumber $desktop "orphanProcessCount" "desktop.orphanProcessCount") `
        (Get-RequiredNumber $desktopBudget "orphanProcessCountMax" "desktop orphan budget")
    Assert-Maximum "desktop.orphanBridgeProcessCount" `
        (Get-RequiredNumber $desktop "orphanBridgeProcessCount" "desktop.orphanBridgeProcessCount") `
        (Get-RequiredNumber $desktopBudget "orphanProcessCountMax" "desktop orphan budget")
    $checkedGroups.Add("desktop measurements")
}

if ($BridgeMeasurementsPath) {
    $bridge = Read-JsonObject $BridgeMeasurementsPath "Bridge measurements"
    if ((Get-RequiredNumber $bridge "schemaVersion" "Bridge schemaVersion") -ne 1) {
        throw "Unsupported bridge measurement schemaVersion."
    }
    $publish = Get-RequiredProperty $bridge "publish" "bridge publish"
    $health = Get-RequiredProperty $bridge "healthCheck" "bridge healthCheck"
    $healthStatistics = Get-RequiredProperty $health "statistics" "bridge healthCheck statistics"
    Assert-Maximum "bridge.publishBytes" `
        (Get-RequiredNumber $publish "totalBytes" "bridge.publish.totalBytes") `
        (Get-RequiredNumber $bridgeBudget "publishBytesMax" "bridge publish budget")
    Assert-Minimum "bridge.healthCheckRuns" `
        (Get-RequiredNumber $health "runs" "bridge.healthCheck.runs") `
        (Get-RequiredNumber $bridgeBudget "healthCheckRunsMin" "bridge run budget")
    Assert-Maximum "bridge.healthCheckMedianMilliseconds" `
        (Get-RequiredNumber $healthStatistics "median" "bridge health median") `
        (Get-RequiredNumber $bridgeBudget "healthCheckMedianMillisecondsMax" "bridge health median budget")
    Assert-Maximum "bridge.healthCheckMaximumMilliseconds" `
        (Get-RequiredNumber $healthStatistics "maximum" "bridge health maximum") `
        (Get-RequiredNumber $bridgeBudget "healthCheckMaximumMillisecondsMax" "bridge health maximum budget")
    $checkedGroups.Add("bridge measurements")
}

if ($BuiltArtifacts) {
    $dist = Join-Path $root "apps/desktop/dist"
    $desktopRelease = Join-Path $root "apps/desktop/src-tauri/target/release"
    $bridgePublish = Join-Path $root "apps/bridge/bin/Release/net10.0/win-x64/publish"
    foreach ($directory in @($dist, $desktopRelease, $bridgePublish)) {
        if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
            throw "A required built artifact directory is missing."
        }
    }
    foreach ($executablePath in @(
        (Join-Path $desktopRelease "thrustline-desktop.exe"),
        (Join-Path $bridgePublish "Thrustline.Bridge.exe")
    )) {
        if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
            throw "A required built executable is missing."
        }
    }

    $bundleFiles = @(
        Get-ChildItem -LiteralPath $dist -File -Recurse |
            Where-Object Extension -In @(".html", ".css", ".js")
    )
    if ($bundleFiles.Count -eq 0) {
        throw "No frontend bundle files were found."
    }
    $bundleGzipBytes = [long]((
        $bundleFiles |
            ForEach-Object { Get-GzipSize $_.FullName } |
            Measure-Object -Sum
    ).Sum)
    $desktopLaunchBytes = [long]((
        Get-ChildItem -LiteralPath $desktopRelease -File |
            Measure-Object Length -Sum
    ).Sum)
    $bridgePublishBytes = [long]((
        Get-ChildItem -LiteralPath $bridgePublish -File -Recurse |
            Measure-Object Length -Sum
    ).Sum)

    Assert-Maximum "built.frontend.totalGzipBytes" $bundleGzipBytes `
        (Get-RequiredNumber $frontendBudget "totalGzipBytesMax" "frontend budget")
    Assert-Maximum "built.desktop.launchArtifactsBytes" $desktopLaunchBytes `
        (Get-RequiredNumber $desktopBudget "launchArtifactsBytesMax" "desktop launch budget")
    Assert-Maximum "built.bridge.publishBytes" $bridgePublishBytes `
        (Get-RequiredNumber $bridgeBudget "publishBytesMax" "bridge publish budget")
    $checkedGroups.Add("built artifact sizes")
}

if ($checkedGroups.Count -eq 0) {
    throw "No measurements or built artifacts were selected."
}
if ($issues.Count -gt 0) {
    $issues | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    exit 1
}

Write-Output "Performance budgets passed: $($checkedGroups -join ', ')."
