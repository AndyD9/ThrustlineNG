[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$checkScript = Join-Path $repositoryRoot "scripts/ci/check-cargo-advisories.ps1"
$allowlistPath = Join-Path $repositoryRoot "eng/cargo-advisory-allowlist.json"

foreach ($path in @($checkScript, $allowlistPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing Cargo advisory file: $path"
    }
}

$allowlist = Get-Content -Raw -Encoding UTF8 -LiteralPath $allowlistPath | ConvertFrom-Json

function New-ReportFromEntries {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Entries,
        [object[]]$Vulnerabilities = @()
    )

    $warnings = [ordered]@{}
    foreach ($entry in $Entries) {
        $kind = $entry.kind
        if (-not $warnings.Contains($kind)) {
            $warnings[$kind] = [System.Collections.Generic.List[object]]::new()
        }
        $warnings[$kind].Add([pscustomobject]@{
            kind     = $kind
            package  = [pscustomobject]@{ name = $entry.crate; version = $entry.version }
            advisory = [pscustomobject]@{ id = $entry.id }
        })
    }

    $materialised = [ordered]@{}
    foreach ($key in $warnings.Keys) {
        $materialised[$key] = @($warnings[$key])
    }

    return [pscustomobject]@{
        database        = [pscustomobject]@{ "advisory-count" = 800 }
        vulnerabilities = [pscustomobject]@{
            found = ($Vulnerabilities.Count -gt 0)
            count = $Vulnerabilities.Count
            list  = @($Vulnerabilities)
        }
        warnings        = [pscustomobject]$materialised
    }
}

function Copy-AllowlistEntry {
    param(
        [Parameter(Mandatory)]
        [object]$Entry
    )

    return [pscustomobject]@{
        id                   = $Entry.id
        crate                = $Entry.crate
        version              = $Entry.version
        kind                 = $Entry.kind
        inWindowsTargetGraph = $Entry.inWindowsTargetGraph
        reason               = $Entry.reason
        exitCondition        = $Entry.exitCondition
    }
}

function New-Allowlist {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Entries,
        [string]$ReviewedAt = $allowlist.reviewedAt,
        [string]$RevalidateBefore = $allowlist.revalidateBefore
    )

    return [pscustomobject]@{
        schemaVersion       = 1
        reviewedAt          = $ReviewedAt
        revalidateBefore    = $RevalidateBefore
        lockfile            = $allowlist.lockfile
        context             = $allowlist.context
        targetGraphEvidence = $allowlist.targetGraphEvidence
        allowedAdvisories   = @($Entries)
    }
}

$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    "thrustline-t0058-" + [Guid]::NewGuid().ToString("N")
)
New-Item -ItemType Directory -Force -Path $temporaryRoot | Out-Null

function Get-ScenarioIssue {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [object]$Allowlist,
        [Parameter(Mandatory)]
        [object]$Report,
        [string]$AsOf
    )

    $allowlistFile = Join-Path $temporaryRoot ("$Name-allowlist.json")
    $reportFile = Join-Path $temporaryRoot ("$Name-report.json")
    [System.IO.File]::WriteAllText(
        $allowlistFile, ($Allowlist | ConvertTo-Json -Depth 8))
    [System.IO.File]::WriteAllText(
        $reportFile, ($Report | ConvertTo-Json -Depth 8))

    $arguments = @{
        AllowlistPath = $allowlistFile
        ReportPath    = $reportFile
        IssuesOnly    = $true
    }
    if ($AsOf) {
        $arguments["AsOf"] = $AsOf
    }

    return @(& $checkScript @arguments)
}

function Assert-Detected {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Issues,
        [Parameter(Mandatory)]
        [string]$Pattern,
        [Parameter(Mandatory)]
        [string]$Scenario
    )

    if ($Issues.Count -eq 0) {
        throw "Harness self-test failed: $Scenario returned no issue."
    }
    if (@($Issues | Where-Object { $_ -match $Pattern }).Count -eq 0) {
        throw "Harness self-test failed: $Scenario did not report '$Pattern'. Got: $($Issues -join ' | ')"
    }
}

