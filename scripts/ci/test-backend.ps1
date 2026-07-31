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

    Write-Output "Backend CI passed: 2 resets, 4 pgTAP files, PASS, stable types, loopback ports."
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
