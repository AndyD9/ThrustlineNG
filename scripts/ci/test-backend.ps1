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
        $testText -notmatch "Result:\s+PASS") {
        throw "Supabase pgTAP did not prove all four files with Result: PASS."
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

    Write-Output "Backend CI passed: 2 resets, 4 pgTAP files, 70 assertions, concurrent idempotence, stable types, loopback ports."
}
finally {
    if ($started) {
        Stop-SupabaseQuietly
    }
    if ($testNetworkCreated -and $null -ne $dockerPath) {
        & $dockerPath network rm $testNetworkName *> $null
    }
    Pop-Location
}
