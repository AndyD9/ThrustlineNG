#requires -Version 7.6
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $IsLinux) {
    throw "This CI backend harness requires the explicit Linux runner."
}

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$networkName = "thrustline-ci"
$testNetworkName = "thrustline-ci-tests"
$projectId = "thrustline-ng"
$started = $false
$testNetworkCreated = $false
$dockerPath = $null
$databaseContainer = $null
$restoreDatabaseName = "thrustline_t0019_restore"
$restoreBackupPath = "/tmp/thrustline-t0019-restore.dump"
$restoreJournalPath = "/tmp/thrustline-t0019-replay.tsv"
$restoreListPath = "/tmp/thrustline-t0019-restore.list"
$restoreFilteredListPath = "/tmp/thrustline-t0019-restore-filtered.list"

function Invoke-Supabase {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,
        [switch]$SuppressOutput
    )

    if ($SuppressOutput) {
        & pnpm exec supabase @Arguments *> $null
    }
    else {
        & pnpm exec supabase @Arguments
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Supabase CI command failed."
    }
}

function Stop-SupabaseQuietly {
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & pnpm exec supabase stop --project-id $projectId *> $null
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
}

Push-Location $repositoryRoot
try {
    & pnpm exec supabase --version *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Supabase CLI binary is missing; retrying the frozen install once."
        & pnpm install --frozen-lockfile --force
        if ($LASTEXITCODE -ne 0) {
            throw "Frozen dependency reinstall failed."
        }
        & pnpm exec supabase --version *> $null
        if ($LASTEXITCODE -ne 0) {
            throw "Supabase CLI binary is unavailable after one frozen reinstall."
        }
    }

    $dockerPath = @(
        Get-Command docker -CommandType Application -All -ErrorAction Stop |
            Select-Object -ExpandProperty Source |
            Select-Object -Unique |
            Select-Object -First 1
    )[0]
    & $dockerPath info --format "{{.ServerVersion}}" *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker daemon is unavailable on the CI runner."
    }

    $existingNetworks = @(& $dockerPath network ls --format "{{.Name}}")
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to list Docker networks."
    }
    if ($networkName -notin $existingNetworks) {
        & $dockerPath network create `
            --opt "com.docker.network.bridge.host_binding_ipv4=127.0.0.1" `
            $networkName *> $null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create the loopback-only CI network."
        }
    }

    Invoke-Supabase -SuppressOutput -Arguments @(
        "start",
        "--network-id", $networkName,
        "--exclude",
        "realtime,storage-api,imgproxy,mailpit,edge-runtime,logflare,vector,supavisor"
    )
    $started = $true

    $publishedPorts = @(
        & $dockerPath ps `
            --filter "label=com.supabase.cli.project=$projectId" `
            --format "{{.Ports}}"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to inspect Supabase published ports."
    }
    $unsafeBindings = @(
        $publishedPorts | Where-Object { $_ -match '(^|,\s)(0\.0\.0\.0:|\[::\]:)' }
    )
    if ($unsafeBindings.Count -gt 0) {
        throw "Docker exposed the CI Supabase stack beyond loopback."
    }

    Invoke-Supabase -Arguments @("db", "reset", "--local")
    Invoke-Supabase -Arguments @("db", "reset", "--local")

    & $dockerPath network create $testNetworkName *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create the isolated pgTAP network."
    }
    $testNetworkCreated = $true
    $databaseContainers = @(
        & $dockerPath ps `
            --filter "label=com.supabase.cli.project=$projectId" `
            --filter "name=supabase_db_" `
            --format "{{.ID}}"
    )
    if ($LASTEXITCODE -ne 0 -or $databaseContainers.Count -ne 1) {
        throw "Expected exactly one local Supabase database container."
    }
    $databaseContainer = $databaseContainers[0]
    & $dockerPath network connect `
        --alias db `
        $testNetworkName `
        $databaseContainers[0]
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to attach the database alias to the pgTAP network."
    }

    $testOutput = @(
        & pnpm exec supabase test db --network-id $testNetworkName 2>&1
    )
    $testExitCode = $LASTEXITCODE
    $testOutput | Write-Output
    if ($testExitCode -ne 0) {
        throw "Supabase pgTAP execution failed."
    }
    $testText = $testOutput -join "`n"
    if ($testText -notmatch "companies_structure\.test\.sql" -or
        $testText -notmatch "companies_rls\.test\.sql" -or
        $testText -notmatch "account_lifecycle_structure\.test\.sql" -or
        $testText -notmatch "account_lifecycle\.test\.sql" -or
        $testText -notmatch "account_restore_replay_structure\.test\.sql" -or
        $testText -notmatch "account_restore_replay\.test\.sql" -or
        $testText -notmatch "financial_ledger_structure\.test\.sql" -or
        $testText -notmatch "financial_ledger\.test\.sql" -or
        $testText -notmatch "company_onboarding_structure\.test\.sql" -or
        $testText -notmatch "company_onboarding\.test\.sql" -or
        $testText -notmatch "Result:\s+PASS") {
        throw "Supabase pgTAP did not prove all ten files with Result: PASS."
    }

    $concurrencyUserId = "44000000-0000-4000-8000-000000000004"
    $concurrencySessionId = "44100000-0000-4000-8000-000000000004"
    $concurrencyCompanyId = "d4000000-0000-4000-8000-000000000004"
    $concurrencyClaims = @{
        role = "authenticated"
        sub = $concurrencyUserId
        session_id = $concurrencySessionId
        is_anonymous = $false
        amr = @(
            @{
                method = "password"
                timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            }
        )
    } | ConvertTo-Json -Compress -Depth 4
    $escapedClaims = $concurrencyClaims.Replace("'", "''")
    $setupSql = @"
