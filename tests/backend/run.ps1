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
    $lifecycleMigrationPath = Join-Path $Root "supabase\migrations\20260731000100_account_lifecycle.sql"
    $restoreMigrationPath = Join-Path $Root "supabase\migrations\20260731000200_account_deletion_restore_replay.sql"
    $ledgerMigrationPath = Join-Path $Root "supabase\migrations\20260731000300_immutable_financial_ledger.sql"
    $seedPath = Join-Path $Root "supabase\seed.sql"
    $structureTestPath = Join-Path $Root "supabase\tests\database\companies_structure.test.sql"
    $rlsTestPath = Join-Path $Root "supabase\tests\database\companies_rls.test.sql"
    $lifecycleStructureTestPath = Join-Path $Root "supabase\tests\database\account_lifecycle_structure.test.sql"
    $lifecycleTestPath = Join-Path $Root "supabase\tests\database\account_lifecycle.test.sql"
    $restoreStructureTestPath = Join-Path $Root "supabase\tests\database\account_restore_replay_structure.test.sql"
    $restoreTestPath = Join-Path $Root "supabase\tests\database\account_restore_replay.test.sql"
    $ledgerStructureTestPath = Join-Path $Root "supabase\tests\database\financial_ledger_structure.test.sql"
    $ledgerTestPath = Join-Path $Root "supabase\tests\database\financial_ledger.test.sql"
    $typesPath = Join-Path $Root "packages\database\src\database.types.ts"
    $startScriptPath = Join-Path $Root "scripts\start-supabase-local.ps1"
    $invokeScriptPath = Join-Path $Root "scripts\invoke-supabase-local.ps1"
    $dockerToolsPath = Join-Path $Root "scripts\docker-tools.ps1"
    $runtimeScriptPath = Join-Path $Root "scripts\supabase-local-runtime.ps1"
    $cliContainerfilePath = Join-Path $Root "scripts\supabase-local-cli.Containerfile"
    $typeScriptPath = Join-Path $Root "scripts\generate-database-types.ps1"
    $ciBackendPath = Join-Path $Root "scripts\ci\test-backend.ps1"

    $requiredPaths = @(
        $packagePath,
        $configPath,
        $migrationPath,
        $lifecycleMigrationPath,
        $restoreMigrationPath,
        $ledgerMigrationPath,
        $seedPath,
        $structureTestPath,
        $rlsTestPath,
        $lifecycleStructureTestPath,
        $lifecycleTestPath,
        $restoreStructureTestPath,
        $restoreTestPath,
        $ledgerStructureTestPath,
        $ledgerTestPath,
        $typesPath,
        $startScriptPath,
        $invokeScriptPath,
        $dockerToolsPath,
        $runtimeScriptPath,
        $cliContainerfilePath,
        $typeScriptPath,
        $ciBackendPath
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
    Require-Text $invokeScript '@\("test", "db"\)' "pgTAP does not let Supabase select its generated inner network."
    if ([string]$package.scripts.'backend:start' -notmatch "start-supabase-local\.ps1") {
        $issues.Add("backend:start must use the loopback-safe start script.")
    }

    $startScript = Get-Content -Raw -Encoding UTF8 $startScriptPath
    $dockerTools = Get-Content -Raw -Encoding UTF8 $dockerToolsPath
    $runtimeScript = Get-Content -Raw -Encoding UTF8 $runtimeScriptPath
    $cliContainerfile = Get-Content -Raw -Encoding UTF8 $cliContainerfilePath
    $typeScript = Get-Content -Raw -Encoding UTF8 $typeScriptPath
    Require-Text $dockerTools 'Get-Command docker\.exe -CommandType Application -All' "Docker must resolve to an application."
    Require-Text $dockerTools 'Select-Object -First 1' "Docker resolution must select exactly one executable."
    Require-Text $dockerTools 'Enable-DockerCliForProcess' "Docker CLI directory is not injected into child PATH."
    Require-Text $startScript 'docker-tools\.ps1' "Supabase start must use the shared Docker resolver."
    Require-Text $startScript 'supabase-local-runtime\.ps1' "Supabase start must use the isolated runtime helper."
    Require-Text $startScript '\$dockerPath info --format' "Docker daemon availability is not checked."
    Require-Text $startScript '--privileged' "The dedicated Docker-in-Docker engine is not started explicitly."
    foreach ($port in @(54321, 54322, 54323)) {
        Require-Text $startScript ('--publish "127\.0\.0\.1:{0}:{0}"' -f $port) "Supabase port $port is not restricted to IPv4 loopback."
    }
    Require-Text $startScript 'Copy-SupabaseProjectToEngine' "Supabase sources are not copied through the bounded staging helper."
    Require-Text $startScript 'Assert-SupabaseOuterBindings' "Supabase outer bindings are not verified after startup."
    Require-Text $startScript 'Remove-SupabaseLocalRuntime' "Failed startup does not remove the isolated runtime."
    Require-Text $runtimeScript 'docker:29\.6\.2-dind@sha256:[0-9a-f]{64}' "Docker-in-Docker is not pinned by version and digest."
    Require-Text $runtimeScript 'DOCKER_HOST=tcp://\$\(\$script:SupabaseEngineContainer\):2375' "The CLI does not target the isolated Docker API."
    Require-Text $runtimeScript 'DO_NOT_TRACK=1' "The isolated CLI does not disable generic telemetry."
    Require-Text $runtimeScript 'SUPABASE_TELEMETRY_DISABLED=1' "The isolated CLI does not disable Supabase telemetry."
    Require-Text $runtimeScript ([regex]::Escape('${script:SupabaseProjectVolume}:/workspace')) "The CLI does not use the dedicated project volume."
    Require-Text $startScript ([regex]::Escape('${script:SupabaseEngineCacheVolume}:/var/lib/docker')) "The inner image cache is not isolated in its dedicated volume."
    Require-Text $invokeScript 'Remove-SupabaseLocalRuntime -DockerPath \$dockerPath -PreserveImageCache' "Normal shutdown does not preserve only the source-free image cache."
    Require-Text $runtimeScript 'HostIp -ne "127\.0\.0\.1"' "The runtime does not reject non-loopback host bindings."
    Require-Text $runtimeScript '0\\\.0\\\.0\\\.0:|\\\\\[::\\\\\]:' "Published wildcard ports are not detected."
    Require-Text $runtimeScript 'Refusing to copy secret-capable files' "Secret-capable Supabase files are not rejected."
    Require-Text $runtimeScript 'Select-Object -Last 20' "Failed CLI output is not bounded before reporting."
    Require-Text $cliContainerfile 'node:24\.18\.0-bookworm-slim@sha256:[0-9a-f]{64}' "The CLI base image is not pinned by version and digest."
    Require-Text $cliContainerfile ([regex]::Escape('svFmamF/vIq4/oinwY50jDi869itC9/GWrPaGtsHFkK4NUBcQtl1T37WWIivGsXwbBKNC4FjZD3dGqjL7bfW1g==')) "The Linux CLI archive is not checked against the lockfile integrity."
    if (($startScript + $runtimeScript + $cliContainerfile) -match 'docker\.sock|\\\\\.\\pipe\\docker_engine') {
        $issues.Add("The isolated runtime must never mount the host Docker socket.")
    }
    if (($startScript + $invokeScript + $typeScript) -match '--network-id') {
        $issues.Add("The outer isolation must not force a stale inner Supabase network.")
    }

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

    $lifecycleMigration = Get-Content -Raw -Encoding UTF8 $lifecycleMigrationPath
    $lifecycleRequirements = @{
        "private schema" = 'create schema if not exists private'
        "deletion requests" = 'create table private\.account_deletion_requests'
        "idempotency ledger" = 'create table private\.account_lifecycle_commands'
        "non-personal markers" = 'create table private\.account_deletion_markers'
        "seven-day window" = "interval '7 days'"
        "forced private RLS" = 'alter table private\.account_deletion_requests force row level security'
        "no API table grants" = 'revoke all on all tables in schema private from authenticated'
        "session correlation" = 'from auth\.sessions as sessions'
        "five-minute freshness" = "interval '5 minutes'"
        "AMR validation" = "claims -> 'amr'"
        "mutation gate" = 'private\.account_is_active\(owner_id\)'
        "request command" = 'create function public\.request_account_deletion\(idempotency_key uuid\)'
        "export recovery" = 'create function public\.get_account_export\(request_id uuid\)'
        "cancel command" = 'create function public\.cancel_account_deletion\('
        "server finalization" = 'create function public\.finalize_account_deletion\(request_id uuid\)'
        "empty search path" = "set search_path = ''"
        "SHA-256 export" = "'sha256'"
        "Auth deletion" = 'delete from auth\.users'
        "service-only finalizer" = 'grant execute on function public\.finalize_account_deletion\(uuid\) to service_role'
        "authenticated finalizer revoked" = 'revoke all on function public\.finalize_account_deletion\(uuid\) from authenticated'
    }
    foreach ($entry in $lifecycleRequirements.GetEnumerator()) {
        Require-Text $lifecycleMigration $entry.Value "Account lifecycle invariant missing: $($entry.Key)."
    }
    if ($lifecycleMigration -match '(?i)grant\s+execute\s+on\s+function\s+public\.finalize_account_deletion\(uuid\)\s+to\s+(anon|authenticated)') {
        $issues.Add("Account finalization must remain service-role-only.")
    }

    $restoreMigration = Get-Content -Raw -Encoding UTF8 $restoreMigrationPath
    $restoreRequirements = @{
        "private restoration subjects" = 'create table private\.account_restoration_subjects'
        "private replay events" = 'create table private\.account_deletion_replay_events'
        "opaque subject token" = 'subject_token uuid primary key default gen_random_uuid\(\)'
        "existing company backfill" = 'from public\.companies as companies'
        "future company trigger" = 'create trigger companies_create_restoration_subject'
        "forced subject RLS" = 'alter table private\.account_restoration_subjects force row level security'
        "forced event RLS" = 'alter table private\.account_deletion_replay_events force row level security'
        "atomic source event" = 'insert into private\.account_deletion_replay_events'
        "replay command" = 'create function public\.replay_account_deletion_event\('
        "service-only replay" = 'to service_role'
        "conflict rejection" = 'Deletion replay event conflicts with the recorded event'
        "unknown event rejection" = 'Deletion replay event does not match the restored backup'
        "empty search path" = "set search_path = ''"
    }
    foreach ($entry in $restoreRequirements.GetEnumerator()) {
        Require-Text $restoreMigration $entry.Value "Restore replay invariant missing: $($entry.Key)."
    }
    if ($restoreMigration -match '(?is)grant\s+execute\s+on\s+function\s+public\.replay_account_deletion_event\(.*?\)\s+to\s+(anon|authenticated)') {
        $issues.Add("Deletion replay must remain service-role-only.")
    }

    $ledgerMigration = Get-Content -Raw -Encoding UTF8 $ledgerMigrationPath
    $ledgerRequirements = @{
        "private ledger subjects" = 'create table private\.financial_ledger_subjects'
        "private ledger entries" = 'create table private\.financial_ledger_entries'
        "forced subject RLS" = 'alter table private\.financial_ledger_subjects force row level security'
        "forced entry RLS" = 'alter table private\.financial_ledger_entries force row level security'
        "opaque entry identity" = 'subject_id uuid not null references private\.financial_ledger_subjects'
        "no direct client grants" = 'revoke all on table private\.financial_ledger_entries from authenticated'
        "append-only update delete trigger" = 'before update or delete on private\.financial_ledger_entries'
        "append-only truncate trigger" = 'before truncate on private\.financial_ledger_entries'
        "company anonymization trigger" = 'create trigger companies_anonymize_financial_ledger_subject'
        "server posting command" = 'create function public\.post_company_opening_balance\('
        "service-only posting" = 'grant execute on function public\.post_company_opening_balance\(uuid, uuid, bigint, text\) to service_role'
        "owner read command" = 'create function public\.get_company_ledger\(\)'
        "anonymous read revoked" = 'revoke all on function public\.get_company_ledger\(\) from anon'
        "deletion pending gate" = 'private\.account_is_active\(company\.owner_id\)'
        "empty search path" = "set search_path = ''"
    }
    foreach ($entry in $ledgerRequirements.GetEnumerator()) {
        Require-Text $ledgerMigration $entry.Value "Financial ledger invariant missing: $($entry.Key)."
    }
    if ($ledgerMigration -match '(?i)grant\s+execute\s+on\s+function\s+public\.post_company_opening_balance\([^;]+\)\s+to\s+(anon|authenticated)') {
        $issues.Add("Financial posting must remain service-role-only.")
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
        (Get-Content -Raw -Encoding UTF8 $rlsTestPath) +
        "`n" +
        (Get-Content -Raw -Encoding UTF8 $lifecycleStructureTestPath) +
        "`n" +
        (Get-Content -Raw -Encoding UTF8 $lifecycleTestPath) +
        "`n" +
        (Get-Content -Raw -Encoding UTF8 $restoreStructureTestPath) +
        "`n" +
        (Get-Content -Raw -Encoding UTF8 $restoreTestPath) +
        "`n" +
        (Get-Content -Raw -Encoding UTF8 $ledgerStructureTestPath) +
        "`n" +
        (Get-Content -Raw -Encoding UTF8 $ledgerTestPath)
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
        "B cannot recover A export",
        "a session older than five minutes is rejected",
        "a token refresh is not accepted as reauthentication",
        "an injected finalization failure rolls back the command",
        "finalization replay returns the same non-personal marker",
        "authenticated cannot invoke deletion replay",
        "replay preserves the unrelated owner B",
        "an altered replay event is rejected",
        "an unknown replay subject fails closed",
        "an injected replay failure rolls back the transaction",
        "authenticated cannot post an opening balance",
        "an identical command replays idempotently",
        "idempotency payload collision is rejected",
        "A can read only company A ledger",
        "B can read only company B ledger",
        "anonymous cannot read a company ledger",
        "deletion pending blocks financial mutation",
        "deletion replay detaches and dates the personal ledger link",
        "ledger entries cannot be updated",
        "rollback;"
    )) {
        if (-not $allTests.Contains($marker)) {
            $issues.Add("Missing RLS test scenario: $marker")
        }
    }

    $types = Get-Content -Raw -Encoding UTF8 $typesPath
    Require-Text $types 'companies:' "Generated types do not expose companies."
    Require-Text $types 'owner_id: string' "Generated types do not expose owner_id."
    Require-Text $types 'request_account_deletion:' "Generated types do not expose the deletion request command."
    Require-Text $types 'get_account_export:' "Generated types do not expose export recovery."
    Require-Text $types 'cancel_account_deletion:' "Generated types do not expose deletion cancellation."
    Require-Text $types 'finalize_account_deletion:' "Generated types do not expose server finalization."
    Require-Text $types 'replay_account_deletion_event:' "Generated types do not expose deletion replay."
    Require-Text $types 'post_company_opening_balance:' "Generated types do not expose the server ledger command."
    Require-Text $types 'get_company_ledger:' "Generated types do not expose owner ledger reads."

    $typeScript = Get-Content -Raw -Encoding UTF8 $typeScriptPath
    Require-Text $typeScript 'Invoke-IsolatedSupabaseCli' "Type generation does not use the isolated local runtime."
    Require-Text $typeScript '"--local"' "Type generation does not target the local database explicitly."

    $ciBackend = Get-Content -Raw -Encoding UTF8 $ciBackendPath
    Require-Text $ciBackend 'Start-Job -ScriptBlock' "Backend CI does not create concurrent database sessions."
    Require-Text $ciBackend 'select pg_sleep\(4\)' "Backend CI does not hold the first transaction for concurrency."
    Require-Text $ciBackend '"1\|2\|1"' "Backend CI does not verify one request and two idempotency records."
    Require-Text $ciBackend 'Account lifecycle concurrency passed' "Backend CI does not report the concurrency proof."
    Require-Text $ciBackend 'Financial ledger concurrency passed' "Backend CI does not report ledger concurrency."
    Require-Text $ciBackend 'Concurrent financial ledger commands did not converge' "Backend CI does not verify identical ledger command convergence."
    Require-Text $ciBackend '"1\|1"' "Backend CI does not verify one immutable concurrent ledger entry."
    Require-Text $ciBackend 'pg_dump' "Backend CI does not create a real PostgreSQL backup."
    foreach ($schema in @("auth", "public", "private", "extensions", "supabase_migrations")) {
        Require-Text $ciBackend "--schema $schema" "Backend CI backup scope is missing schema: $schema."
    }
    if ($ciBackend -match '--no-privileges') {
        $issues.Add("Backend CI restore must preserve database grants.")
    }
    Require-Text $ciBackend "grep -v ' DEFAULT ACL '" "Backend CI does not narrowly exclude role-owned default ACL entries."
    Require-Text $ciBackend '--use-list \$restoreFilteredListPath' "Backend CI does not restore from the reviewed archive list."
    Require-Text $ciBackend 'pg_restore' "Backend CI does not restore into an isolated PostgreSQL database."
    Require-Text $ciBackend 'create extension if not exists pgcrypto with schema extensions' "Backend CI does not reinstall pgcrypto after logical restore."
    Require-Text $ciBackend 'Restored pgcrypto extension version differs from the source' "Backend CI does not compare source and restored pgcrypto versions."
    Require-Text $ciBackend 'drop schema public cascade' "Backend CI does not remove the empty target public schema before restore."
    Require-Text $ciBackend '\\copy' "Backend CI does not export the replay journal through the unprivileged psql client."
    Require-Text $ciBackend 'replay_account_deletion_event' "Backend CI does not replay deletion events."
    Require-Text $ciBackend 'Isolated restore replay passed' "Backend CI does not report the restore replay proof."
    Require-Text $ciBackend 'dropdb.+--if-exists' "Backend CI does not guarantee restored database cleanup."

    return $issues
}

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$repositoryIssues = @(Get-BackendIssues -Root $repositoryRoot)
if ($repositoryIssues.Count -gt 0) {
    $repositoryIssues | ForEach-Object { Write-Error $_ }
    exit 1
}

