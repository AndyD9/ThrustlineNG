[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-CiIssues {
    param(
        [Parameter(Mandatory)]
        [string]$Root
    )

    $issues = [System.Collections.Generic.List[string]]::new()
    $ciPath = Join-Path $Root ".github/workflows/ci.yml"
    $securityPath = Join-Path $Root ".github/workflows/security.yml"
    $packagePath = Join-Path $Root "package.json"
    $backendPath = Join-Path $Root "scripts/ci/test-backend.ps1"
    $licencePath = Join-Path $Root "scripts/ci/write-license-report.ps1"

    foreach ($path in @($ciPath, $securityPath, $packagePath, $backendPath, $licencePath)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $issues.Add("Missing CI file: $([System.IO.Path]::GetFileName($path))")
        }
    }
    if ($issues.Count -gt 0) {
        return $issues
    }

    $ci = Get-Content -Raw -Encoding UTF8 $ciPath
    $security = Get-Content -Raw -Encoding UTF8 $securityPath
    $workflows = "$ci`n$security"
    $package = Get-Content -Raw -Encoding UTF8 $packagePath | ConvertFrom-Json
    $backend = Get-Content -Raw -Encoding UTF8 $backendPath
    $licences = Get-Content -Raw -Encoding UTF8 $licencePath

    if ($workflows -match "(?m)^\s*pull_request_target\s*:") {
        $issues.Add("pull_request_target is forbidden.")
    }
    foreach ($workflow in @($ci, $security)) {
        if ($workflow -notmatch "(?ms)^permissions:\s*\r?\n\s+contents:\s+read\s*$") {
            $issues.Add("Each workflow must grant contents: read only.")
        }
        if ($workflow -notmatch "(?m)^\s+pull_request:\s*$" -or
            $workflow -notmatch "(?ms)^\s+push:\s*\r?\n\s+branches:\s*\r?\n\s+- main\s*$") {
            $issues.Add("Each workflow must run on pull requests and pushes to main.")
        }
        if ($workflow -notmatch "cancel-in-progress:\s+true") {
            $issues.Add("Workflow concurrency must cancel obsolete runs.")
        }
    }
    if ($workflows -match "(?im)(?:\b(?:write|admin):|:\s+(?:write|admin)\s*$)" -or
        $workflows -match "(?i)secrets\.") {
        $issues.Add("CI must not request write permissions or repository secrets.")
    }
    if ($workflows -match "(?m)^\s*runs-on:\s+\S*-latest\s*$" -or
        $workflows -notmatch "runs-on:\s+windows-2025" -or
        $workflows -notmatch "runs-on:\s+ubuntu-24\.04") {
        $issues.Add("CI runners must use explicit Windows and Ubuntu labels.")
    }

    $usesLines = @(
        [regex]::Matches($workflows, "(?m)^\s*uses:\s+([^\r\n]+)$") |
            ForEach-Object { $_.Groups[1].Value.Trim() }
    )
    if ($usesLines.Count -lt 8 -or
        @($usesLines | Where-Object { $_ -notmatch "^[^@\s]+@[0-9a-f]{40}\s+#\s+v[0-9]" }).Count -gt 0) {
        $issues.Add("Every action must be pinned to a full SHA with a version comment.")
    }
    $checkoutCount = ([regex]::Matches($workflows, "actions/checkout@")).Count
    $credentialCount = ([regex]::Matches($workflows, "persist-credentials:\s+false")).Count
    if ($checkoutCount -ne $credentialCount) {
        $issues.Add("Every checkout must disable persisted credentials.")
    }
    $setupNodeCount = ([regex]::Matches($workflows, "actions/setup-node@")).Count
    $disabledNodeCacheCount = (
        [regex]::Matches($workflows, "package-manager-cache:\s+false")
    ).Count
    if ($setupNodeCount -ne $disabledNodeCacheCount) {
        $issues.Add("Every setup-node action must disable its automatic package-manager cache.")
    }
    if ($workflows -match "(?m)^\s+cache:\s+" -and
        ($workflows -notmatch "cache-dependency-path:\s+pnpm-lock\.yaml" -or
         $workflows -match "(?m)^\s+cache-dependency-path:\s+(?!pnpm-lock\.yaml\s*$)")) {
        $issues.Add("Dependency caches must derive from pnpm-lock.yaml.")
    }
    if ($workflows -notmatch "pnpm install --frozen-lockfile") {
        $issues.Add("CI must restore pnpm dependencies from the frozen lockfile.")
    }

    foreach ($marker in @(
        "scripts/check-toolchain.ps1",
        "tests/toolchain/run.ps1",
        "pnpm data-policy:check",
        "pnpm authority:check",
        "pnpm maintenance:check",
        "pnpm frontend:typecheck",
        "pnpm frontend:test",
        "pnpm frontend:coverage",
        "pnpm frontend:build",
        "pnpm desktop:check",
        "pnpm desktop:test",
        "pnpm desktop:build",
        "dotnet restore apps/bridge/Thrustline.Bridge.csproj",
        "--runtime win-x64",
        "--locked-mode",
        "--source https://api.nuget.org/v3/index.json",
        "pnpm bridge:build",
        "pnpm bridge:test",
        "pnpm bridge:health",
        "pnpm bridge:publish",
        "pnpm performance:test",
        "pnpm performance:check:build",
        "pwsh -NoProfile -File ./tests/backend/run.ps1",
        "pnpm ci:backend"
    )) {
        if (-not $ci.Contains($marker)) {
            $issues.Add("Missing CI gate: $marker")
        }
    }
    if ($ci -notmatch "(?ms)if:\s+always\(\).*?supabase stop --project-id thrustline-ng") {
        $issues.Add("Backend cleanup must run always against the local project.")
    }
    foreach ($marker in @(
        "pnpm exec supabase --version",
        "pnpm install --frozen-lockfile --force",
        "network connect",
        "--alias db",
        "supabase test db --network-id"
    )) {
        if (-not $backend.Contains($marker)) {
            $issues.Add("Missing resilient backend restore invariant: $marker")
        }
    }

    foreach ($marker in @(
        "pnpm audit --audit-level high",
        "--vulnerable --include-transitive",
        "cargo install cargo-audit --version 0.22.2 --locked",
        "cargo audit --file apps/desktop/src-tauri/Cargo.lock --json",
        "gitleaks/gitleaks-action@",
        "pnpm supply-chain:report",
        "anchore/sbom-action@",
        "format: spdx-json",
        "Enforce supply-chain results"
    )) {
        if (-not $security.Contains($marker)) {
            $issues.Add("Missing supply-chain gate: $marker")
        }
    }
    if (([regex]::Matches($workflows, "retention-days:\s+30")).Count -lt 2 -or
        $workflows -notmatch "unsigned") {
        $issues.Add("Unsigned build and supply-chain evidence must be explicit and retained 30 days.")
    }

    foreach ($marker in @(
        "host_binding_ipv4=127.0.0.1",
        "--network-id",
        '@("db", "reset", "--local")',
        "companies_structure\.test\.sql",
        "companies_rls\.test\.sql",
        "Result:\s+PASS",
        "Select-Object -First 1",
        "Stop-SupabaseQuietly"
    )) {
        if (-not $backend.Contains($marker)) {
            $issues.Add("Missing backend CI invariant: $marker")
        }
    }
    if ($backend -notmatch "0\\\.0\\\.0\\\.0:|\\\\\[::\\\\\]:") {
        $issues.Add("Missing backend CI invariant: wildcard port rejection.")
    }
    if ($backend -match "(^|\s)(link|db push|--linked)(\s|$)") {
        $issues.Add("Backend CI contains a remote-capable Supabase command.")
    }
    foreach ($marker in @(
        "pnpm licenses list --json --long",
        "cargo metadata",
        "dotnet package list",
        "deniedPattern",
        "NOASSERTION"
    )) {
        if (-not $licences.Contains($marker)) {
            $issues.Add("Missing licence-report invariant: $marker")
        }
    }

    foreach ($scriptName in @(
        "ci:check",
        "ci:backend",
        "supply-chain:report",
        "performance:test",
        "performance:check:build",
        "data-policy:check",
        "authority:check",
        "maintenance:check"
    )) {
        if ($null -eq $package.scripts.PSObject.Properties[$scriptName]) {
            $issues.Add("Missing package script: $scriptName")
        }
    }

    return $issues
}

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$repositoryIssues = @(Get-CiIssues -Root $repositoryRoot)
if ($repositoryIssues.Count -gt 0) {
    $repositoryIssues | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    exit 1
}

