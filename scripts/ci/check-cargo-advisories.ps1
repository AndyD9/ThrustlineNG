[CmdletBinding()]
param(
    [string]$AllowlistPath,
    [string]$ReportPath,
    [string]$LockfilePath,
    [string]$AsOf,
    [switch]$IssuesOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if (-not $AllowlistPath) {
    $AllowlistPath = Join-Path $repositoryRoot "eng/cargo-advisory-allowlist.json"
}

function Read-JsonObject {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label file is missing: $Path"
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

function Get-RequiredText {
    param(
        [Parameter(Mandatory)]
        [object]$Object,
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$Label
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $property.Value -isnot [string] -or
        [string]::IsNullOrWhiteSpace($property.Value)) {
        throw "$Label must provide a non-empty $Name."
    }
    return $property.Value
}

function Get-RequiredDate {
    param(
        [Parameter(Mandatory)]
        [object]$Object,
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$Label
    )

    $text = Get-RequiredText -Object $Object -Name $Name -Label $Label
    $parsed = [datetime]::MinValue
    $styles = [System.Globalization.DateTimeStyles]::None
    if (-not [datetime]::TryParseExact(
            $text,
            "yyyy-MM-dd",
            [System.Globalization.CultureInfo]::InvariantCulture,
            $styles,
            [ref]$parsed)) {
        throw "$Label must express $Name as yyyy-MM-dd."
    }
    return $parsed
}

function Get-AdvisoryWarning {
    param(
        [Parameter(Mandatory)]
        [object]$Report
    )

    $observed = [System.Collections.Generic.List[object]]::new()
    $warningsProperty = $Report.PSObject.Properties["warnings"]
    if ($null -eq $warningsProperty -or $null -eq $warningsProperty.Value) {
        return $observed
    }

    foreach ($kindProperty in $warningsProperty.Value.PSObject.Properties) {
        foreach ($entry in @($kindProperty.Value)) {
            if ($null -eq $entry) { continue }
            $advisoryId = "unidentified"
            $advisoryProperty = $entry.PSObject.Properties["advisory"]
            if ($null -ne $advisoryProperty -and $null -ne $advisoryProperty.Value) {
                $idProperty = $advisoryProperty.Value.PSObject.Properties["id"]
                if ($null -ne $idProperty -and -not [string]::IsNullOrWhiteSpace($idProperty.Value)) {
                    $advisoryId = $idProperty.Value
                }
            }
            $crateName = "unknown"
            $crateVersion = "unknown"
            $packageProperty = $entry.PSObject.Properties["package"]
            if ($null -ne $packageProperty -and $null -ne $packageProperty.Value) {
                $nameProperty = $packageProperty.Value.PSObject.Properties["name"]
                if ($null -ne $nameProperty -and -not [string]::IsNullOrWhiteSpace($nameProperty.Value)) {
                    $crateName = $nameProperty.Value
                }
                $versionProperty = $packageProperty.Value.PSObject.Properties["version"]
                if ($null -ne $versionProperty -and -not [string]::IsNullOrWhiteSpace($versionProperty.Value)) {
                    $crateVersion = $versionProperty.Value
                }
            }
            $observed.Add([pscustomobject]@{
                Id      = $advisoryId
                Crate   = $crateName
                Version = $crateVersion
                Kind    = $kindProperty.Name
            })
        }
    }

    return $observed
}

function Get-CargoAdvisoryIssue {
    param(
        [Parameter(Mandatory)]
        [object]$Allowlist,
        [Parameter(Mandatory)]
        [object]$Report,
        [Parameter(Mandatory)]
        [datetime]$EvaluatedOn
    )

    $issues = [System.Collections.Generic.List[string]]::new()

    $schemaVersion = $Allowlist.PSObject.Properties["schemaVersion"]
    if ($null -eq $schemaVersion -or $schemaVersion.Value -ne 1) {
        $issues.Add("Allowlist schemaVersion must be 1.")
        return $issues
    }

    $reviewedAt = Get-RequiredDate -Object $Allowlist -Name "reviewedAt" -Label "Allowlist"
    $revalidateBefore = Get-RequiredDate -Object $Allowlist -Name "revalidateBefore" -Label "Allowlist"
    Get-RequiredText -Object $Allowlist -Name "context" -Label "Allowlist" | Out-Null
    Get-RequiredText -Object $Allowlist -Name "targetGraphEvidence" -Label "Allowlist" | Out-Null
    $lockfile = Get-RequiredText -Object $Allowlist -Name "lockfile" -Label "Allowlist"

    if ($revalidateBefore -le $reviewedAt) {
        $issues.Add("Allowlist revalidateBefore must follow reviewedAt.")
    }
    if ($EvaluatedOn -ge $revalidateBefore) {
        $issues.Add(
            "Cargo advisory allowlist expired on $($revalidateBefore.ToString('yyyy-MM-dd')); " +
            "re-review each entry and record a new revalidateBefore.")
    }

    $entriesProperty = $Allowlist.PSObject.Properties["allowedAdvisories"]
    if ($null -eq $entriesProperty -or $null -eq $entriesProperty.Value) {
        $issues.Add("Allowlist must declare allowedAdvisories.")
        return $issues
    }
    $entries = @($entriesProperty.Value)

    $allowedKinds = @("unmaintained", "unsound", "notice", "yanked")
    $allowedById = @{}
    foreach ($entry in $entries) {
        $id = Get-RequiredText -Object $entry -Name "id" -Label "Allowlist entry"
        if ($allowedById.ContainsKey($id)) {
            $issues.Add("Duplicate allowlist entry: $id.")
            continue
        }
        $crate = Get-RequiredText -Object $entry -Name "crate" -Label "Allowlist entry $id"
        $version = Get-RequiredText -Object $entry -Name "version" -Label "Allowlist entry $id"
        $kind = Get-RequiredText -Object $entry -Name "kind" -Label "Allowlist entry $id"
        Get-RequiredText -Object $entry -Name "reason" -Label "Allowlist entry $id" | Out-Null
        Get-RequiredText -Object $entry -Name "exitCondition" -Label "Allowlist entry $id" | Out-Null

        if ($allowedKinds -notcontains $kind) {
            $issues.Add("Allowlist entry $id declares an unsupported kind: $kind.")
        }
        $graphProperty = $entry.PSObject.Properties["inWindowsTargetGraph"]
        if ($null -eq $graphProperty -or $graphProperty.Value -isnot [bool]) {
            $issues.Add("Allowlist entry $id must state inWindowsTargetGraph as a boolean.")
        }

        $allowedById[$id] = [pscustomobject]@{
            Id       = $id
            Crate    = $crate
            Version  = $version
            Kind     = $kind
            Observed = $false
        }
    }

    $vulnerabilitiesProperty = $Report.PSObject.Properties["vulnerabilities"]
    if ($null -ne $vulnerabilitiesProperty -and $null -ne $vulnerabilitiesProperty.Value) {
        $found = $vulnerabilitiesProperty.Value.PSObject.Properties["found"]
        $list = @()
        $listProperty = $vulnerabilitiesProperty.Value.PSObject.Properties["list"]
        if ($null -ne $listProperty -and $null -ne $listProperty.Value) {
            $list = @($listProperty.Value)
        }
        if (($null -ne $found -and $found.Value -eq $true) -or $list.Count -gt 0) {
            foreach ($vulnerability in $list) {
                $vulnerabilityId = "unidentified"
                $advisoryProperty = $vulnerability.PSObject.Properties["advisory"]
                if ($null -ne $advisoryProperty -and $null -ne $advisoryProperty.Value) {
                    $idProperty = $advisoryProperty.Value.PSObject.Properties["id"]
                    if ($null -ne $idProperty -and -not [string]::IsNullOrWhiteSpace($idProperty.Value)) {
                        $vulnerabilityId = $idProperty.Value
                    }
                }
                $issues.Add("Cargo reported a vulnerability in $lockfile : $vulnerabilityId.")
            }
            if ($list.Count -eq 0) {
                $issues.Add("Cargo reported a vulnerability in $lockfile without a readable list.")
            }
        }
    }

    foreach ($warning in (Get-AdvisoryWarning -Report $Report)) {
        if (-not $allowedById.ContainsKey($warning.Id)) {
            $issues.Add(
                "Unreviewed Cargo advisory $($warning.Id) ($($warning.Kind)) on " +
                "$($warning.Crate) $($warning.Version). Review it, then either fix the " +
                "dependency or record it in eng/cargo-advisory-allowlist.json.")
            continue
        }

        $allowed = $allowedById[$warning.Id]
        $allowed.Observed = $true
        if ($allowed.Crate -ne $warning.Crate -or $allowed.Version -ne $warning.Version) {
            $issues.Add(
                "Cargo advisory $($warning.Id) now applies to $($warning.Crate) " +
                "$($warning.Version) instead of the reviewed $($allowed.Crate) " +
                "$($allowed.Version).")
        }
        if ($allowed.Kind -ne $warning.Kind) {
            $issues.Add(
                "Cargo advisory $($warning.Id) is now reported as $($warning.Kind) " +
                "instead of the reviewed $($allowed.Kind).")
        }
    }

    foreach ($allowed in $allowedById.Values) {
        if (-not $allowed.Observed) {
            $issues.Add(
                "Allowlisted advisory $($allowed.Id) on $($allowed.Crate) " +
                "$($allowed.Version) is no longer reported; remove the stale entry.")
        }
    }

    return $issues
}

$allowlist = Read-JsonObject -Path $AllowlistPath -Label "Cargo advisory allowlist"

if (-not $LockfilePath) {
    $declaredLockfile = $allowlist.PSObject.Properties["lockfile"]
    if ($null -ne $declaredLockfile -and -not [string]::IsNullOrWhiteSpace($declaredLockfile.Value)) {
        $LockfilePath = Join-Path $repositoryRoot $declaredLockfile.Value
    }
}

if ($ReportPath) {
    $report = Read-JsonObject -Path $ReportPath -Label "Cargo audit report"
}
else {
    if (-not (Test-Path -LiteralPath $LockfilePath -PathType Leaf)) {
        throw "Cargo lockfile is missing: $LockfilePath"
    }
    $auditOutput = & cargo audit --file $LockfilePath --json 2>$null
    if ($null -eq $auditOutput) {
        throw "cargo audit produced no report; install cargo-audit 0.22.2 or pass -ReportPath."
    }
    try {
        $report = ($auditOutput | Out-String) | ConvertFrom-Json
    }
    catch {
        throw "cargo audit did not produce readable JSON."
    }
}

$evaluatedOn = (Get-Date).Date
if ($AsOf) {
    $parsedAsOf = [datetime]::MinValue
    if (-not [datetime]::TryParseExact(
            $AsOf,
            "yyyy-MM-dd",
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::None,
            [ref]$parsedAsOf)) {
        throw "-AsOf must use the yyyy-MM-dd format."
    }
    $evaluatedOn = $parsedAsOf
}

$issues = @(Get-CargoAdvisoryIssue -Allowlist $allowlist -Report $report -EvaluatedOn $evaluatedOn)

if ($IssuesOnly) {
    return $issues
}

if ($issues.Count -gt 0) {
    $issues | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    exit 1
}

$reviewedCount = @($allowlist.allowedAdvisories).Count
Write-Output (
    "Cargo advisory checks passed (0 vulnerabilities, $reviewedCount reviewed " +
    "informational advisories, revalidation before $($allowlist.revalidateBefore)).")
