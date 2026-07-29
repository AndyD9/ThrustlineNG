[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-BackendIssues {
    param(
        [Parameter(Mandatory)]
        [string]$Root
    )

    $issues = [System.Collections.Generic.List[string]]::new()

    function Require-Text {
        param(
            [string]$Text,
            [string]$Pattern,
            [string]$Message
        )

        if ($Text -notmatch $Pattern) {
            $issues.Add($Message)
        }
    }

    $packagePath = Join-Path $Root "package.json"
    $configPath = Join-Path $Root "supabase\config.toml"
    $migrationPath = Join-Path $Root "supabase\migrations\20260728000100_create_companies.sql"
    $seedPath = Join-Path $Root "supabase\seed.sql"
    $structureTestPath = Join-Path $Root "supabase\tests\database\companies_structure.test.sql"
    $rlsTestPath = Join-Path $Root "supabase\tests\database\companies_rls.test.sql"
    $typesPath = Join-Path $Root "packages\database\src\database.types.ts"
    $startScriptPath = Join-Path $Root "scripts\start-supabase-local.ps1"
    $invokeScriptPath = Join-Path $Root "scripts\invoke-supabase-local.ps1"
    $dockerToolsPath = Join-Path $Root "scripts\docker-tools.ps1"
    $typeScriptPath = Join-Path $Root "scripts\generate-database-types.ps1"

    $requiredPaths = @(
        $packagePath,
        $configPath,
        $migrationPath,
        $seedPath,
        $structureTestPath,
        $rlsTestPath,
        $typesPath,
        $startScriptPath,
        $invokeScriptPath,
        $dockerToolsPath,
        $typeScriptPath
    )
    foreach ($path in $requiredPaths) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $issues.Add("Missing required backend file: $([System.IO.Path]::GetFileName($path))")
        }
    }
    if ($issues.Count -gt 0) {
        return $issues
    }

    $package = Get-Content -Raw -Encoding UTF8 $packagePath | ConvertFrom-Json
    if ($package.devDependencies.supabase -ne "2.109.1") {
        $issues.Add("Supabase CLI must be pinned exactly to 2.109.1.")
    }

    $backendScripts = $package.scripts.PSObject.Properties |
        Where-Object Name -Like "backend:*"
    $requiredScripts = @(
        "backend:check",
        "backend:start",
        "backend:stop",
        "backend:reset",
        "backend:test",
        "backend:types",
        "backend:types:check"
    )
    foreach ($name in $requiredScripts) {
        if ($name -notin $backendScripts.Name) {
            $issues.Add("Missing package script: $name")
        }
    }

    $invokeScript = Get-Content -Raw -Encoding UTF8 $invokeScriptPath
    $commandSurface = (
        @($backendScripts | ForEach-Object { [string]$_.Value }) +
        @($invokeScript)
    ) -join "`n"
    if ($commandSurface -match "(^|\s)(link|projects)(\s|$)|db\s+(push|pull|dump)|--linked|--db-url") {
        $issues.Add("Backend command surface contains a remote-capable command.")
    }

    if ([string]$package.scripts.'backend:reset' -notmatch "invoke-supabase-local\.ps1 -Action Reset" -or
        $invokeScript -notmatch '@\("db", "reset", "--local"\)') {
        $issues.Add("backend:reset must target the local database explicitly.")
    }
    Require-Text $invokeScript '@\("test", "db", "--network-id", "thrustline-local"\)' "pgTAP does not use the local Docker network."
    if ([string]$package.scripts.'backend:start' -notmatch "start-supabase-local\.ps1") {
        $issues.Add("backend:start must use the loopback-safe start script.")
    }

    $startScript = Get-Content -Raw -Encoding UTF8 $startScriptPath
    $dockerTools = Get-Content -Raw -Encoding UTF8 $dockerToolsPath
    Require-Text $dockerTools 'Get-Command docker\.exe -CommandType Application -All' "Docker must resolve to an application."
    Require-Text $dockerTools 'Select-Object -First 1' "Docker resolution must select exactly one executable."
    Require-Text $dockerTools 'Enable-DockerCliForProcess' "Docker CLI directory is not injected into child PATH."
    Require-Text $startScript 'docker-tools\.ps1' "Supabase start must use the shared Docker resolver."
    Require-Text $startScript '\$dockerPath info --format' "Docker daemon availability is not checked."
    Require-Text $startScript 'host_binding_ipv4=127\.0\.0\.1' "Docker ports are not restricted to loopback."
    Require-Text $startScript '--network-id \$networkName' "Supabase does not use the restricted Docker network."
    Require-Text $startScript '\$dockerPath network ls --format' "Docker networks must be listed before inspection."
    Require-Text $startScript '\$networkName -notin \$networkNames' "Missing Docker networks are not handled safely."
    Require-Text $startScript '\$networkInspection \| ConvertFrom-Json' "Docker network inspection must parse JSON."
    Require-Text $startScript '\$networkBinding -ne "127\.0\.0\.1"' "An unsafe existing Docker network is not rejected."
    Require-Text $startScript '\*> \$null' "Supabase start output may expose local credentials."
    Require-Text $startScript "0\\\.0\\\.0\\\.0:|\\\\\[::\\\\\]:" "Published wildcard ports are not detected."
    Require-Text $startScript 'Stop-LocalStackQuietly' "Fail-safe shutdown does not isolate CLI stderr."
    Require-Text $startScript 'the local stack was stopped' "Unsafe bindings do not stop the local stack."

    $config = Get-Content -Raw -Encoding UTF8 $configPath
    Require-Text $config '(?m)^project_id = "thrustline-ng"$' "Unexpected Supabase project ID."
    Require-Text $config '(?m)^major_version = 17$' "PostgreSQL major version must be 17."
    Require-Text $config '(?s)\[db\.migrations\].*?enabled = true' "Migrations must be enabled."
    Require-Text $config '(?s)\[db\.seed\].*?enabled = true.*?sql_paths = \["\./seed\.sql"\]' "Seed ordering is not explicit."
    Require-Text $config '(?s)\[realtime\].*?enabled = false' "Realtime must remain disabled in T0012."
    Require-Text $config '(?s)\[storage\].*?enabled = false' "Storage must remain disabled in T0012."
    Require-Text $config '(?s)\[edge_runtime\].*?enabled = false' "Edge Runtime must remain disabled in T0012."

    $migration = Get-Content -Raw -Encoding UTF8 $migrationPath
    $migrationRequirements = @{
        "companies table" = 'create table public\.companies'
        "Auth owner FK" = 'owner_id uuid not null references auth\.users \(id\)'
        "one-company constraint" = 'constraint companies_one_per_owner unique \(owner_id\)'
        "RLS enabled" = 'alter table public\.companies enable row level security'
        "RLS forced" = 'alter table public\.companies force row level security'
        "anonymous revoked" = 'revoke all on table public\.companies from anon'
        "authenticated grants" = 'grant select, insert, update, delete on table public\.companies to authenticated'
        "select policy" = 'create policy companies_select_own'
        "insert policy" = 'create policy companies_insert_own'
        "update policy" = 'create policy companies_update_own'
        "delete policy" = 'create policy companies_delete_own'
        "authenticated policy roles" = 'to authenticated'
        "owner predicate" = '\(select auth\.uid\(\)\) = owner_id'
    }
    foreach ($entry in $migrationRequirements.GetEnumerator()) {
        Require-Text $migration $entry.Value "Migration invariant missing: $($entry.Key)."
    }
    if ($migration -match '(?i)to\s+(public|anon|service_role)') {
        $issues.Add("A company policy grants an unintended role.")
    }

    $seed = Get-Content -Raw -Encoding UTF8 $seedPath
    Require-Text $seed 'pilot-a@thrustline\.invalid' "Synthetic user A is missing."
    Require-Text $seed 'pilot-b@thrustline\.invalid' "Synthetic user B is missing."
    Require-Text $seed 'insert into public\.companies' "Synthetic companies are missing."
    if ($seed -match '(?i)@(gmail|outlook|hotmail|yahoo)\.' -or $seed -match '(?i)(password|secret|token)\s*=') {
        $issues.Add("Seed may contain a real identity or secret-like assignment.")
    }

    $allTests = (
        (Get-Content -Raw -Encoding UTF8 $structureTestPath) +
        "`n" +
        (Get-Content -Raw -Encoding UTF8 $rlsTestPath)
    )
    foreach ($marker in @(
        "set local role authenticated",
        "set local role anon",
        "A can read only company A",
        "B can read only company B",
        "A cannot update company B",
        "B cannot update company A",
        "anonymous cannot read companies",
        "anonymous cannot insert companies",
        "companies_one_per_owner",
        "rollback;"
    )) {
        if (-not $allTests.Contains($marker)) {
            $issues.Add("Missing RLS test scenario: $marker")
        }
    }

    $types = Get-Content -Raw -Encoding UTF8 $typesPath
    Require-Text $types 'companies:' "Generated types do not expose companies."
    Require-Text $types 'owner_id: string' "Generated types do not expose owner_id."

    $typeScript = Get-Content -Raw -Encoding UTF8 $typeScriptPath
    Require-Text $typeScript '--network-id thrustline-local' "Type generation does not use the local Docker network."

    return $issues
}

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$repositoryIssues = @(Get-BackendIssues -Root $repositoryRoot)
if ($repositoryIssues.Count -gt 0) {
    $repositoryIssues | ForEach-Object { Write-Error $_ }
    exit 1
}