$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    "thrustline-backend-" + [Guid]::NewGuid().ToString("N")
)
try {
    New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
    foreach ($relativePath in @(
        "package.json",
        "supabase\config.toml",
        "supabase\migrations\20260728000100_create_companies.sql",
        "supabase\migrations\20260731000100_account_lifecycle.sql",
        "supabase\migrations\20260731000200_account_deletion_restore_replay.sql",
        "supabase\migrations\20260731000300_immutable_financial_ledger.sql",
        "supabase\seed.sql",
        "supabase\tests\database\companies_structure.test.sql",
        "supabase\tests\database\companies_rls.test.sql",
        "supabase\tests\database\account_lifecycle_structure.test.sql",
        "supabase\tests\database\account_lifecycle.test.sql",
        "supabase\tests\database\account_restore_replay_structure.test.sql",
        "supabase\tests\database\account_restore_replay.test.sql",
        "supabase\tests\database\financial_ledger_structure.test.sql",
        "supabase\tests\database\financial_ledger.test.sql",
        "packages\database\src\database.types.ts",
        "scripts\start-supabase-local.ps1",
        "scripts\invoke-supabase-local.ps1",
        "scripts\docker-tools.ps1",
        "scripts\supabase-local-runtime.ps1",
        "scripts\supabase-local-cli.Containerfile",
        "scripts\generate-database-types.ps1",
        "scripts\ci\test-backend.ps1"
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

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "scripts\invoke-supabase-local.ps1") -Destination $invokeCopy
    $startCopy = Join-Path $temporaryRoot "scripts\start-supabase-local.ps1"
    $startText = Get-Content -Raw -Encoding UTF8 $startCopy
    $startText = $startText.Replace(
        '--publish "127.0.0.1:54321:54321"',
        '--publish "0.0.0.0:54321:54321"'
    )
    [System.IO.File]::WriteAllText($startCopy, $startText)
    $wildcardBindingIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($wildcardBindingIssues -match "port 54321 is not restricted")) {
        Write-Error "Harness self-test failed to detect a wildcard outer binding."
        exit 1
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "scripts\start-supabase-local.ps1") -Destination $startCopy
    $runtimeCopy = Join-Path $temporaryRoot "scripts\supabase-local-runtime.ps1"
    $runtimeText = Get-Content -Raw -Encoding UTF8 $runtimeCopy
    $runtimeText = $runtimeText.Replace(
        '"${script:SupabaseProjectVolume}:/workspace"',
        '"/var/run/docker.sock:/var/run/docker.sock"'
    )
    [System.IO.File]::WriteAllText($runtimeCopy, $runtimeText)
    $hostSocketIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($hostSocketIssues -match "must never mount the host Docker socket")) {
        Write-Error "Harness self-test failed to detect a host Docker socket mount."
        exit 1
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "scripts\supabase-local-runtime.ps1") -Destination $runtimeCopy

    $lifecycleMigrationCopy = Join-Path $temporaryRoot "supabase\migrations\20260731000100_account_lifecycle.sql"
    $lifecycleText = Get-Content -Raw -Encoding UTF8 $lifecycleMigrationCopy
    $lifecycleText = $lifecycleText.Replace(
        "grant execute on function public.finalize_account_deletion(uuid) to service_role;",
        "grant execute on function public.finalize_account_deletion(uuid) to authenticated;"
    )
    [System.IO.File]::WriteAllText($lifecycleMigrationCopy, $lifecycleText)
    $unsafeFinalizerIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($unsafeFinalizerIssues -match "service-role-only") -or
        -not ($unsafeFinalizerIssues -match "service-only finalizer")) {
        Write-Error "Harness self-test failed to detect a client-executable finalizer."
        exit 1
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "supabase\migrations\20260731000100_account_lifecycle.sql") -Destination $lifecycleMigrationCopy
    $restoreMigrationCopy = Join-Path $temporaryRoot "supabase\migrations\20260731000200_account_deletion_restore_replay.sql"
    $restoreText = Get-Content -Raw -Encoding UTF8 $restoreMigrationCopy
    $restoreText = $restoreText.Replace(
        ") to service_role;",
        ") to authenticated;"
    )
    [System.IO.File]::WriteAllText($restoreMigrationCopy, $restoreText)
    $unsafeReplayIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($unsafeReplayIssues -match "service-role-only") -or
        -not ($unsafeReplayIssues -match "service-only replay")) {
        Write-Error "Harness self-test failed to detect a client-executable restore replay."
        exit 1
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "supabase\migrations\20260731000200_account_deletion_restore_replay.sql") -Destination $restoreMigrationCopy
    $ledgerMigrationCopy = Join-Path $temporaryRoot "supabase\migrations\20260731000300_immutable_financial_ledger.sql"
    $ledgerText = Get-Content -Raw -Encoding UTF8 $ledgerMigrationCopy
    $ledgerText = $ledgerText.Replace(
        "grant execute on function public.post_company_opening_balance(uuid, uuid, bigint, text) to service_role;",
        "grant execute on function public.post_company_opening_balance(uuid, uuid, bigint, text) to authenticated;"
    )
    [System.IO.File]::WriteAllText($ledgerMigrationCopy, $ledgerText)
    $unsafeLedgerIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($unsafeLedgerIssues -match "service-role-only") -or
        -not ($unsafeLedgerIssues -match "service-only posting")) {
        Write-Error "Harness self-test failed to detect a client-executable ledger command."
        exit 1
    }
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}

Write-Output "Backend checks passed (T0012-T0021 repository plus 7 mutation scenarios)."
