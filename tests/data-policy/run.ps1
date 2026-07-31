[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-DataPolicyIssues {
    param(
        [Parameter(Mandatory)]
        [string]$Root
    )

    $issues = [System.Collections.Generic.List[string]]::new()

    function Require-DayMaximum {
        param(
            [object]$Value,
            [int]$Maximum,
            [string]$Label
        )

        if ($Value -isnot [int] -and $Value -isnot [long]) {
            $issues.Add("$Label must be an integer number of days.")
        }
        elseif ([long]$Value -lt 1 -or [long]$Value -gt $Maximum) {
            $issues.Add("$Label must be between 1 and $Maximum days.")
        }
    }

    $policyPath = Join-Path $Root "eng\data-policy.json"
    $documentationPath = Join-Path $Root "docs\DATA_POLICY.md"
    $knownIssuesPath = Join-Path $Root "docs\KNOWN_ISSUES.md"
    $seedPath = Join-Path $Root "supabase\seed.sql"
    $migrationPath = Join-Path $Root "supabase\migrations\20260728000100_create_companies.sql"
    $lifecycleMigrationPath = Join-Path $Root "supabase\migrations\20260731000100_account_lifecycle.sql"
    $lifecycleTestPath = Join-Path $Root "supabase\tests\database\account_lifecycle.test.sql"
    $restoreMigrationPath = Join-Path $Root "supabase\migrations\20260731000200_account_deletion_restore_replay.sql"
    $restoreTestPath = Join-Path $Root "supabase\tests\database\account_restore_replay.test.sql"
    $backendCiPath = Join-Path $Root "scripts\ci\test-backend.ps1"
    $packagePath = Join-Path $Root "package.json"
    $ciPath = Join-Path $Root ".github\workflows\ci.yml"
    $ciHarnessPath = Join-Path $Root "tests\ci\run.ps1"

    foreach ($path in @(
        $policyPath,
        $documentationPath,
        $knownIssuesPath,
        $seedPath,
        $migrationPath,
        $lifecycleMigrationPath,
        $lifecycleTestPath,
        $restoreMigrationPath,
        $restoreTestPath,
        $backendCiPath,
        $packagePath,
        $ciPath,
        $ciHarnessPath
    )) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $issues.Add("Missing data-policy file: $([System.IO.Path]::GetFileName($path))")
        }
    }
    if ($issues.Count -gt 0) {
        return $issues
    }

    try {
        $policy = Get-Content -Raw -Encoding UTF8 $policyPath | ConvertFrom-Json
    }
    catch {
        $issues.Add("Data policy JSON is invalid.")
        return $issues
    }

    if ($policy.schemaVersion -ne 1) {
        $issues.Add("Data policy schemaVersion must be 1.")
    }
    if ([string]$policy.admission.realUserData -ne
        "blocked-until-deletion-export-and-restore-controls-exist") {
        $issues.Add("Real user data must remain blocked until lifecycle controls exist.")
    }
    if ([string]$policy.admission.historicalRepositoryDataMigration -ne "forbidden") {
        $issues.Add("Historical repository data migration must remain forbidden.")
    }
    if ([string]$policy.admission.defaultCollection -ne "deny") {
        $issues.Add("Data collection must be denied by default.")
    }

    $expectedEnvironments = @("local", "ci", "staging", "production")
    $environmentNames = @($policy.environments | ForEach-Object { [string]$_.name })
    foreach ($name in $expectedEnvironments) {
        if ($name -notin $environmentNames) {
            $issues.Add("Missing environment policy: $name.")
        }
    }
    if ($environmentNames.Count -ne $expectedEnvironments.Count) {
        $issues.Add("Data policy must define exactly four environments.")
    }
    foreach ($environment in @($policy.environments)) {
        if ([string]$environment.name -ne "production" -and
            [bool]$environment.productionDataAllowed) {
            $issues.Add("Production data is allowed outside production: $($environment.name).")
        }
        if ([string]$environment.name -in @("local", "ci") -and
            ([string]$environment.dataSource -ne "synthetic-only" -or
             [string]$environment.remoteProject -ne "forbidden")) {
            $issues.Add("$($environment.name) must be synthetic-only and local.")
        }
        if ([string]$environment.name -in @("staging", "production") -and
            [string]$environment.remoteProject -ne "dedicated-not-provisioned") {
            $issues.Add("$($environment.name) must use a dedicated, not-yet-provisioned project.")
        }
    }

    $requiredCategories = @(
        "authIdentity",
        "companyState",
        "financialLedger",
        "rawFlightTelemetry",
        "flightReports",
        "securityLogs",
        "optionalDiagnostics",
        "backups"
    )
    foreach ($name in $requiredCategories) {
        if ($null -eq $policy.categories.PSObject.Properties[$name]) {
            $issues.Add("Missing data category: $name.")
            continue
        }
        $category = $policy.categories.$name
        foreach ($field in @("purpose", "personalData", "collection", "retention", "endOfLife", "backupHandling")) {
            if ($null -eq $category.PSObject.Properties[$field]) {
                $issues.Add("Category $name is missing field: $field.")
            }
        }
    }

    if ($null -ne $policy.categories.PSObject.Properties["rawFlightTelemetry"]) {
        Require-DayMaximum `
            $policy.categories.rawFlightTelemetry.retention.maxDays `
            7 `
            "Raw flight telemetry retention"
    }
    if ($null -ne $policy.categories.PSObject.Properties["securityLogs"]) {
        Require-DayMaximum `
            $policy.categories.securityLogs.retention.maxDays `
            90 `
            "Security log retention"
    }
    if ($null -ne $policy.categories.PSObject.Properties["optionalDiagnostics"]) {
        Require-DayMaximum `
            $policy.categories.optionalDiagnostics.retention.maxDays `
            30 `
            "Optional diagnostic retention"
        if (-not [bool]$policy.categories.optionalDiagnostics.explicitConsentRequired) {
            $issues.Add("Optional diagnostics must require explicit consent.")
        }
    }
    if ($null -ne $policy.categories.PSObject.Properties["backups"]) {
        Require-DayMaximum `
            $policy.categories.backups.retention.maxDays `
            30 `
            "Backup retention"
    }
    foreach ($name in @("authIdentity", "companyState", "flightReports")) {
        if ($null -ne $policy.categories.PSObject.Properties[$name]) {
            Require-DayMaximum `
                $policy.categories.$name.retention.maxDaysAfterVerifiedDeletionRequest `
                30 `
                "$name deletion window"
        }
    }
    if ($null -ne $policy.categories.PSObject.Properties["financialLedger"]) {
        Require-DayMaximum `
            $policy.categories.financialLedger.retention.maxDaysToAnonymizePersonalLinkAfterVerifiedDeletionRequest `
            30 `
            "Financial ledger anonymization window"
    }

    if (-not [bool]$policy.restore.deletionReplayRequiredBeforeReopen -or
        -not [bool]$policy.restore.integrityVerificationRequired -or
        -not [bool]$policy.restore.scheduledDrillRequired) {
        $issues.Add("Restore policy must require deletion replay, integrity verification, and drills.")
    }
    $expectedCapabilities = @{
        accountExport = "enforced-local-ci"
        accountDeletion = "enforced-local-ci"
        retentionPurge = "not-implemented"
        ledgerAnonymization = "enforced-local-ci"
        managedBackups = "not-implemented"
        restoreDrill = "enforced-local-ci"
        deletionReplayAfterRestore = "enforced-local-ci"
    }
    foreach ($entry in $expectedCapabilities.GetEnumerator()) {
        if ([string]$policy.capabilities.($entry.Key) -ne $entry.Value) {
            $issues.Add(
                "Unexpected capability status for $($entry.Key): expected $($entry.Value)."
            )
        }
    }

    $seed = Get-Content -Raw -Encoding UTF8 $seedPath
    $seedEmails = @(
        [regex]::Matches($seed, "(?i)[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}") |
            ForEach-Object { $_.Value }
    )
    if ($seedEmails.Count -lt 2 -or
        @($seedEmails | Where-Object { $_ -notmatch "(?i)@thrustline\.invalid$" }).Count -gt 0 -or
        $seed -notmatch "Synthetic Alpha Air" -or
        $seed -notmatch "Synthetic Bravo Air") {
        $issues.Add("Supabase seed must contain only the expected synthetic identities.")
    }
    if ($seed -match "(?i)(password|secret|token)\s*=") {
        $issues.Add("Supabase seed contains a secret-like assignment.")
    }

    $migration = Get-Content -Raw -Encoding UTF8 $migrationPath
    $knownIssues = Get-Content -Raw -Encoding UTF8 $knownIssuesPath
    if ($migration -match "on delete restrict" -and $knownIssues -notmatch "KI-021") {
        $issues.Add("The current account-deletion blocker must be tracked as KI-021.")
    }

    $lifecycleMigration = Get-Content -Raw -Encoding UTF8 $lifecycleMigrationPath
    $lifecycleTest = Get-Content -Raw -Encoding UTF8 $lifecycleTestPath
    $backendCi = Get-Content -Raw -Encoding UTF8 $backendCiPath
    if ($lifecycleMigration -notmatch "public\.request_account_deletion" -or
        $lifecycleMigration -notmatch "public\.finalize_account_deletion" -or
        $lifecycleTest -notmatch "B cannot recover A export" -or
        $lifecycleTest -notmatch "an injected finalization failure rolls back" -or
        $backendCi -notmatch "Account lifecycle concurrency passed") {
        $issues.Add("Local-CI account export/deletion evidence is incomplete.")
    }

    $restoreMigration = Get-Content -Raw -Encoding UTF8 $restoreMigrationPath
    $restoreTest = Get-Content -Raw -Encoding UTF8 $restoreTestPath
    if ($restoreMigration -notmatch "private\.account_restoration_subjects" -or
        $restoreMigration -notmatch "public\.replay_account_deletion_event" -or
        $restoreTest -notmatch "replay preserves the unrelated owner B" -or
        $restoreTest -notmatch "an injected replay failure rolls back" -or
        $backendCi -notmatch "pg_restore" -or
        $backendCi -notmatch "Isolated restore replay passed") {
        $issues.Add("Local-CI isolated restore/deletion replay evidence is incomplete.")
    }

    $documentation = Get-Content -Raw -Encoding UTF8 $documentationPath
    $documentationRequirements = @{
        "application status" = "(?m)^## Statut d.application\r?$"
        "classification and retention" = "(?m)^## Classification et r.tention\r?$"
        "environment separation" = "(?m)^## S.+ des environnements\r?$"
        "deletion and export" = "(?m)^## Suppression, anonymisation et export\r?$"
        "backup and restore" = "(?m)^## Sauvegarde et restauration\r?$"
        "official sources" = "(?m)^## Sources officielles\r?$"
    }
    foreach ($entry in $documentationRequirements.GetEnumerator()) {
        if ($documentation -notmatch $entry.Value) {
            $issues.Add("Data policy documentation is missing: $($entry.Key).")
        }
    }

    $package = Get-Content -Raw -Encoding UTF8 $packagePath | ConvertFrom-Json
    if ([string]$package.scripts.'data-policy:check' -notmatch "tests/data-policy/run\.ps1") {
        $issues.Add("Missing data-policy:check package script.")
    }
    $ci = Get-Content -Raw -Encoding UTF8 $ciPath
    $ciHarness = Get-Content -Raw -Encoding UTF8 $ciHarnessPath
    if (-not $ci.Contains("pnpm data-policy:check")) {
        $issues.Add("CI does not execute the data policy gate.")
    }
    if (-not $ciHarness.Contains('"pnpm data-policy:check"') -or
        -not $ciHarness.Contains('"data-policy:check"')) {
        $issues.Add("CI harness does not enforce the data policy gate and package script.")
    }

    return $issues
}

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$repositoryIssues = @(Get-DataPolicyIssues -Root $repositoryRoot)
if ($repositoryIssues.Count -gt 0) {
    $repositoryIssues | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    exit 1
}