$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    "thrustline-t0012-" + [Guid]::NewGuid().ToString("N")
)
try {
    New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
    foreach ($relativePath in @(
        "package.json",
        "supabase\config.toml",
        "supabase\migrations\20260728000100_create_companies.sql",
        "supabase\seed.sql",
        "supabase\tests\database\companies_structure.test.sql",
        "supabase\tests\database\companies_rls.test.sql",
        "packages\database\src\database.types.ts",
        "scripts\start-supabase-local.ps1",
        "scripts\invoke-supabase-local.ps1",
        "scripts\docker-tools.ps1",
        "scripts\generate-database-types.ps1"
    )) {
        $destination = Join-Path $temporaryRoot $relativePath
        New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
        Copy-Item -LiteralPath (Join-Path $repositoryRoot $relativePath) -Destination $destination
    }

    $migrationCopy = Join-Path $temporaryRoot "supabase\migrations\20260728000100_create_companies.sql"
    $migrationText = Get-Content -Raw -Encoding UTF8 $migrationCopy
    $migrationText = $migrationText.Replace("create policy companies_select_own", "create policy removed_select_policy")
    [System.IO.File]::WriteAllText($migrationCopy, $migrationText)
    $missingPolicyIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($missingPolicyIssues -match "select policy")) {
        Write-Error "Harness self-test failed to detect a missing RLS policy."
        exit 1
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "supabase\migrations\20260728000100_create_companies.sql") -Destination $migrationCopy
    $invokeCopy = Join-Path $temporaryRoot "scripts\invoke-supabase-local.ps1"
    $invokeText = Get-Content -Raw -Encoding UTF8 $invokeCopy
    $invokeText = $invokeText.Replace('@("db", "reset", "--local")', '@("db", "reset", "--linked")')
    [System.IO.File]::WriteAllText($invokeCopy, $invokeText)
    $remoteCommandIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($remoteCommandIssues -match "remote-capable") -or
        -not ($remoteCommandIssues -match "local database explicitly")) {
        Write-Error "Harness self-test failed to detect a remote reset command."
        exit 1
    }
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}

Write-Output "T0012 backend checks passed (repository plus 2 mutation scenarios)."
