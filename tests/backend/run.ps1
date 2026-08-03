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
    $economyPolicyPath = Join-Path $Root "eng\economy-policy.json"
    $configPath = Join-Path $Root "supabase\config.toml"
    $migrationPath = Join-Path $Root "supabase\migrations\20260728000100_create_companies.sql"
    $lifecycleMigrationPath = Join-Path $Root "supabase\migrations\20260731000100_account_lifecycle.sql"
    $restoreMigrationPath = Join-Path $Root "supabase\migrations\20260731000200_account_deletion_restore_replay.sql"
    $ledgerMigrationPath = Join-Path $Root "supabase\migrations\20260731000300_immutable_financial_ledger.sql"
    $onboardingMigrationPath = Join-Path $Root "supabase\migrations\20260731000400_authoritative_company_onboarding.sql"
    $purchaseMigrationPath = Join-Path $Root "supabase\migrations\20260802000100_authoritative_aircraft_purchase.sql"
    $dispatchMigrationPath = Join-Path $Root "supabase\migrations\20260803000100_authoritative_dispatch_draft.sql"
    $seedPath = Join-Path $Root "supabase\seed.sql"
    $structureTestPath = Join-Path $Root "supabase\tests\database\companies_structure.test.sql"
    $rlsTestPath = Join-Path $Root "supabase\tests\database\companies_rls.test.sql"
    $lifecycleStructureTestPath = Join-Path $Root "supabase\tests\database\account_lifecycle_structure.test.sql"
    $lifecycleTestPath = Join-Path $Root "supabase\tests\database\account_lifecycle.test.sql"
    $restoreStructureTestPath = Join-Path $Root "supabase\tests\database\account_restore_replay_structure.test.sql"
    $restoreTestPath = Join-Path $Root "supabase\tests\database\account_restore_replay.test.sql"
    $ledgerStructureTestPath = Join-Path $Root "supabase\tests\database\financial_ledger_structure.test.sql"
    $ledgerTestPath = Join-Path $Root "supabase\tests\database\financial_ledger.test.sql"
    $onboardingStructureTestPath = Join-Path $Root "supabase\tests\database\company_onboarding_structure.test.sql"
    $onboardingTestPath = Join-Path $Root "supabase\tests\database\company_onboarding.test.sql"
    $purchaseStructureTestPath = Join-Path $Root "supabase\tests\database\aircraft_purchase_structure.test.sql"
    $purchaseTestPath = Join-Path $Root "supabase\tests\database\aircraft_purchase.test.sql"
    $dispatchStructureTestPath = Join-Path $Root "supabase\tests\database\dispatch_draft_structure.test.sql"
    $dispatchTestPath = Join-Path $Root "supabase\tests\database\dispatch_draft.test.sql"
    $onboardingFunctionPath = Join-Path $Root "supabase\functions\company-onboarding\handler.ts"
    $onboardingFunctionPolicyPath = Join-Path $Root "supabase\functions\company-onboarding\economy-policy.json"
    $onboardingFunctionEntryPath = Join-Path $Root "supabase\functions\company-onboarding\index.ts"
    $onboardingFunctionTestPath = Join-Path $Root "supabase\functions\company-onboarding\handler.test.ts"
    $onboardingFunctionPackagePath = Join-Path $Root "supabase\functions\company-onboarding\package.json"
    $purchaseFunctionPath = Join-Path $Root "supabase\functions\aircraft-purchase\handler.ts"
    $purchaseFunctionEntryPath = Join-Path $Root "supabase\functions\aircraft-purchase\index.ts"
    $purchaseFunctionTestPath = Join-Path $Root "supabase\functions\aircraft-purchase\handler.test.ts"
    $purchaseFunctionPackagePath = Join-Path $Root "supabase\functions\aircraft-purchase\package.json"
    $dispatchFunctionPath = Join-Path $Root "supabase\functions\dispatch-draft\handler.ts"
    $dispatchFunctionEntryPath = Join-Path $Root "supabase\functions\dispatch-draft\index.ts"
    $dispatchFunctionTestPath = Join-Path $Root "supabase\functions\dispatch-draft\handler.test.ts"
    $dispatchFunctionPackagePath = Join-Path $Root "supabase\functions\dispatch-draft\package.json"
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
        $economyPolicyPath,
        $configPath,
        $migrationPath,
        $lifecycleMigrationPath,
        $restoreMigrationPath,
        $ledgerMigrationPath,
        $onboardingMigrationPath,
        $purchaseMigrationPath,
        $dispatchMigrationPath,
        $seedPath,
        $structureTestPath,
        $rlsTestPath,
        $lifecycleStructureTestPath,
        $lifecycleTestPath,
        $restoreStructureTestPath,
        $restoreTestPath,
        $ledgerStructureTestPath,
        $ledgerTestPath,
        $onboardingStructureTestPath,
        $onboardingTestPath,
        $purchaseStructureTestPath,
        $purchaseTestPath,
        $dispatchStructureTestPath,
        $dispatchTestPath,
        $onboardingFunctionPath,
        $onboardingFunctionPolicyPath,
        $onboardingFunctionEntryPath,
        $onboardingFunctionTestPath,
        $onboardingFunctionPackagePath,
        $purchaseFunctionPath,
        $purchaseFunctionEntryPath,
        $purchaseFunctionTestPath,
        $purchaseFunctionPackagePath,
        $dispatchFunctionPath,
        $dispatchFunctionEntryPath,
        $dispatchFunctionTestPath,
        $dispatchFunctionPackagePath,
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

    $economyPolicyText = Get-Content -Raw -Encoding UTF8 $economyPolicyPath
    $onboardingFunctionPolicyText = Get-Content -Raw -Encoding UTF8 $onboardingFunctionPolicyPath
    try {
        $economyPolicy = $economyPolicyText | ConvertFrom-Json
    }
    catch {
        $issues.Add("Economy policy must be valid JSON.")
        $economyPolicy = $null
    }
    if ($null -ne $economyPolicy) {
        $economyPolicyProperties = @($economyPolicy.PSObject.Properties.Name | Sort-Object)
        if (($economyPolicyProperties -join ",") -ne "currencyCode,openingAmountMinor,schemaVersion,scope" -or
            $economyPolicy.schemaVersion -ne 1 -or
            $economyPolicy.scope -ne "new-company-opening" -or
            $economyPolicy.openingAmountMinor -ne 43000000 -or
            $economyPolicy.currencyCode -cne "EUR") {
            $issues.Add("Economy policy must be schema v1 for a 43000000 EUR new-company opening.")
        }
    }
    if ($economyPolicyText -cne $onboardingFunctionPolicyText) {
        $issues.Add("Packaged company onboarding economy policy diverges from eng/economy-policy.json.")
    }

    $backendScripts = $package.scripts.PSObject.Properties |
        Where-Object Name -Like "backend:*"
    $requiredScripts = @(
        "backend:check",
        "backend:start",
        "backend:stop",
        "backend:reset",
        "backend:test",
        "backend:functions:test",
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
    Require-Text $invokeScript '@\("stop", "--project-id", \$script:SupabaseProjectId, "--no-backup"\)' "Local shutdown must not preserve database state in the image cache."
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
    if ($startScript -match '--exclude[^\r\n]+edge-runtime') {
        $issues.Add("The local start command must load the company onboarding Edge Function.")
    }
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
    $authSection = [regex]::Match($config, '(?ms)^\[auth\]\s*$(.*?)(?=^\[)')
    $authSignupValues = @(if ($authSection.Success) {
        [regex]::Matches($authSection.Groups[1].Value, '(?m)^enable_signup = (true|false)$') |
            ForEach-Object { $_.Groups[1].Value }
    })
    if ($authSignupValues.Count -ne 1 -or $authSignupValues[0] -ne "false") {
        $issues.Add("Public Auth signup must remain disabled by one unambiguous setting.")
    }
    $emailSection = [regex]::Match($config, '(?ms)^\[auth\.email\]\s*$(.*?)(?=^\[)')
    $emailSignupValues = @(if ($emailSection.Success) {
        [regex]::Matches($emailSection.Groups[1].Value, '(?m)^enable_signup = (true|false)$') |
            ForEach-Object { $_.Groups[1].Value }
    })
    if ($emailSignupValues.Count -ne 1 -or $emailSignupValues[0] -ne "true") {
        $issues.Add("Local email/password Auth must remain available for provisioned identities.")
    }
    $smtpSection = [regex]::Match($config, '(?ms)^\[local_smtp\]\s*$(.*?)(?=^\[)')
    $smtpEnabledValues = @(if ($smtpSection.Success) {
        [regex]::Matches($smtpSection.Groups[1].Value, '(?m)^enabled = (true|false)$') |
            ForEach-Object { $_.Groups[1].Value }
    })
    if ($smtpEnabledValues.Count -ne 1 -or $smtpEnabledValues[0] -ne "false") {
        $issues.Add("Local password Auth must not enable an SMTP surface.")
    }
    Require-Text $config '(?s)\[edge_runtime\].*?enabled = true' "Edge Runtime must be enabled for the T0023 server boundary."
    Require-Text $config '(?s)\[functions\.company-onboarding\].*?enabled = true' "Company onboarding function must be enabled explicitly."
    Require-Text $config '(?s)\[functions\.company-onboarding\].*?verify_jwt = true' "Company onboarding must retain the platform JWT gate."
    Require-Text $config '(?s)\[functions\.company-onboarding\].*?entrypoint = "\./functions/company-onboarding/index\.ts"' "Company onboarding entrypoint is not explicit."

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

    $onboardingMigration = Get-Content -Raw -Encoding UTF8 $onboardingMigrationPath
    $onboardingRequirements = @{
        "private onboarding registry" = 'create table private\.company_onboarding_commands'
        "forced onboarding RLS" = 'alter table private\.company_onboarding_commands force row level security'
        "owner-scoped idempotency" = 'primary key \(owner_id, idempotency_key\)'
        "payload fingerprint" = "extensions\.digest\("
        "authoritative onboarding command" = 'create function public\.create_company_with_opening_balance\('
        "service-only onboarding" = 'grant execute on function public\.create_company_with_opening_balance\(uuid, uuid, text, bigint, text\) to service_role'
        "client company mutation revoked" = 'revoke insert, update, delete on table public\.companies from authenticated'
        "client insert policy removed" = 'drop policy companies_insert_own on public\.companies'
        "client update policy removed" = 'drop policy companies_update_own on public\.companies'
        "client delete policy removed" = 'drop policy companies_delete_own on public\.companies'
        "Auth owner lock" = 'from auth\.users as users[\s\S]+for update'
        "anonymous owner rejection" = 'not coalesce\(users\.is_anonymous, false\)'
        "account lifecycle gate" = 'private\.account_is_active\(locked_owner_id\)'
        "atomic opening call" = 'public\.post_company_opening_balance\('
        "empty search path" = "set search_path = ''"
    }
    foreach ($entry in $onboardingRequirements.GetEnumerator()) {
        Require-Text $onboardingMigration $entry.Value "Company onboarding invariant missing: $($entry.Key)."
    }
    if ($onboardingMigration -match '(?i)grant\s+execute\s+on\s+function\s+public\.create_company_with_opening_balance\([^;]+\)\s+to\s+(anon|authenticated)') {
        $issues.Add("Company onboarding must remain service-role-only.")
    }
    if ($onboardingMigration -match '(?i)grant\s+(insert|update|delete)[^;]*on\s+(table\s+)?public\.companies\s+to\s+(anon|authenticated)') {
        $issues.Add("Client roles must not regain direct company mutation privileges.")
    }

    $purchaseMigration = Get-Content -Raw -Encoding UTF8 $purchaseMigrationPath
    $purchaseRequirements = @{
        "server offers" = 'create table public\.aircraft_purchase_offers'
        "company ownership" = 'create table public\.company_aircraft'
        "private purchase registry" = 'create table private\.aircraft_purchase_commands'
        "owner idempotency" = 'primary key \(owner_id, idempotency_key\)'
        "server price lookup" = 'from public\.aircraft_purchase_offers as offers[\s\S]+for update'
        "server seller" = "seller_kind text not null default 'system'"
        "company lock" = 'from public\.companies as companies[\s\S]+for update'
        "financial subject lock" = 'from private\.financial_ledger_subjects as subjects[\s\S]+for update'
        "derived balance" = 'coalesce\(sum\(entries\.amount_minor\), 0\)'
        "immutable purchase debit" = "'aircraft_purchase',[\s\S]+-offer\.price_minor"
        "service-only purchase" = 'grant execute on function public\.purchase_aircraft\(uuid, uuid, uuid\) to service_role'
        "owner aircraft read" = 'create function public\.get_company_aircraft\(\)'
        "forced offer RLS" = 'alter table public\.aircraft_purchase_offers force row level security'
        "forced aircraft RLS" = 'alter table public\.company_aircraft force row level security'
        "empty search path" = "set search_path = ''"
    }
    foreach ($entry in $purchaseRequirements.GetEnumerator()) {
        Require-Text $purchaseMigration $entry.Value "Aircraft purchase invariant missing: $($entry.Key)."
    }
    if ($purchaseMigration -match '(?i)grant\s+execute\s+on\s+function\s+public\.purchase_aircraft\([^;]+\)\s+to\s+(anon|authenticated)') {
        $issues.Add("Aircraft purchase must remain service-role-only.")
    }
    if ($purchaseMigration -match '(?i)grant\s+(insert|update|delete)[^;]*on\s+(table\s+)?public\.(aircraft_purchase_offers|company_aircraft)\s+to\s+(anon|authenticated)') {
        $issues.Add("Client roles must not gain direct offer or aircraft mutation privileges.")
    }

    $dispatchMigration = Get-Content -Raw -Encoding UTF8 $dispatchMigrationPath
    $dispatchRequirements = @{
        "dispatch drafts" = 'create table public\.flight_dispatches'
        "private dispatch registry" = 'create table private\.dispatch_draft_commands'
        "owner idempotency" = 'primary key \(owner_id, idempotency_key\)'
        "payload fingerprint" = 'extensions\.digest\('
        "company derivation" = 'where companies\.owner_id = create_dispatch_draft\.owner_id'
        "active account" = 'private\.account_is_active\(create_dispatch_draft\.owner_id\)'
        "owned aircraft lock" = 'from public\.company_aircraft as aircraft_rows[\s\S]+aircraft_rows\.company_id = company\.id[\s\S]+for update'
        "server draft state" = "state text not null default 'draft'"
        "server timestamp" = 'created_at timestamptz not null default clock_timestamp\(\)'
        "normalized ICAO" = 'normalized_departure := upper\(btrim\(departure_icao\)\)'
        "distinct airports" = 'normalized_departure = normalized_arrival'
        "one draft per aircraft" = 'constraint flight_dispatches_one_draft_per_aircraft unique \(aircraft_id\)'
        "forced dispatch RLS" = 'alter table public\.flight_dispatches force row level security'
        "service-only dispatch" = 'grant execute on function public\.create_dispatch_draft\(uuid, uuid, uuid, text, text\) to service_role'
        "empty search path" = "set search_path = ''"
    }
    foreach ($entry in $dispatchRequirements.GetEnumerator()) {
        Require-Text $dispatchMigration $entry.Value "Dispatch draft invariant missing: $($entry.Key)."
    }
    if ($dispatchMigration -match '(?i)grant\s+execute\s+on\s+function\s+public\.create_dispatch_draft\([^;]+\)\s+to\s+(anon|authenticated)') {
        $issues.Add("Dispatch creation must remain service-role-only.")
    }
    if ($dispatchMigration -match '(?i)grant\s+(insert|update|delete)[^;]*on\s+(table\s+)?public\.flight_dispatches\s+to\s+(anon|authenticated)') {
        $issues.Add("Client roles must not gain direct dispatch mutation privileges.")
    }
    if ($dispatchMigration -match '(?i)create_dispatch_draft\([^)]*(company_id|state|created_at)[^)]*\)') {
        $issues.Add("Dispatch creation must not accept client-controlled company, state or time.")
    }

    $onboardingFunction = Get-Content -Raw -Encoding UTF8 $onboardingFunctionPath
    $onboardingFunctionEntry = Get-Content -Raw -Encoding UTF8 $onboardingFunctionEntryPath
    $onboardingFunctionTests = Get-Content -Raw -Encoding UTF8 $onboardingFunctionTestPath
    $onboardingFunctionRequirements = @{
        "bounded request body" = 'MAX_BODY_BYTES = 4_096'
        "bounded upstream calls" = 'UPSTREAM_TIMEOUT_MILLISECONDS = 5_000'
        "strict client payload" = 'keys\.length !== 2'
        "Auth session verification" = '/auth/v1/user'
        "anonymous session rejection" = 'user\.is_anonymous !== false'
        "canonical economy import" = 'economy-policy\.json'
        "canonical economy validation" = 'readEconomyPolicy'
        "canonical opening amount" = 'openingAmountMinor: policy\.openingAmountMinor'
        "canonical currency" = 'currencyCode: policy\.currencyCode'
        "service-role RPC" = '/rest/v1/rpc/create_company_with_opening_balance'
        "owner derived from Auth" = 'owner_id: user\.id'
        "service credential header" = 'apikey: configuration\.serviceRoleKey'
        "redacted database failure" = 'onboarding_rejected'
        "non-cacheable response" = 'headers\.set\("cache-control", "no-store"\)'
    }
    foreach ($entry in $onboardingFunctionRequirements.GetEnumerator()) {
        Require-Text $onboardingFunction $entry.Value "Company onboarding endpoint invariant missing: $($entry.Key)."
    }
    if (($runtimeScript + $config + $onboardingFunction) -match 'COMPANY_OPENING_(BALANCE_MINOR|CURRENCY)') {
        $issues.Add("Company onboarding economy policy must not be replaceable through environment variables.")
    }
    Require-Text $onboardingFunctionEntry 'Deno\.serve\(createCompanyOnboardingHandler\(Deno\.env\.toObject\(\)\)\)' "Company onboarding handler is not registered with the Edge runtime."
    foreach ($marker in @(
        "rejects owner, amount, currency, and other client-controlled fields",
        "rejects invalid canonical economy policies",
        "ignores deployment attempts to override the canonical economy policy",
        "rejects an invalid or anonymous Auth session",
        "fails closed when Auth is unavailable",
        "derives the owner from Auth and keeps economic inputs server-side",
        "does not disclose database rejection details",
        "fails closed when the privileged RPC is unavailable",
        "fails closed on a malformed privileged response"
    )) {
        if (-not $onboardingFunctionTests.Contains($marker)) {
            $issues.Add("Missing company onboarding endpoint test scenario: $marker")
        }
    }

    $purchaseFunction = Get-Content -Raw -Encoding UTF8 $purchaseFunctionPath
    $purchaseFunctionEntry = Get-Content -Raw -Encoding UTF8 $purchaseFunctionEntryPath
    $purchaseFunctionTests = Get-Content -Raw -Encoding UTF8 $purchaseFunctionTestPath
    $purchaseFunctionRequirements = @{
        "bounded request body" = 'MAX_BODY_BYTES = 4_096'
        "bounded upstream calls" = 'UPSTREAM_TIMEOUT_MILLISECONDS = 5_000'
        "strict purchase payload" = 'keys\.length !== 2'
        "Auth session verification" = '/auth/v1/user'
        "anonymous session rejection" = 'user\.is_anonymous !== false'
        "service-role purchase RPC" = '/rest/v1/rpc/purchase_aircraft'
        "owner derived from Auth" = 'owner_id: user\.id'
        "service credential API key" = 'apikey: configuration\.serviceRoleKey'
        "service credential bearer" = 'authorization: `Bearer \$\{configuration\.serviceRoleKey\}`'
        "redacted purchase failure" = 'purchase_rejected'
        "allowlisted public response" = 'aircraftId: value\.aircraftId[\s\S]+ledgerEntryId: value\.ledgerEntryId[\s\S]+offerId: value\.offerId'
        "non-cacheable response" = 'headers\.set\("cache-control", "no-store"\)'
    }
    foreach ($entry in $purchaseFunctionRequirements.GetEnumerator()) {
        Require-Text $purchaseFunction $entry.Value "Aircraft purchase endpoint invariant missing: $($entry.Key)."
    }
    if ($purchaseFunction -match 'request\.(owner|company|price|currency)[A-Za-z]*') {
        $issues.Add("Aircraft purchase endpoint must not accept client-controlled owner, company, price or currency.")
    }
    Require-Text $config '\[functions\.aircraft-purchase\][\s\S]+verify_jwt = true[\s\S]+entrypoint = "\./functions/aircraft-purchase/index\.ts"' "Aircraft purchase Edge function must verify JWTs and register its entrypoint."
    Require-Text $purchaseFunctionEntry 'Deno\.serve\(createAircraftPurchaseHandler\(Deno\.env\.toObject\(\)\)\)' "Aircraft purchase handler is not registered with the Edge runtime."
    foreach ($marker in @(
        "rejects owner, company, price, currency, and other client-controlled fields",
        "rejects an invalid or anonymous Auth session",
        "fails closed when Auth is unavailable",
        "derives the owner from Auth and sends only the RPC contract",
        "does not disclose database rejection details",
        "fails closed when the privileged RPC is unavailable",
        "fails closed on a malformed privileged response",
        "returns only public fields from a privileged response"
    )) {
        if (-not $purchaseFunctionTests.Contains($marker)) {
            $issues.Add("Missing aircraft purchase endpoint test scenario: $marker")
        }
    }

    $dispatchFunction = Get-Content -Raw -Encoding UTF8 $dispatchFunctionPath
    $dispatchFunctionEntry = Get-Content -Raw -Encoding UTF8 $dispatchFunctionEntryPath
    $dispatchFunctionTests = Get-Content -Raw -Encoding UTF8 $dispatchFunctionTestPath
    $dispatchFunctionRequirements = @{
        "bounded request body" = 'MAX_BODY_BYTES = 4_096'
        "bounded upstream calls" = 'UPSTREAM_TIMEOUT_MILLISECONDS = 5_000'
        "strict dispatch payload" = 'keys\.length !== 4'
        "ICAO normalization" = 'trim\(\)\.toUpperCase\(\)'
        "Auth session verification" = '/auth/v1/user'
        "anonymous session rejection" = 'user\.is_anonymous !== false'
        "service-role dispatch RPC" = '/rest/v1/rpc/create_dispatch_draft'
        "owner derived from Auth" = 'owner_id: user\.id'
        "service credential API key" = 'apikey: configuration\.serviceRoleKey'
        "service credential bearer" = 'authorization: `Bearer \$\{configuration\.serviceRoleKey\}`'
        "redacted dispatch failure" = 'dispatch_rejected'
        "allowlisted public response" = 'aircraftId: value\.aircraftId[\s\S]+arrivalIcao: value\.arrivalIcao[\s\S]+createdAt: value\.createdAt[\s\S]+departureIcao: value\.departureIcao[\s\S]+dispatchId: value\.dispatchId'
        "non-cacheable response" = 'headers\.set\("cache-control", "no-store"\)'
    }
    foreach ($entry in $dispatchFunctionRequirements.GetEnumerator()) {
        Require-Text $dispatchFunction $entry.Value "Dispatch draft endpoint invariant missing: $($entry.Key)."
    }
    if ($dispatchFunction -match 'request\.(owner|company|state|created|route|simbrief)[A-Za-z]*') {
        $issues.Add("Dispatch draft endpoint must not accept client-controlled owner, company, state, time, route or SimBrief data.")
    }
    Require-Text $config '\[functions\.dispatch-draft\][\s\S]+verify_jwt = true[\s\S]+entrypoint = "\./functions/dispatch-draft/index\.ts"' "Dispatch draft Edge function must verify JWTs and register its entrypoint."
    Require-Text $dispatchFunctionEntry 'Deno\.serve\(createDispatchDraftHandler\(Deno\.env\.toObject\(\)\)\)' "Dispatch draft handler is not registered with the Edge runtime."
    foreach ($marker in @(
        "rejects owner, company, state, time, route, and other client-controlled fields",
        "normalizes valid airports and rejects invalid or identical ICAO codes",
        "rejects an invalid or anonymous Auth session",
        "fails closed when Auth is unavailable",
        "derives the owner from Auth and sends only the normalized RPC contract",
        "does not disclose database rejection details",
        "fails closed when the privileged RPC is unavailable",
        "fails closed on a malformed or mismatched privileged response",
        "returns only public fields from a privileged response"
    )) {
        if (-not $dispatchFunctionTests.Contains($marker)) {
            $issues.Add("Missing dispatch draft endpoint test scenario: $marker")
        }
    }
    Require-Text ([string]$package.scripts.'backend:functions:test') 'company-onboarding/handler\.test\.ts.+aircraft-purchase/handler\.test\.ts.+dispatch-draft/handler\.test\.ts' "The functions test script must execute onboarding, aircraft purchase and dispatch draft handlers."

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
        (Get-Content -Raw -Encoding UTF8 $ledgerTestPath) +
        "`n" +
        (Get-Content -Raw -Encoding UTF8 $onboardingStructureTestPath) +
        "`n" +
        (Get-Content -Raw -Encoding UTF8 $onboardingTestPath) +
        "`n" +
        (Get-Content -Raw -Encoding UTF8 $purchaseStructureTestPath) +
        "`n" +
        (Get-Content -Raw -Encoding UTF8 $purchaseTestPath) +
        "`n" +
        (Get-Content -Raw -Encoding UTF8 $dispatchStructureTestPath) +
        "`n" +
        (Get-Content -Raw -Encoding UTF8 $dispatchTestPath)
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
        "authenticated cannot insert a company directly",
        "an identical onboarding command replays idempotently",
        "onboarding idempotency payload collision is rejected",
        "A can read only company A after onboarding",
        "B can read only company B after onboarding",
        "an injected opening failure rolls back onboarding",
        "authenticated cannot execute the purchase command",
        "authenticated cannot forge aircraft ownership",
        "identical purchase replays with the same response",
        "purchase idempotency collision is rejected",
        "insufficient balance leaves no partial state",
        "owner B cannot read owner A aircraft",
        "authenticated cannot forge an offer price",
        "deletion pending blocks aircraft purchase",
        "injected failure rolls back ownership, command, debit and offer state",
        "authenticated cannot execute the dispatch command",
        "authenticated cannot forge a dispatch",
        "server normalizes airports and derives company and state",
        "identical dispatch creation replays with the same response",
        "dispatch idempotency payload collision is rejected",
        "owner A cannot dispatch owner B aircraft",
        "a second active draft for the same aircraft is rejected",
        "owner B cannot read owner A dispatch",
        "deletion pending blocks dispatch creation",
        "injected failure rolls back dispatch and command",
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
    Require-Text $types 'create_company_with_opening_balance:' "Generated types do not expose authoritative onboarding."
    Require-Text $types 'aircraft_purchase_offers:' "Generated types do not expose purchase offers."
    Require-Text $types 'company_aircraft:' "Generated types do not expose company aircraft."
    Require-Text $types 'purchase_aircraft:' "Generated types do not expose authoritative purchase."
    Require-Text $types 'get_company_aircraft:' "Generated types do not expose owner aircraft reads."
    Require-Text $types 'flight_dispatches:' "Generated types do not expose flight dispatches."
    Require-Text $types 'create_dispatch_draft:' "Generated types do not expose authoritative dispatch creation."

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
    Require-Text $ciBackend 'Company onboarding concurrency passed' "Backend CI does not report onboarding concurrency."
    Require-Text $ciBackend 'Concurrent company onboarding commands did not converge' "Backend CI does not verify identical onboarding convergence."
    Require-Text $ciBackend 'pnpm backend:functions:test' "Backend CI does not execute all Edge handler tests on Linux."
    Require-Text $ciBackend 'realtime,storage-api,imgproxy,mailpit,edge-runtime,logflare,vector,supavisor' "Backend CI must isolate PostgreSQL resets from the Edge Runtime port lifecycle."
    Require-Text $ciBackend '"1\|1"' "Backend CI does not verify one immutable concurrent ledger entry."
    Require-Text $ciBackend 'Aircraft purchase concurrency passed' "Backend CI does not report purchase concurrency."
    Require-Text $ciBackend 'Concurrent aircraft purchases did not converge' "Backend CI does not verify purchase convergence."
    Require-Text $ciBackend '"1\|1\|1\|33000000"' "Backend CI does not verify one aircraft, command, debit and safe balance."
    Require-Text $ciBackend 'Aircraft balance concurrency passed' "Backend CI does not report the shared-balance race."
    Require-Text $ciBackend '"0\|1"' "Backend CI does not require exactly one distinct purchase to fail."
    Require-Text $ciBackend '"1\|1\|1\|5000000"' "Backend CI does not verify nonnegative balance after the race."
    Require-Text $ciBackend 'Dispatch draft concurrency passed' "Backend CI does not report dispatch concurrency."
    Require-Text $ciBackend 'Concurrent dispatch drafts did not preserve one active draft' "Backend CI does not verify one active dispatch under concurrency."
    Require-Text $ciBackend '"1\|1\|0\|1"' "Backend CI does not require one dispatch, one command, draft-only state and one aircraft."
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
        "eng\economy-policy.json",
        "supabase\config.toml",
        "supabase\migrations\20260728000100_create_companies.sql",
        "supabase\migrations\20260731000100_account_lifecycle.sql",
        "supabase\migrations\20260731000200_account_deletion_restore_replay.sql",
        "supabase\migrations\20260731000300_immutable_financial_ledger.sql",
        "supabase\migrations\20260731000400_authoritative_company_onboarding.sql",
        "supabase\migrations\20260802000100_authoritative_aircraft_purchase.sql",
        "supabase\migrations\20260803000100_authoritative_dispatch_draft.sql",
        "supabase\seed.sql",
        "supabase\tests\database\companies_structure.test.sql",
        "supabase\tests\database\companies_rls.test.sql",
        "supabase\tests\database\account_lifecycle_structure.test.sql",
        "supabase\tests\database\account_lifecycle.test.sql",
        "supabase\tests\database\account_restore_replay_structure.test.sql",
        "supabase\tests\database\account_restore_replay.test.sql",
        "supabase\tests\database\financial_ledger_structure.test.sql",
        "supabase\tests\database\financial_ledger.test.sql",
        "supabase\tests\database\company_onboarding_structure.test.sql",
        "supabase\tests\database\company_onboarding.test.sql",
        "supabase\tests\database\aircraft_purchase_structure.test.sql",
        "supabase\tests\database\aircraft_purchase.test.sql",
        "supabase\tests\database\dispatch_draft_structure.test.sql",
        "supabase\tests\database\dispatch_draft.test.sql",
        "supabase\functions\company-onboarding\handler.ts",
        "supabase\functions\company-onboarding\economy-policy.json",
        "supabase\functions\company-onboarding\index.ts",
        "supabase\functions\company-onboarding\handler.test.ts",
        "supabase\functions\company-onboarding\package.json",
        "supabase\functions\aircraft-purchase\handler.ts",
        "supabase\functions\aircraft-purchase\index.ts",
        "supabase\functions\aircraft-purchase\handler.test.ts",
        "supabase\functions\aircraft-purchase\package.json",
        "supabase\functions\dispatch-draft\handler.ts",
        "supabase\functions\dispatch-draft\index.ts",
        "supabase\functions\dispatch-draft\handler.test.ts",
        "supabase\functions\dispatch-draft\package.json",
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
    $configCopy = Join-Path $temporaryRoot "supabase\config.toml"
    $configText = Get-Content -Raw -Encoding UTF8 $configCopy
    $configText = $configText.Replace(
        "[auth]`r`nenabled = true",
        "[auth]`r`nenabled = true`r`nenable_signup = true"
    ).Replace(
        "[auth]`nenabled = true",
        "[auth]`nenabled = true`nenable_signup = true"
    )
    [System.IO.File]::WriteAllText($configCopy, $configText)
    $publicSignupIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($publicSignupIssues -match "Public Auth signup must remain disabled")) {
        Write-Error "Harness self-test failed to detect public Auth signup."
        exit 1
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "supabase\config.toml") -Destination $configCopy
    $configText = Get-Content -Raw -Encoding UTF8 $configCopy
    $configText = $configText.Replace(
        "[auth.email]`r`n# Allow/disallow new user signups via email to your project.`r`n# Keep the email/password provider available for identities provisioned through`r`n# the local Admin API. Global auth.enable_signup remains false, so public`r`n# registration is still rejected.`r`nenable_signup = true",
        "[auth.email]`r`n# Allow/disallow new user signups via email to your project.`r`nenable_signup = false"
    ).Replace(
        "[auth.email]`n# Allow/disallow new user signups via email to your project.`n# Keep the email/password provider available for identities provisioned through`n# the local Admin API. Global auth.enable_signup remains false, so public`n# registration is still rejected.`nenable_signup = true",
        "[auth.email]`n# Allow/disallow new user signups via email to your project.`nenable_signup = false"
    )
    [System.IO.File]::WriteAllText($configCopy, $configText)
    $disabledEmailIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($disabledEmailIssues -match "Local email/password Auth must remain available")) {
        Write-Error "Harness self-test failed to detect disabled local password Auth."
        exit 1
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "supabase\config.toml") -Destination $configCopy
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
    $invokeText = Get-Content -Raw -Encoding UTF8 $invokeCopy
    $invokeText = $invokeText.Replace(', "--no-backup"', '')
    [System.IO.File]::WriteAllText($invokeCopy, $invokeText)
    $persistentDatabaseIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($persistentDatabaseIssues -match "must not preserve database state")) {
        Write-Error "Harness self-test failed to detect a shutdown that preserves local database state."
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

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "supabase\migrations\20260731000300_immutable_financial_ledger.sql") -Destination $ledgerMigrationCopy
    $onboardingMigrationCopy = Join-Path $temporaryRoot "supabase\migrations\20260731000400_authoritative_company_onboarding.sql"
    $onboardingText = Get-Content -Raw -Encoding UTF8 $onboardingMigrationCopy
    $onboardingText = $onboardingText.Replace(
        "grant execute on function public.create_company_with_opening_balance(uuid, uuid, text, bigint, text) to service_role;",
        "grant execute on function public.create_company_with_opening_balance(uuid, uuid, text, bigint, text) to authenticated;"
    )
    [System.IO.File]::WriteAllText($onboardingMigrationCopy, $onboardingText)
    $unsafeOnboardingIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($unsafeOnboardingIssues -match "service-role-only") -or
        -not ($unsafeOnboardingIssues -match "service-only onboarding")) {
        Write-Error "Harness self-test failed to detect client-executable onboarding."
        exit 1
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "supabase\migrations\20260731000400_authoritative_company_onboarding.sql") -Destination $onboardingMigrationCopy
    $purchaseMigrationCopy = Join-Path $temporaryRoot "supabase\migrations\20260802000100_authoritative_aircraft_purchase.sql"
    $purchaseText = Get-Content -Raw -Encoding UTF8 $purchaseMigrationCopy
    $purchaseText = $purchaseText.Replace(
        "grant execute on function public.purchase_aircraft(uuid, uuid, uuid) to service_role;",
        "grant execute on function public.purchase_aircraft(uuid, uuid, uuid) to authenticated;"
    )
    [System.IO.File]::WriteAllText($purchaseMigrationCopy, $purchaseText)
    $unsafePurchaseIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($unsafePurchaseIssues -match "service-role-only") -or
        -not ($unsafePurchaseIssues -match "service-only purchase")) {
        Write-Error "Harness self-test failed to detect client-executable aircraft purchase."
        exit 1
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "supabase\migrations\20260802000100_authoritative_aircraft_purchase.sql") -Destination $purchaseMigrationCopy
    $dispatchMigrationCopy = Join-Path $temporaryRoot "supabase\migrations\20260803000100_authoritative_dispatch_draft.sql"
    $dispatchText = Get-Content -Raw -Encoding UTF8 $dispatchMigrationCopy
    $dispatchText = $dispatchText.Replace(
        "grant execute on function public.create_dispatch_draft(uuid, uuid, uuid, text, text) to service_role;",
        "grant execute on function public.create_dispatch_draft(uuid, uuid, uuid, text, text) to authenticated;"
    )
    [System.IO.File]::WriteAllText($dispatchMigrationCopy, $dispatchText)
    $unsafeDispatchIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($unsafeDispatchIssues -match "service-role-only") -or
        -not ($unsafeDispatchIssues -match "service-only dispatch")) {
        Write-Error "Harness self-test failed to detect client-executable dispatch creation."
        exit 1
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "supabase\migrations\20260803000100_authoritative_dispatch_draft.sql") -Destination $dispatchMigrationCopy
    $dispatchText = Get-Content -Raw -Encoding UTF8 $dispatchMigrationCopy
    $dispatchText = $dispatchText.Replace(
        "    arrival_icao text`r`n)",
        "    arrival_icao text,`r`n    company_id uuid`r`n)"
    ).Replace(
        "    arrival_icao text`n)",
        "    arrival_icao text,`n    company_id uuid`n)"
    )
    [System.IO.File]::WriteAllText($dispatchMigrationCopy, $dispatchText)
    $clientDispatchAuthorityIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($clientDispatchAuthorityIssues -match "client-controlled company, state or time")) {
        Write-Error "Harness self-test failed to detect client-controlled dispatch authority."
        exit 1
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "supabase\migrations\20260803000100_authoritative_dispatch_draft.sql") -Destination $dispatchMigrationCopy
    $onboardingFunctionCopy = Join-Path $temporaryRoot "supabase\functions\company-onboarding\handler.ts"
    $onboardingFunctionText = Get-Content -Raw -Encoding UTF8 $onboardingFunctionCopy
    $onboardingFunctionText = $onboardingFunctionText.Replace(
        "owner_id: user.id,",
        "owner_id: request.ownerId,"
    )
    [System.IO.File]::WriteAllText($onboardingFunctionCopy, $onboardingFunctionText)
    $clientOwnerIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($clientOwnerIssues -match "owner derived from Auth")) {
        Write-Error "Harness self-test failed to detect a client-controlled company owner."
        exit 1
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "supabase\functions\company-onboarding\handler.ts") -Destination $onboardingFunctionCopy
    $onboardingFunctionText = Get-Content -Raw -Encoding UTF8 $onboardingFunctionCopy
    $onboardingFunctionText = $onboardingFunctionText.Replace(
        "apikey: configuration.serviceRoleKey,",
        "apikey: configuration.anonKey,"
    )
    [System.IO.File]::WriteAllText($onboardingFunctionCopy, $onboardingFunctionText)
    $unprivilegedRpcIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($unprivilegedRpcIssues -match "service credential header")) {
        Write-Error "Harness self-test failed to detect an unprivileged onboarding RPC call."
        exit 1
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "supabase\functions\company-onboarding\handler.ts") -Destination $onboardingFunctionCopy
    $purchaseFunctionCopy = Join-Path $temporaryRoot "supabase\functions\aircraft-purchase\handler.ts"
    $purchaseFunctionText = Get-Content -Raw -Encoding UTF8 $purchaseFunctionCopy
    $purchaseFunctionText = $purchaseFunctionText.Replace(
        "owner_id: user.id,",
        "owner_id: request.ownerId,"
    )
    [System.IO.File]::WriteAllText($purchaseFunctionCopy, $purchaseFunctionText)
    $clientPurchaseOwnerIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($clientPurchaseOwnerIssues -match "owner derived from Auth") -or
        -not ($clientPurchaseOwnerIssues -match "client-controlled owner")) {
        Write-Error "Harness self-test failed to detect a client-controlled aircraft owner."
        exit 1
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "supabase\functions\aircraft-purchase\handler.ts") -Destination $purchaseFunctionCopy
    $purchaseFunctionText = Get-Content -Raw -Encoding UTF8 $purchaseFunctionCopy
    $purchaseFunctionText = $purchaseFunctionText.Replace(
        "apikey: configuration.serviceRoleKey,",
        "apikey: configuration.anonKey,"
    )
    [System.IO.File]::WriteAllText($purchaseFunctionCopy, $purchaseFunctionText)
    $unprivilegedPurchaseIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($unprivilegedPurchaseIssues -match "service credential API key")) {
        Write-Error "Harness self-test failed to detect an unprivileged aircraft purchase RPC call."
        exit 1
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "supabase\functions\aircraft-purchase\handler.ts") -Destination $purchaseFunctionCopy
    $purchaseFunctionText = Get-Content -Raw -Encoding UTF8 $purchaseFunctionCopy
    $purchaseFunctionText = $purchaseFunctionText.Replace(
        "offer_id: request.offerId,",
        "offer_id: request.offerId,`r`n        price_minor: request.priceMinor,"
    )
    [System.IO.File]::WriteAllText($purchaseFunctionCopy, $purchaseFunctionText)
    $clientPriceIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($clientPriceIssues -match "client-controlled owner, company, price or currency")) {
        Write-Error "Harness self-test failed to detect a client-controlled aircraft price."
        exit 1
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "supabase\functions\aircraft-purchase\handler.ts") -Destination $purchaseFunctionCopy
    $dispatchFunctionCopy = Join-Path $temporaryRoot "supabase\functions\dispatch-draft\handler.ts"
    $dispatchFunctionText = Get-Content -Raw -Encoding UTF8 $dispatchFunctionCopy
    $dispatchFunctionText = $dispatchFunctionText.Replace(
        "owner_id: user.id,",
        "owner_id: request.ownerId,"
    )
    [System.IO.File]::WriteAllText($dispatchFunctionCopy, $dispatchFunctionText)
    $clientDispatchOwnerIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($clientDispatchOwnerIssues -match "owner derived from Auth") -or
        -not ($clientDispatchOwnerIssues -match "client-controlled owner")) {
        Write-Error "Harness self-test failed to detect a client-controlled dispatch owner."
        exit 1
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "supabase\functions\dispatch-draft\handler.ts") -Destination $dispatchFunctionCopy
    $dispatchFunctionText = Get-Content -Raw -Encoding UTF8 $dispatchFunctionCopy
    $dispatchFunctionText = $dispatchFunctionText.Replace(
        "apikey: configuration.serviceRoleKey,",
        "apikey: configuration.anonKey,"
    )
    [System.IO.File]::WriteAllText($dispatchFunctionCopy, $dispatchFunctionText)
    $unprivilegedDispatchIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($unprivilegedDispatchIssues -match "service credential API key")) {
        Write-Error "Harness self-test failed to detect an unprivileged dispatch RPC call."
        exit 1
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "supabase\functions\dispatch-draft\handler.ts") -Destination $dispatchFunctionCopy
    $dispatchFunctionText = Get-Content -Raw -Encoding UTF8 $dispatchFunctionCopy
    $dispatchFunctionText = $dispatchFunctionText.Replace(
        "arrival_icao: request.arrivalIcao,",
        "arrival_icao: request.arrivalIcao,`r`n        state: request.state,"
    )
    [System.IO.File]::WriteAllText($dispatchFunctionCopy, $dispatchFunctionText)
    $clientDispatchStateIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($clientDispatchStateIssues -match "client-controlled owner, company, state, time, route or SimBrief")) {
        Write-Error "Harness self-test failed to detect client-controlled dispatch state."
        exit 1
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "supabase\functions\dispatch-draft\handler.ts") -Destination $dispatchFunctionCopy
    $dispatchFunctionTestCopy = Join-Path $temporaryRoot "supabase\functions\dispatch-draft\handler.test.ts"
    $dispatchFunctionTestText = Get-Content -Raw -Encoding UTF8 $dispatchFunctionTestCopy
    $dispatchFunctionTestText = $dispatchFunctionTestText.Replace(
        "returns only public fields from a privileged response",
        "returns fields from a privileged response"
    )
    [System.IO.File]::WriteAllText($dispatchFunctionTestCopy, $dispatchFunctionTestText)
    $incompleteDispatchTestsIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($incompleteDispatchTestsIssues -match "Missing dispatch draft endpoint test scenario")) {
        Write-Error "Harness self-test failed to detect an incomplete dispatch endpoint contract."
        exit 1
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "supabase\functions\dispatch-draft\handler.test.ts") -Destination $dispatchFunctionTestCopy
    $economyPolicyCopy = Join-Path $temporaryRoot "eng\economy-policy.json"
    $economyPolicyText = Get-Content -Raw -Encoding UTF8 $economyPolicyCopy
    $economyPolicyText = $economyPolicyText.Replace('"schemaVersion": 1', '"schemaVersion": 2')
    [System.IO.File]::WriteAllText($economyPolicyCopy, $economyPolicyText)
    $unknownPolicyVersionIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($unknownPolicyVersionIssues -match "schema v1")) {
        Write-Error "Harness self-test failed to detect an unknown economy policy version."
        exit 1
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "eng\economy-policy.json") -Destination $economyPolicyCopy
    $packagedEconomyPolicyCopy = Join-Path $temporaryRoot "supabase\functions\company-onboarding\economy-policy.json"
    $packagedEconomyPolicyText = Get-Content -Raw -Encoding UTF8 $packagedEconomyPolicyCopy
    $packagedEconomyPolicyText = $packagedEconomyPolicyText.Replace('"currencyCode": "EUR"', '"currencyCode": "USD"')
    [System.IO.File]::WriteAllText($packagedEconomyPolicyCopy, $packagedEconomyPolicyText)
    $divergentPolicyIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($divergentPolicyIssues -match "diverges")) {
        Write-Error "Harness self-test failed to detect a divergent packaged economy policy."
        exit 1
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot "supabase\functions\company-onboarding\economy-policy.json") -Destination $packagedEconomyPolicyCopy
    $runtimeText = Get-Content -Raw -Encoding UTF8 $runtimeCopy
    $runtimeText = $runtimeText.Replace(
        '"--env", "SUPABASE_TELEMETRY_DISABLED=1",',
        '"--env", "SUPABASE_TELEMETRY_DISABLED=1",`r`n        "--env", "COMPANY_OPENING_CURRENCY=USD",'
    )
    [System.IO.File]::WriteAllText($runtimeCopy, $runtimeText)
    $environmentOverrideIssues = @(Get-BackendIssues -Root $temporaryRoot)
    if (-not ($environmentOverrideIssues -match "replaceable through environment variables")) {
        Write-Error "Harness self-test failed to detect an economy policy environment override."
        exit 1
    }
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}

Write-Output "Backend checks passed (T0012-T0023, T0028-T0029, T0035, T0040 and T0047-T0048 repository plus 26 mutation scenarios)."