$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    "thrustline-t0013-" + [Guid]::NewGuid().ToString("N")
)
try {
    foreach ($relativePath in @(
        ".github/workflows/ci.yml",
        ".github/workflows/security.yml",
        "package.json",
        "scripts/ci/test-backend.ps1",
        "scripts/ci/write-license-report.ps1"
    )) {
        $destination = Join-Path $temporaryRoot $relativePath
        New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
        Copy-Item -LiteralPath (Join-Path $repositoryRoot $relativePath) -Destination $destination
    }

    $ciCopy = Join-Path $temporaryRoot ".github/workflows/ci.yml"
    $ciText = Get-Content -Raw -Encoding UTF8 $ciCopy
    $ciText = [regex]::Replace(
        $ciText,
        "actions/checkout@[0-9a-f]{40}",
        "actions/checkout@v7",
        1
    )
    [System.IO.File]::WriteAllText($ciCopy, $ciText)
    $mutableActionIssues = @(Get-CiIssues -Root $temporaryRoot)
    if (-not ($mutableActionIssues -match "full SHA")) {
        throw "Harness self-test failed to detect a mutable action reference."
    }

    Copy-Item -Force `
        -LiteralPath (Join-Path $repositoryRoot ".github/workflows/ci.yml") `
        -Destination $ciCopy
    $securityCopy = Join-Path $temporaryRoot ".github/workflows/security.yml"
    $securityText = Get-Content -Raw -Encoding UTF8 $securityCopy
    $securityText = $securityText.Replace("contents: read", "contents: write")
    [System.IO.File]::WriteAllText($securityCopy, $securityText)
    $writePermissionIssues = @(Get-CiIssues -Root $temporaryRoot)
    if (-not ($writePermissionIssues -match "contents: read only") -or
        -not ($writePermissionIssues -match "write permissions")) {
        throw "Harness self-test failed to detect a write permission."
    }
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}

Write-Output "T0013 CI checks passed (repository plus 2 mutation scenarios)."