insert into auth.users (id, email, raw_user_meta_data)
values (
    '$concurrencyUserId',
    'lifecycle-concurrency@thrustline.invalid',
    '{}'
);
insert into auth.sessions (id, user_id, created_at, updated_at)
values (
    '$concurrencySessionId',
    '$concurrencyUserId',
    clock_timestamp(),
    clock_timestamp()
);
insert into public.companies (id, owner_id, name)
values (
    '$concurrencyCompanyId',
    '$concurrencyUserId',
    'Lifecycle Concurrency Air'
);
"@
    $firstSql = @"
begin;
set local role authenticated;
select set_config('request.jwt.claims', '$escapedClaims', true);
select public.request_account_deletion(
    'aa400000-0000-4000-8000-000000000001'
) ->> 'requestId';
select pg_sleep(4);
commit;
"@
    $secondSql = @"
begin;
set local role authenticated;
select set_config('request.jwt.claims', '$escapedClaims', true);
select public.request_account_deletion(
    'aa400000-0000-4000-8000-000000000002'
) ->> 'requestId';
commit;
"@
    $cleanupSql = @"
delete from private.account_lifecycle_commands
where owner_id = '$concurrencyUserId';
delete from private.account_deletion_requests
where owner_id = '$concurrencyUserId';
delete from public.companies
where owner_id = '$concurrencyUserId';
delete from auth.users
where id = '$concurrencyUserId';
"@

    & $dockerPath exec $databaseContainers[0] `
        psql -X -q -v ON_ERROR_STOP=1 -U postgres -d postgres -c $setupSql
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to prepare the account lifecycle concurrency scenario."
    }

    $concurrencyJobs = @()
    try {
        $concurrencyJobs += Start-Job -ScriptBlock {
            param($DockerPath, $ContainerId, $Sql)
            & $DockerPath exec $ContainerId `
                psql -X -qAt -v ON_ERROR_STOP=1 -U postgres -d postgres -c $Sql
            if ($LASTEXITCODE -ne 0) {
                throw "First concurrent database session failed."
            }
        } -ArgumentList $dockerPath, $databaseContainers[0], $firstSql

        Start-Sleep -Milliseconds 750

        $concurrencyJobs += Start-Job -ScriptBlock {
            param($DockerPath, $ContainerId, $Sql)
            & $DockerPath exec $ContainerId `
                psql -X -qAt -v ON_ERROR_STOP=1 -U postgres -d postgres -c $Sql
            if ($LASTEXITCODE -ne 0) {
                throw "Second concurrent database session failed."
            }
        } -ArgumentList $dockerPath, $databaseContainers[0], $secondSql

        $concurrencyJobs | Wait-Job | Out-Null
        $concurrencyOutput = @(
            $concurrencyJobs | Receive-Job
        )
        $requestIds = @(
            $concurrencyOutput |
                ForEach-Object { [string]$_ } |
                Where-Object { $_ -match '^[0-9a-f-]{36}$' }
        )
        if ($concurrencyJobs.State -contains "Failed" -or
            $requestIds.Count -ne 2 -or
            @($requestIds | Select-Object -Unique).Count -ne 1) {
            throw "Concurrent account deletion requests did not converge."
        }

        $convergenceSql = @"
select
    count(*) filter (where cancelled_at is null),
    (
        select count(*)
        from private.account_lifecycle_commands
        where owner_id = '$concurrencyUserId'
          and operation = 'request_deletion'
    ),
    (
        select count(distinct response ->> 'requestId')
        from private.account_lifecycle_commands
        where owner_id = '$concurrencyUserId'
          and operation = 'request_deletion'
    )
from private.account_deletion_requests
where owner_id = '$concurrencyUserId';
"@
        $convergence = @(
            & $dockerPath exec $databaseContainers[0] `
                psql -X -qAt -v ON_ERROR_STOP=1 -U postgres -d postgres -c $convergenceSql
        )
        if ($LASTEXITCODE -ne 0 -or
            ($convergence -join "").Trim() -ne "1|2|1") {
            throw "Concurrent account lifecycle state is not idempotent."
        }
        Write-Output "Account lifecycle concurrency passed: 2 sessions, 1 request, 2 idempotency records."
    }
    finally {
        $concurrencyJobs | Remove-Job -Force -ErrorAction SilentlyContinue
        & $dockerPath exec $databaseContainers[0] `
            psql -X -q -v ON_ERROR_STOP=1 -U postgres -d postgres -c $cleanupSql
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to clean the synthetic concurrency scenario."
        }
    }

    $ledgerConcurrencyUserId = "54000000-0000-4000-8000-000000000004"
    $ledgerConcurrencyCompanyId = "f4000000-0000-4000-8000-000000000004"
    $ledgerConcurrencyKey = "a4000000-0000-4000-8000-000000000004"
    $ledgerSetupSql = @"
insert into auth.users (id, email, raw_user_meta_data)
values (
    '$ledgerConcurrencyUserId',
    'ledger-concurrency@thrustline.invalid',
    '{}'
);
insert into public.companies (id, owner_id, name)
values (
    '$ledgerConcurrencyCompanyId',
    '$ledgerConcurrencyUserId',
    'Ledger Concurrency Air'
);
"@
    $ledgerFirstSql = @"
begin;
set local role service_role;
select public.post_company_opening_balance(
    '$ledgerConcurrencyCompanyId',
    '$ledgerConcurrencyKey',
    42000000,
    'EUR'
) ->> 'entryId';
select pg_sleep(4);
commit;
"@
    $ledgerSecondSql = @"
begin;
set local role service_role;
select public.post_company_opening_balance(
    '$ledgerConcurrencyCompanyId',
    '$ledgerConcurrencyKey',
    42000000,
    'EUR'
) ->> 'entryId';
commit;
"@

    & $dockerPath exec $databaseContainers[0] `
        psql -X -q -v ON_ERROR_STOP=1 -U postgres -d postgres -c $ledgerSetupSql
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to prepare the financial ledger concurrency scenario."
    }

    $ledgerConcurrencyJobs = @()
    try {
        $ledgerConcurrencyJobs += Start-Job -ScriptBlock {
            param($DockerPath, $ContainerId, $Sql)
            & $DockerPath exec $ContainerId `
                psql -X -qAt -v ON_ERROR_STOP=1 -U postgres -d postgres -c $Sql
            if ($LASTEXITCODE -ne 0) {
                throw "First concurrent ledger session failed."
            }
        } -ArgumentList $dockerPath, $databaseContainers[0], $ledgerFirstSql

        Start-Sleep -Milliseconds 750

        $ledgerConcurrencyJobs += Start-Job -ScriptBlock {
            param($DockerPath, $ContainerId, $Sql)
            & $DockerPath exec $ContainerId `
                psql -X -qAt -v ON_ERROR_STOP=1 -U postgres -d postgres -c $Sql
            if ($LASTEXITCODE -ne 0) {
                throw "Second concurrent ledger session failed."
            }
        } -ArgumentList $dockerPath, $databaseContainers[0], $ledgerSecondSql

        $ledgerConcurrencyJobs | Wait-Job | Out-Null
        $ledgerConcurrencyOutput = @(
            $ledgerConcurrencyJobs | Receive-Job |
                ForEach-Object { [string]$_ } |
                Where-Object { $_ -match '^[0-9a-f-]{36}$' }
        )
        if ($ledgerConcurrencyJobs.State -contains "Failed" -or
            $ledgerConcurrencyOutput.Count -ne 2 -or
            @($ledgerConcurrencyOutput | Select-Object -Unique).Count -ne 1) {
            throw "Concurrent financial ledger commands did not converge."
        }

        $ledgerConvergenceSql = @"
select
    count(*),
    count(distinct idempotency_key)
from private.financial_ledger_entries as entries
join private.financial_ledger_subjects as subjects
  on subjects.subject_id = entries.subject_id
where subjects.company_id = '$ledgerConcurrencyCompanyId';
"@
        $ledgerConvergence = @(
            & $dockerPath exec $databaseContainers[0] `
                psql -X -qAt -F "|" -v ON_ERROR_STOP=1 -U postgres -d postgres -c $ledgerConvergenceSql
        )
        if ($LASTEXITCODE -ne 0 -or
            ($ledgerConvergence -join "").Trim() -ne "1|1") {
            throw "Concurrent financial ledger state is not idempotent."
        }
        Write-Output "Financial ledger concurrency passed: 2 sessions, 1 immutable entry."
    }
    finally {
        $ledgerConcurrencyJobs | Remove-Job -Force -ErrorAction SilentlyContinue
    }

    $onboardingConcurrencyUserId = "66000000-0000-4000-8000-000000000006"
    $onboardingConcurrencyKey = "ba600000-0000-4000-8000-000000000006"
    $onboardingSetupSql = @"
insert into auth.users (id, email, raw_user_meta_data, is_anonymous)
values (
    '$onboardingConcurrencyUserId',
    'onboarding-concurrency@thrustline.invalid',
    '{}',
    false
);
"@
    $onboardingFirstSql = @"
begin;
set local role service_role;
select public.create_company_with_opening_balance(
    '$onboardingConcurrencyUserId',
    '$onboardingConcurrencyKey',
    'Onboarding Concurrency Air',
    43000000,
    'EUR'
) ->> 'companyId';
select pg_sleep(4);
commit;
"@
    $onboardingSecondSql = @"
begin;
set local role service_role;
select public.create_company_with_opening_balance(
    '$onboardingConcurrencyUserId',
    '$onboardingConcurrencyKey',
    'Onboarding Concurrency Air',
    43000000,
    'EUR'
) ->> 'companyId';
commit;
"@

    & $dockerPath exec $databaseContainers[0] `
        psql -X -q -v ON_ERROR_STOP=1 -U postgres -d postgres -c $onboardingSetupSql
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to prepare the company onboarding concurrency scenario."
    }

    $onboardingConcurrencyJobs = @()
    try {
        $onboardingConcurrencyJobs += Start-Job -ScriptBlock {
            param($DockerPath, $ContainerId, $Sql)
            & $DockerPath exec $ContainerId `
                psql -X -qAt -v ON_ERROR_STOP=1 -U postgres -d postgres -c $Sql
            if ($LASTEXITCODE -ne 0) {
                throw "First concurrent onboarding session failed."
            }
        } -ArgumentList $dockerPath, $databaseContainers[0], $onboardingFirstSql

        Start-Sleep -Milliseconds 750

        $onboardingConcurrencyJobs += Start-Job -ScriptBlock {
            param($DockerPath, $ContainerId, $Sql)
            & $DockerPath exec $ContainerId `
                psql -X -qAt -v ON_ERROR_STOP=1 -U postgres -d postgres -c $Sql
            if ($LASTEXITCODE -ne 0) {
                throw "Second concurrent onboarding session failed."
            }
        } -ArgumentList $dockerPath, $databaseContainers[0], $onboardingSecondSql

        $onboardingConcurrencyJobs | Wait-Job | Out-Null
        $onboardingConcurrencyOutput = @(
            $onboardingConcurrencyJobs | Receive-Job |
                ForEach-Object { [string]$_ } |
                Where-Object { $_ -match '^[0-9a-f-]{36}$' }
        )
        if ($onboardingConcurrencyJobs.State -contains "Failed" -or
            $onboardingConcurrencyOutput.Count -ne 2 -or
            @($onboardingConcurrencyOutput | Select-Object -Unique).Count -ne 1) {
            throw "Concurrent company onboarding commands did not converge."
        }

        $onboardingConvergenceSql = @"
select
    (select count(*) from public.companies
     where owner_id = '$onboardingConcurrencyUserId'),
    (select count(*) from private.company_onboarding_commands
     where owner_id = '$onboardingConcurrencyUserId'),
    (
        select count(*)
        from private.financial_ledger_entries as entries
        join private.financial_ledger_subjects as subjects using (subject_id)
        join public.companies as companies on companies.id = subjects.company_id
        where companies.owner_id = '$onboardingConcurrencyUserId'
    );
"@
        $onboardingConvergence = @(
            & $dockerPath exec $databaseContainers[0] `
                psql -X -qAt -F "|" -v ON_ERROR_STOP=1 -U postgres -d postgres -c $onboardingConvergenceSql
        )
        if ($LASTEXITCODE -ne 0 -or
            ($onboardingConvergence -join "").Trim() -ne "1|1|1") {
            throw "Concurrent company onboarding state is not atomic and idempotent."
        }
        Write-Output "Company onboarding concurrency passed: 2 sessions, 1 company, 1 opening entry."
    }
    finally {
        $onboardingConcurrencyJobs | Remove-Job -Force -ErrorAction SilentlyContinue
    }

    $restoreUserId = "48000000-0000-4000-8000-000000000008"
    $restoreSessionId = "48100000-0000-4000-8000-000000000008"
    $restoreCompanyId = "d8000000-0000-4000-8000-000000000008"
    $witnessUserId = "49000000-0000-4000-8000-000000000009"
    $witnessCompanyId = "d9000000-0000-4000-8000-000000000009"
    $restoreRequestKey = "aa800000-0000-4000-8000-000000000008"
    $restoreClaims = @{
        role = "authenticated"
        sub = $restoreUserId
        session_id = $restoreSessionId
        is_anonymous = $false
        amr = @(
            @{
                method = "password"
                timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            }
        )
    } | ConvertTo-Json -Compress -Depth 4
    $escapedRestoreClaims = $restoreClaims.Replace("'", "''")
    $restoreSetupSql = @"
insert into auth.users (id, email, raw_user_meta_data)
values
    (
        '$restoreUserId',
        'restore-drill-a@thrustline.invalid',
        '{}'
    ),
    (
        '$witnessUserId',
        'restore-drill-b@thrustline.invalid',
        '{}'
    );
insert into auth.sessions (id, user_id, created_at, updated_at)
values (
    '$restoreSessionId',
    '$restoreUserId',
    clock_timestamp(),
    clock_timestamp()
);
insert into public.companies (id, owner_id, name)
values
    (
        '$restoreCompanyId',
        '$restoreUserId',
        'Restore Drill Alpha Air'
    ),
    (
        '$witnessCompanyId',
        '$witnessUserId',
        'Restore Drill Bravo Air'
    );
"@
    & $dockerPath exec $databaseContainer `
        psql -X -q -v ON_ERROR_STOP=1 -U postgres -d postgres -c $restoreSetupSql
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to prepare the isolated restore scenario."
    }

    $backupPoint = @(
        & $dockerPath exec $databaseContainer `
            psql -X -qAt -v ON_ERROR_STOP=1 -U postgres -d postgres `
                -c "select clock_timestamp();"
    )
    if ($LASTEXITCODE -ne 0 -or $backupPoint.Count -ne 1) {
        throw "Failed to record the synthetic backup point."
    }
    $sourcePgcryptoVersion = @(
        & $dockerPath exec $databaseContainer `
            psql -X -qAt -v ON_ERROR_STOP=1 -U postgres -d postgres `
                -c "select extversion from pg_extension where extname = 'pgcrypto';"
    )
    if ($LASTEXITCODE -ne 0 -or $sourcePgcryptoVersion.Count -ne 1) {
        throw "Failed to record the source pgcrypto extension version."
    }

    $dumpTimer = [System.Diagnostics.Stopwatch]::StartNew()
    & $dockerPath exec $databaseContainer `
        pg_dump -U postgres -d postgres --format=custom --no-owner `
            --schema auth `
            --schema public `
            --schema private `
            --schema extensions `
            --schema supabase_migrations `
            --file $restoreBackupPath
    if ($LASTEXITCODE -ne 0) {
        throw "PostgreSQL synthetic backup failed."
    }
    $dumpTimer.Stop()
    & $dockerPath exec $databaseContainer `
        sh -c "pg_restore -l '$restoreBackupPath' > '$restoreListPath' && grep -v ' DEFAULT ACL ' '$restoreListPath' > '$restoreFilteredListPath'"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to prepare the scoped PostgreSQL restore list."
    }
    $defaultAclEntries = @(
        & $dockerPath exec $databaseContainer `
            sh -c "grep -c ' DEFAULT ACL ' '$restoreListPath'"
    )
    if ($LASTEXITCODE -ne 0 -or
        $defaultAclEntries.Count -ne 1 -or
        ($defaultAclEntries[0] -as [int]) -lt 1) {
        throw "Expected role-owned default ACL entries in the PostgreSQL archive."
    }

    $sourceDeletionSql = @"
begin;
set local role authenticated;
select set_config('request.jwt.claims', '$escapedRestoreClaims', true);
select public.request_account_deletion('$restoreRequestKey');
commit;
update private.account_deletion_requests
set requested_at = statement_timestamp() - interval '8 days',
    delete_after = statement_timestamp() - interval '1 day'
where owner_id = '$restoreUserId';
select set_config(
    't0019.request_id',
    (
        select (commands.response ->> 'requestId')::text
        from private.account_lifecycle_commands as commands
        where commands.owner_id = '$restoreUserId'
          and commands.operation = 'request_deletion'
        order by commands.created_at
        limit 1
    ),
    false
);
begin;
set local role service_role;
select public.finalize_account_deletion(
    current_setting('t0019.request_id')::uuid
);
commit;
"@
    & $dockerPath exec $databaseContainer `
        psql -X -q -v ON_ERROR_STOP=1 -U postgres -d postgres `
            -c $sourceDeletionSql *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to finalize the post-backup synthetic deletion."
    }

    $journalSql = "\copy (" +
        "select subject_token, request_token_hash, marker_id, completed_at, " +
        "export_schema_version, event_schema_version " +
        "from private.account_deletion_replay_events " +
        "where completed_at > '$($backupPoint[0])'::timestamptz " +
        "order by completed_at, subject_token" +
        ") to '$restoreJournalPath' with (format csv, delimiter E'\t')"
    & $dockerPath exec $databaseContainer `
        psql -X -q -v ON_ERROR_STOP=1 -U postgres -d postgres `
            -c $journalSql
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to export the post-backup deletion journal."
    }
    $journalRows = @(
        & $dockerPath exec $databaseContainer `
            sh -c "wc -l < '$restoreJournalPath'"
    )
    if ($LASTEXITCODE -ne 0 -or
        $journalRows.Count -ne 1 -or
        ($journalRows[0] -as [int]) -ne 1) {
        throw "Expected exactly one post-backup deletion replay event."
    }
    $eventFields = @(
        & $dockerPath exec $databaseContainer `
            cat $restoreJournalPath
    )
    if ($LASTEXITCODE -ne 0 -or $eventFields.Count -ne 1) {
        throw "Failed to read the exported pseudonymous deletion replay event."
    }
    $event = $eventFields[0].Split("`t")
    if ($event.Count -ne 6 -or
        $event[0] -notmatch '^[0-9a-f-]{36}$' -or
        $event[1] -notmatch '^[0-9a-f]{64}$' -or
        $event[2] -notmatch '^[0-9a-f-]{36}$' -or
        $event[4] -ne "1" -or
        $event[5] -ne "1") {
        throw "Deletion replay event format is invalid."
    }

    & $dockerPath exec $databaseContainer `
        dropdb -U postgres --if-exists $restoreDatabaseName
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clear the isolated restore database name."
    }
    & $dockerPath exec $databaseContainer `
        createdb -U postgres --template=template0 $restoreDatabaseName
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create the isolated restore database."
    }
    & $dockerPath exec $databaseContainer `
        psql -X -q -v ON_ERROR_STOP=1 -U postgres `
            -d $restoreDatabaseName -c "drop schema public cascade;" *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to prepare the empty isolated restore database."
    }

    $restoreTimer = [System.Diagnostics.Stopwatch]::StartNew()
    & $dockerPath exec $databaseContainer `
        pg_restore -U postgres --dbname $restoreDatabaseName --exit-on-error `
            --no-owner --use-list $restoreFilteredListPath $restoreBackupPath
    if ($LASTEXITCODE -ne 0) {
        throw "PostgreSQL isolated restore failed."
    }
    $restoreTimer.Stop()
    & $dockerPath exec $databaseContainer `
        psql -X -q -v ON_ERROR_STOP=1 -U postgres `
            -d $restoreDatabaseName `
            -c "create extension if not exists pgcrypto with schema extensions;" *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to reinstall pgcrypto in the isolated restored database."
    }
    $restoredPgcryptoVersion = @(
        & $dockerPath exec $databaseContainer `
            psql -X -qAt -v ON_ERROR_STOP=1 -U postgres `
                -d $restoreDatabaseName `
                -c "select extversion from pg_extension where extname = 'pgcrypto';"
    )
    if ($LASTEXITCODE -ne 0 -or
        $restoredPgcryptoVersion.Count -ne 1 -or
        $restoredPgcryptoVersion[0] -ne $sourcePgcryptoVersion[0]) {
        throw "Restored pgcrypto extension version differs from the source."
    }

    $restContainers = @(
        & $dockerPath ps `
            --filter "label=com.supabase.cli.project=$projectId" `
            --filter "name=supabase_rest_" `
            --format "{{.ID}}"
    )
    if ($LASTEXITCODE -ne 0 -or $restContainers.Count -ne 1) {
        throw "Expected exactly one local PostgREST container."
    }
    $restEnvironment = @(
        & $dockerPath inspect `
            --format "{{range .Config.Env}}{{println .}}{{end}}" `
            $restContainers[0]
    )
    if ($LASTEXITCODE -ne 0 -or
        -not ($restEnvironment -match '^PGRST_DB_URI=.*[/:]postgres(?:\?.*)?$')) {
        throw "Could not prove that PostgREST remains bound to the source database."
    }

    $preReplayCheckSql = @"
select
    (select count(*) from auth.users where id = '$restoreUserId'),
    (select count(*) from public.companies where owner_id = '$restoreUserId'),
    (select count(*) from auth.users where id = '$witnessUserId'),
    (select count(*) from public.companies where owner_id = '$witnessUserId'),
    (
        select count(*)
        from pg_class
        where oid in (
            'private.account_restoration_subjects'::regclass,
            'private.account_deletion_replay_events'::regclass
        )
          and relrowsecurity
          and relforcerowsecurity
    );
"@
    $preReplayState = @(
        & $dockerPath exec $databaseContainer `
            psql -X -qAt -F "|" -v ON_ERROR_STOP=1 -U postgres `
                -d $restoreDatabaseName -c $preReplayCheckSql
    )
    if ($LASTEXITCODE -ne 0 -or
        ($preReplayState -join "").Trim() -ne "1|1|1|1|2") {
        throw "Restored database integrity check failed before deletion replay."
    }

    $replaySql = @'
begin;
set local role service_role;
select public.replay_account_deletion_event(
    '__SUBJECT__',
    '__REQUEST_HASH__',
    '__MARKER__',
    '__COMPLETED_AT__',
    __EXPORT_VERSION__,
    __EVENT_VERSION__
);
commit;
begin;
set local role service_role;
select public.replay_account_deletion_event(
    '__SUBJECT__',
    '__REQUEST_HASH__',
    '__MARKER__',
    '__COMPLETED_AT__',
    __EXPORT_VERSION__,
    __EVENT_VERSION__
);
commit;
do $altered$
begin
    begin
        perform public.replay_account_deletion_event(
            '__SUBJECT__',
            '__REQUEST_HASH__',
            'ee000000-0000-4000-8000-000000000001',
            '__COMPLETED_AT__',
            __EXPORT_VERSION__,
            __EVENT_VERSION__
        );
        raise exception 'Altered replay event was accepted.';
    exception
        when invalid_parameter_value then
            if sqlerrm <> 'Deletion replay event conflicts with the recorded event.' then
                raise;
            end if;
    end;
end;
$altered$;
do $unknown$
begin
    begin
        perform public.replay_account_deletion_event(
            'ee000000-0000-4000-8000-000000000002',
            repeat('e', 64),
            'ee000000-0000-4000-8000-000000000003',
            '__COMPLETED_AT__',
            1,
            1
        );
        raise exception 'Unknown replay event was accepted.';
    exception
        when object_not_in_prerequisite_state then
            if sqlerrm <> 'Deletion replay event does not match the restored backup.' then
                raise;
            end if;
    end;
end;
$unknown$;
'@
    $replaySql = $replaySql.
        Replace("__SUBJECT__", $event[0]).
        Replace("__REQUEST_HASH__", $event[1]).
        Replace("__MARKER__", $event[2]).
        Replace("__COMPLETED_AT__", $event[3]).
        Replace("__EXPORT_VERSION__", $event[4]).
        Replace("__EVENT_VERSION__", $event[5])

    $replayTimer = [System.Diagnostics.Stopwatch]::StartNew()
    & $dockerPath exec $databaseContainer `
        psql -X -q -v ON_ERROR_STOP=1 -U postgres `
            -d $restoreDatabaseName -c $replaySql
    if ($LASTEXITCODE -ne 0) {
        throw "Deletion replay failed in the isolated restored database."
    }
    $replayTimer.Stop()

    $postReplayCheckSql = @"
select
    (select count(*) from auth.users where id = '$restoreUserId'),
    (select count(*) from public.companies where owner_id = '$restoreUserId'),
    (select count(*) from auth.users where id = '$witnessUserId'),
    (select count(*) from public.companies where owner_id = '$witnessUserId'),
    (
        select count(*)
        from private.account_deletion_replay_events
        where subject_token = '$($event[0])'
          and request_token_hash = '$($event[1])'
          and marker_id = '$($event[2])'
          and export_schema_version = 1
          and event_schema_version = 1
    );
"@
    $postReplayState = @(
        & $dockerPath exec $databaseContainer `
            psql -X -qAt -F "|" -v ON_ERROR_STOP=1 -U postgres `
                -d $restoreDatabaseName -c $postReplayCheckSql
    )
    if ($LASTEXITCODE -ne 0 -or
        ($postReplayState -join "").Trim() -ne "0|0|1|1|1") {
        throw "Deletion replay resurrected an account or changed the witness owner."
    }

    $restoreReport = [ordered]@{
        schemaVersion = 1
        environment = "ci-synthetic-postgresql-17"
        backupPoint = $backupPoint[0]
        backupScope = @(
            "auth",
            "public",
            "private",
            "extensions",
            "supabase_migrations"
        )
        excludedArchiveObjectTypes = @("DEFAULT ACL")
        restoredExtensions = @{
            pgcrypto = $restoredPgcryptoVersion[0]
        }
        eventCount = 1
        dumpMilliseconds = $dumpTimer.ElapsedMilliseconds
        restoreMilliseconds = $restoreTimer.ElapsedMilliseconds
        replayMilliseconds = $replayTimer.ElapsedMilliseconds
        restoredDatabaseServedBySupabaseApi = $false
        replayIdempotent = $true
        alteredEventRejected = $true
        unknownEventRejected = $true
        deletedOwnerAbsent = $true
        witnessOwnerPreserved = $true
        managedBackupProven = $false
        realUserDataUsed = $false
        result = "PASS"
    }
    Write-Output "Isolated restore replay passed:"
    Write-Output ($restoreReport | ConvertTo-Json -Compress)

    $generatedLines = @(
        & pnpm exec supabase gen types typescript `
            --local `
            --schema public `
            --network-id $testNetworkName
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Supabase type generation failed."
    }
    $generated = (($generatedLines -join "`n").TrimEnd() + "`n")
    $typesPath = Join-Path $repositoryRoot "packages/database/src/database.types.ts"
    $current = [System.IO.File]::ReadAllText($typesPath).Replace("`r`n", "`n")
    if ($generated -ne $current) {
        Write-Output "Generated database types begin (schema metadata only):"
        Write-Output $generated
        Write-Output "Generated database types end."
        throw "Generated database types are stale."
    }

    Write-Output "Backend CI passed: 2 resets, 10 pgTAP files, 190 assertions, concurrent idempotence, isolated restore replay, authoritative onboarding, stable types, loopback ports."
}
finally {
    if ($null -ne $databaseContainer -and $null -ne $dockerPath) {
        & $dockerPath exec $databaseContainer `
            dropdb -U postgres --if-exists $restoreDatabaseName *> $null
        & $dockerPath exec $databaseContainer `
            rm -f `
                $restoreBackupPath `
                $restoreJournalPath `
                $restoreListPath `
                $restoreFilteredListPath *> $null
    }
    if ($started) {
        Stop-SupabaseQuietly
    }
    if ($testNetworkCreated -and $null -ne $dockerPath) {
        & $dockerPath network rm $testNetworkName *> $null
    }
    Pop-Location
}