try {
    $reviewedEntries = @($allowlist.allowedAdvisories | ForEach-Object { Copy-AllowlistEntry -Entry $_ })
    if ($reviewedEntries.Count -eq 0) {
        throw "The repository allowlist must review at least one advisory."
    }
    $baselineDate = $allowlist.reviewedAt

    $baselineIssues = @(Get-ScenarioIssue `
        -Name "baseline" `
        -Allowlist (New-Allowlist -Entries $reviewedEntries) `
        -Report (New-ReportFromEntries -Entries $reviewedEntries) `
        -AsOf $baselineDate)
    if ($baselineIssues.Count -gt 0) {
        throw "The repository allowlist does not match its own reviewed advisories: $($baselineIssues -join ' | ')"
    }

    $unreviewed = $reviewedEntries + @([pscustomobject]@{
        id      = "RUSTSEC-2099-0001"
        crate   = "thrustline-unreviewed-fixture"
        version = "9.9.9"
        kind    = "unmaintained"
    })
    Assert-Detected `
        -Issues @(Get-ScenarioIssue -Name "unreviewed" `
            -Allowlist (New-Allowlist -Entries $reviewedEntries) `
            -Report (New-ReportFromEntries -Entries $unreviewed) `
            -AsOf $baselineDate) `
        -Pattern "Unreviewed Cargo advisory RUSTSEC-2099-0001" `
        -Scenario "a new informational advisory"

    $vulnerability = [pscustomobject]@{
        package  = [pscustomobject]@{ name = "thrustline-vulnerable-fixture"; version = "1.0.0" }
        advisory = [pscustomobject]@{ id = "RUSTSEC-2099-0002" }
    }
    Assert-Detected `
        -Issues @(Get-ScenarioIssue -Name "vulnerable" `
            -Allowlist (New-Allowlist -Entries $reviewedEntries) `
            -Report (New-ReportFromEntries -Entries $reviewedEntries -Vulnerabilities @($vulnerability)) `
            -AsOf $baselineDate) `
        -Pattern "reported a vulnerability" `
        -Scenario "a real vulnerability"

    $movedEntries = @($reviewedEntries | ForEach-Object { Copy-AllowlistEntry -Entry $_ })
    $movedEntries[0].version = "0.0.0-moved"
    Assert-Detected `
        -Issues @(Get-ScenarioIssue -Name "version-drift" `
            -Allowlist (New-Allowlist -Entries $reviewedEntries) `
            -Report (New-ReportFromEntries -Entries $movedEntries) `
            -AsOf $baselineDate) `
        -Pattern "instead of the reviewed" `
        -Scenario "an advisory that moved to another version"

    $rekindedEntries = @($reviewedEntries | ForEach-Object { Copy-AllowlistEntry -Entry $_ })
    $rekindedEntries[0].kind = "notice"
    Assert-Detected `
        -Issues @(Get-ScenarioIssue -Name "kind-drift" `
            -Allowlist (New-Allowlist -Entries $reviewedEntries) `
            -Report (New-ReportFromEntries -Entries $rekindedEntries) `
            -AsOf $baselineDate) `
        -Pattern "is now reported as" `
        -Scenario "an advisory whose kind changed"

    $remainingEntries = @($reviewedEntries | Select-Object -Skip 1)
    Assert-Detected `
        -Issues @(Get-ScenarioIssue -Name "stale-entry" `
            -Allowlist (New-Allowlist -Entries $reviewedEntries) `
            -Report (New-ReportFromEntries -Entries $remainingEntries) `
            -AsOf $baselineDate) `
        -Pattern "no longer reported; remove the stale entry" `
        -Scenario "an allowlist entry that no longer matches the lockfile"

    $expiredOn = ([datetime]::ParseExact(
            $allowlist.revalidateBefore,
            "yyyy-MM-dd",
            [System.Globalization.CultureInfo]::InvariantCulture)).AddDays(1).ToString("yyyy-MM-dd")
    Assert-Detected `
        -Issues @(Get-ScenarioIssue -Name "expired" `
            -Allowlist (New-Allowlist -Entries $reviewedEntries) `
            -Report (New-ReportFromEntries -Entries $reviewedEntries) `
            -AsOf $expiredOn) `
        -Pattern "allowlist expired" `
        -Scenario "an allowlist past its revalidation date"

    Assert-Detected `
        -Issues @(Get-ScenarioIssue -Name "inverted-window" `
            -Allowlist (New-Allowlist -Entries $reviewedEntries -RevalidateBefore $allowlist.reviewedAt) `
            -Report (New-ReportFromEntries -Entries $reviewedEntries) `
            -AsOf $baselineDate) `
        -Pattern "revalidateBefore must follow reviewedAt" `
        -Scenario "an allowlist without a forward revalidation window"

    $unjustifiedEntries = @($reviewedEntries | ForEach-Object { Copy-AllowlistEntry -Entry $_ })
    $unjustifiedEntries[0].reason = ""
    $unjustifiedDetected = $false
    try {
        Get-ScenarioIssue -Name "unjustified" `
            -Allowlist (New-Allowlist -Entries $unjustifiedEntries) `
            -Report (New-ReportFromEntries -Entries $reviewedEntries) `
            -AsOf $baselineDate | Out-Null
    }
    catch {
        if ("$_" -match "non-empty reason") {
            $unjustifiedDetected = $true
        }
        else {
            throw
        }
    }
    if (-not $unjustifiedDetected) {
        throw "Harness self-test failed: an entry without justification was accepted."
    }
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}

Write-Output (
    "T0058 Cargo advisory checks passed (repository allowlist plus 8 mutation scenarios).")