$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    "thrustline-t0017-" + [Guid]::NewGuid().ToString("N")
)
try {
    foreach ($relativePath in @(
        "eng\data-policy.json",
        "docs\DATA_POLICY.md",
        "docs\KNOWN_ISSUES.md",
        "supabase\seed.sql",
        "supabase\migrations\20260728000100_create_companies.sql",
        "supabase\migrations\20260731000100_account_lifecycle.sql",
        "supabase\tests\database\account_lifecycle.test.sql",
        "supabase\migrations\20260731000200_account_deletion_restore_replay.sql",
        "supabase\tests\database\account_restore_replay.test.sql",
        "scripts\ci\test-backend.ps1",
        "package.json",
        ".github\workflows\ci.yml",
        "tests\ci\run.ps1"
    )) {
        $destination = Join-Path $temporaryRoot $relativePath
        New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
        Copy-Item -LiteralPath (Join-Path $repositoryRoot $relativePath) -Destination $destination
    }

    $policyCopy = Join-Path $temporaryRoot "eng\data-policy.json"
    $mutation = Get-Content -Raw -Encoding UTF8 $policyCopy | ConvertFrom-Json
    $mutation.categories.PSObject.Properties.Remove("rawFlightTelemetry")
    [System.IO.File]::WriteAllText(
        $policyCopy,
        ($mutation | ConvertTo-Json -Depth 12),
        [System.Text.UTF8Encoding]::new($false)
    )
    $missingCategoryIssues = @(Get-DataPolicyIssues -Root $temporaryRoot)
    if (-not ($missingCategoryIssues -match "Missing data category: rawFlightTelemetry")) {
        throw "Harness self-test failed to detect a missing data category."
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "eng\data-policy.json") -Destination $policyCopy
    $mutation = Get-Content -Raw -Encoding UTF8 $policyCopy | ConvertFrom-Json
    ($mutation.environments | Where-Object name -eq "staging").productionDataAllowed = $true
    [System.IO.File]::WriteAllText(
        $policyCopy,
        ($mutation | ConvertTo-Json -Depth 12),
        [System.Text.UTF8Encoding]::new($false)
    )
    $productionDataIssues = @(Get-DataPolicyIssues -Root $temporaryRoot)
    if (-not ($productionDataIssues -match "Production data is allowed outside production: staging")) {
        throw "Harness self-test failed to detect production data outside production."
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "eng\data-policy.json") -Destination $policyCopy
    $mutation = Get-Content -Raw -Encoding UTF8 $policyCopy | ConvertFrom-Json
    $mutation.categories.securityLogs.retention.maxDays = 91
    [System.IO.File]::WriteAllText(
        $policyCopy,
        ($mutation | ConvertTo-Json -Depth 12),
        [System.Text.UTF8Encoding]::new($false)
    )
    $retentionIssues = @(Get-DataPolicyIssues -Root $temporaryRoot)
    if (-not ($retentionIssues -match "Security log retention must be between 1 and 90 days")) {
        throw "Harness self-test failed to detect an excessive retention period."
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "eng\data-policy.json") -Destination $policyCopy
    $mutation = Get-Content -Raw -Encoding UTF8 $policyCopy | ConvertFrom-Json
    $mutation.capabilities.accountDeletion = "not-implemented"
    [System.IO.File]::WriteAllText(
        $policyCopy,
        ($mutation | ConvertTo-Json -Depth 12),
        [System.Text.UTF8Encoding]::new($false)
    )
    $capabilityIssues = @(Get-DataPolicyIssues -Root $temporaryRoot)
    if (-not ($capabilityIssues -match "Unexpected capability status for accountDeletion")) {
        throw "Harness self-test failed to detect account-deletion status drift."
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "eng\data-policy.json") -Destination $policyCopy
    $mutation = Get-Content -Raw -Encoding UTF8 $policyCopy | ConvertFrom-Json
    $mutation.capabilities.deletionReplayAfterRestore = "not-implemented"
    [System.IO.File]::WriteAllText(
        $policyCopy,
        ($mutation | ConvertTo-Json -Depth 12),
        [System.Text.UTF8Encoding]::new($false)
    )
    $restoreCapabilityIssues = @(Get-DataPolicyIssues -Root $temporaryRoot)
    if (-not ($restoreCapabilityIssues -match "Unexpected capability status for deletionReplayAfterRestore")) {
        throw "Harness self-test failed to detect restore-replay status drift."
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "eng\data-policy.json") -Destination $policyCopy
    $mutation = Get-Content -Raw -Encoding UTF8 $policyCopy | ConvertFrom-Json
    $mutation.capabilities.ledgerAnonymization = "not-implemented"
    [System.IO.File]::WriteAllText(
        $policyCopy,
        ($mutation | ConvertTo-Json -Depth 12),
        [System.Text.UTF8Encoding]::new($false)
    )
    $ledgerCapabilityIssues = @(Get-DataPolicyIssues -Root $temporaryRoot)
    if (-not ($ledgerCapabilityIssues -match "Unexpected capability status for ledgerAnonymization")) {
        throw "Harness self-test failed to detect ledger-anonymization status drift."
    }
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}

Write-Output "Data policy checks passed (T0017-T0020 repository plus 6 mutation scenarios)."
