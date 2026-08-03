#requires -Version 7.0
<#
    T0049 — Validate the dispatch draft boundary on the real local Edge Runtime.

    The script drives only public HTTP surfaces of the isolated stack started by
    scripts/start-supabase-local.ps1: the local Admin API, Auth, and the three
    Edge Functions. It never modifies the schema, the seed, or a handler, it
    creates exclusively synthetic identities, and it prints no secret, JWT,
    email, identifier, or SQL detail.

    Run it on a freshly reset stack (pnpm backend:reset), then destroy that stack
    (pnpm backend:stop): destroying the disposable volume is what removes the
    synthetic identities, because an identity owning a company cannot be
    hard-deleted through the Admin API.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "docker-tools.ps1")
. (Join-Path $PSScriptRoot "supabase-local-runtime.ps1")

# Seeded synthetic offer priced below the canonical company opening amount.
$script:AffordableOfferId = "e1000000-0000-4000-8000-000000000001"
$script:BaseUrl = "http://127.0.0.1:54321"
$script:DatabaseContainer = "supabase_db_thrustline-ng"
$script:ExpectedDraftFields = @(
    "aircraftId",
    "arrivalIcao",
    "createdAt",
    "departureIcao",
    "dispatchId",
    "schemaVersion",
    "state"
)

$script:Checks = [System.Collections.Generic.List[string]]::new()
$script:FailureCount = 0

function Add-Check {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [bool]$Condition,

        [string]$Detail = ""
    )

    if ($Condition) {
        $script:Checks.Add("PASS  $Name")
        return
    }
    $suffix = if ([string]::IsNullOrWhiteSpace($Detail)) { "" } else { " — $Detail" }
    $script:Checks.Add("FAIL  $Name$suffix")
    $script:FailureCount++
}

function New-SyntheticPassword {
    $bytes = [byte[]]::new(32)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    return "Tl0049!" + [Convert]::ToBase64String($bytes).Replace("/", "_").Replace("+", "-").Replace("=", "")
}

function Get-HeaderValue {
    param(
        [Parameter(Mandatory)]
        $Response,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $Response.Headers -or -not $Response.Headers.ContainsKey($Name)) {
        return ""
    }
    return (@($Response.Headers[$Name]) -join ",")
}

function Invoke-LocalApi {
    param(
        [Parameter(Mandatory)]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$Path,

        [hashtable]$Headers = @{},

        [string]$RawBody
    )

    $arguments = @{
        Method             = $Method
        Uri                = "$script:BaseUrl$Path"
        Headers            = $Headers
        SkipHttpErrorCheck = $true
        MaximumRedirection = 0
        TimeoutSec         = 30
    }
    if ($PSBoundParameters.ContainsKey("RawBody")) {
        $arguments.ContentType = "application/json; charset=utf-8"
        $arguments.Body = $RawBody
    }

    $response = Invoke-WebRequest @arguments
    $content = [string]$response.Content
    $parsed = $null
    if (-not [string]::IsNullOrWhiteSpace($content)) {
        try {
            $parsed = $content | ConvertFrom-Json
        }
        catch {
            $parsed = $null
        }
    }

    return [pscustomobject]@{
        Status       = [int]$response.StatusCode
        Json         = $parsed
        Raw          = $content
        CacheControl = Get-HeaderValue -Response $response -Name "Cache-Control"
    }
}

function Get-EngineSqlRow {
    param(
        [Parameter(Mandatory)]
        [string]$Sql
    )

    $output = @(
        & $script:DockerPath exec $script:SupabaseEngineContainer `
            docker exec $script:DatabaseContainer `
            psql -U postgres -d postgres -Atq -c $Sql 2>&1
    )
    if ($LASTEXITCODE -ne 0) {
        throw "PostgreSQL inspection failed inside the isolated runtime."
    }
    $rows = @($output | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($rows.Count -ne 1) {
        throw "PostgreSQL inspection returned $($rows.Count) rows instead of one."
    }
    return [string]$rows[0]
}

function Get-JsonPropertyNames {
    param($Value)

    if ($null -eq $Value) {
        return @()
    }
    return @($Value.PSObject.Properties | ForEach-Object { $_.Name } | Sort-Object)
}

function Get-JsonValue {
    param(
        $Value,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $current = $Value
    foreach ($segment in $Path.Split(".")) {
        if ($null -eq $current) {
            return $null
        }
        $property = $current.PSObject.Properties[$segment]
        if ($null -eq $property) {
            return $null
        }
        $current = $property.Value
    }
    return $current
}

function Get-JsonText {
    param(
        $Value,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $raw = Get-JsonValue -Value $Value -Path $Path
    if ($null -eq $raw) {
        return ""
    }
    return [string]$raw
}

function Add-RedactedErrorChecks {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        $Response,

        [Parameter(Mandatory)]
        [int]$ExpectedStatus,

        [string]$ExpectedCode,

        [string[]]$ForbiddenValues = @()
    )

    Add-Check -Name "$Name returns HTTP $ExpectedStatus" `
        -Condition ($Response.Status -eq $ExpectedStatus) `
        -Detail "observed HTTP $($Response.Status)"

    if (-not [string]::IsNullOrWhiteSpace($ExpectedCode)) {
        $observedCode = Get-JsonText -Value $Response.Json -Path "error.code"
        Add-Check -Name "$Name reports the public error code" `
            -Condition ($observedCode -eq $ExpectedCode) `
            -Detail "observed code '$observedCode'"

        $bodyFields = (Get-JsonPropertyNames -Value $Response.Json) -join ","
        $errorFields = (Get-JsonPropertyNames -Value (Get-JsonValue -Value $Response.Json -Path "error")) -join ","
        Add-Check -Name "$Name body carries only code and message" `
            -Condition ($bodyFields -eq "error" -and $errorFields -eq "code,message") `
            -Detail "observed '$bodyFields' and '$errorFields'"
    }

    $leaked = @($ForbiddenValues | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_) -and $Response.Raw -like "*$_*"
        })
    Add-Check -Name "$Name leaks no privileged value" `
        -Condition ($leaked.Count -eq 0) `
        -Detail "$($leaked.Count) forbidden value(s) present in the response body"
}

function Get-IsolatedSupabaseCredentials {
    $dockerArguments = @(
        "run",
        "--rm",
        "--network", $script:SupabaseControlNetwork,
        "--env", "DOCKER_HOST=tcp://$($script:SupabaseEngineContainer):2375",
        "--env", "DO_NOT_TRACK=1",
        "--env", "SUPABASE_TELEMETRY_DISABLED=1",
        "--volume", "${script:SupabaseProjectVolume}:/workspace",
        "--workdir", "/workspace",
        $script:SupabaseCliImage,
        "status",
        "-o", "env"
    )

    $output = @(& $script:DockerPath @dockerArguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to read the isolated Supabase runtime status."
    }

    $values = @{}
    foreach ($line in $output) {
        $match = [regex]::Match([string]$line, '^([A-Z0-9_]+)="(.*)"$')
        if ($match.Success) {
            $values[$match.Groups[1].Value] = $match.Groups[2].Value
        }
    }
    if (-not $values.ContainsKey("ANON_KEY") -or -not $values.ContainsKey("SERVICE_ROLE_KEY")) {
        throw "The isolated Supabase runtime did not expose the expected local keys."
    }
    # The CLI advertises container-internal URLs; the host reaches the stack only
    # through the republished IPv4 loopback port.
    return [pscustomobject]@{
        AnonKey        = $values["ANON_KEY"]
        ServiceRoleKey = $values["SERVICE_ROLE_KEY"]
    }
}

function New-SyntheticIdentity {
    param(
        [Parameter(Mandatory)]
        [string]$Email,

        [Parameter(Mandatory)]
        [string]$Password
    )

    $body = @{ email = $Email; password = $Password; email_confirm = $true } |
        ConvertTo-Json -Compress
    $response = Invoke-LocalApi -Method "POST" -Path "/auth/v1/admin/users" -Headers @{
        apikey        = $script:Credentials.ServiceRoleKey
        authorization = "Bearer $($script:Credentials.ServiceRoleKey)"
    } -RawBody $body

    $userId = Get-JsonText -Value $response.Json -Path "id"
    if ($response.Status -ne 200 -or [string]::IsNullOrWhiteSpace($userId)) {
        throw "The local Admin API did not provision a synthetic identity (HTTP $($response.Status))."
    }
    return $userId
}

function Remove-SyntheticIdentity {
    param(
        [Parameter(Mandatory)]
        [string]$UserId,

        [switch]$UseAnonKey
    )

    $key = if ($UseAnonKey) { $script:Credentials.AnonKey } else { $script:Credentials.ServiceRoleKey }
    return Invoke-LocalApi -Method "DELETE" -Path "/auth/v1/admin/users/$UserId" -Headers @{
        apikey        = $key
        authorization = "Bearer $key"
    }
}

function Get-SyntheticSessionToken {
    param(
        [Parameter(Mandatory)]
        [string]$Email,

        [Parameter(Mandatory)]
        [string]$Password
    )

    $body = @{ email = $Email; password = $Password } | ConvertTo-Json -Compress
    $response = Invoke-LocalApi -Method "POST" -Path "/auth/v1/token?grant_type=password" -Headers @{
        apikey = $script:Credentials.AnonKey
    } -RawBody $body

    $accessToken = Get-JsonText -Value $response.Json -Path "access_token"
    if ($response.Status -ne 200 -or [string]::IsNullOrWhiteSpace($accessToken)) {
        throw "The local Auth provider refused a synthetic password sign-in (HTTP $($response.Status))."
    }
    return $accessToken
}

function Invoke-EdgeFunction {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$RawBody,

        [string]$BearerToken
    )

    $headers = @{}
    if ($PSBoundParameters.ContainsKey("BearerToken")) {
        $headers.apikey = $script:Credentials.AnonKey
        $headers.authorization = "Bearer $BearerToken"
    }
    return Invoke-LocalApi -Method "POST" -Path "/functions/v1/$Name" -Headers $headers -RawBody $RawBody
}

function New-DispatchDraftBody {
    param(
        [Parameter(Mandatory)]
        [string]$AircraftId,

        [Parameter(Mandatory)]
        [string]$DepartureIcao,

        [Parameter(Mandatory)]
        [string]$ArrivalIcao,

        [Parameter(Mandatory)]
        [string]$IdempotencyKey
    )

    return @{
        aircraftId     = $AircraftId
        arrivalIcao    = $ArrivalIcao
        departureIcao  = $DepartureIcao
        idempotencyKey = $IdempotencyKey
    } | ConvertTo-Json -Compress
}

$script:DockerPath = Get-DockerCliPath
Enable-DockerCliForProcess -DockerPath $script:DockerPath

if (-not (Test-DockerResourceExists `
            -ResourceType container `
            -Name $script:SupabaseEngineContainer `
            -DockerPath $script:DockerPath)) {
    throw "The isolated Supabase runtime is not running. Run pnpm backend:start first."
}

Assert-SupabaseOuterBindings -DockerPath $script:DockerPath
Add-Check -Name "Isolated engine publishes only 54321-54323 on 127.0.0.1 before any call" -Condition $true

$loadedFunctions = @(
    & $script:DockerPath exec $script:SupabaseEngineContainer `
        docker ps --filter "name=supabase_edge_runtime_thrustline-ng" --format "{{.Names}}" 2>&1
)
Add-Check -Name "Local Edge Runtime container is running" `
    -Condition ($loadedFunctions -contains "supabase_edge_runtime_thrustline-ng") `
    -Detail "edge runtime container not found"

$baseline = Get-EngineSqlRow -Sql "select (select count(*) from public.flight_dispatches), (select count(*) from private.dispatch_draft_commands);"
Add-Check -Name "Baseline PostgreSQL state holds no dispatch and no command" `
    -Condition ($baseline -eq "0|0") `
    -Detail "observed '$baseline'; run pnpm backend:reset first"
if ($baseline -ne "0|0") {
    throw "Refusing to validate on a stack whose dispatch baseline reads '$baseline'."
}

$script:Credentials = Get-IsolatedSupabaseCredentials

$runId = [Guid]::NewGuid().ToString("N").Substring(0, 8)
$ownerEmail = "t0049-owner-$runId@thrustline.invalid"
$otherEmail = "t0049-other-$runId@thrustline.invalid"
$ownerPassword = New-SyntheticPassword
$otherPassword = New-SyntheticPassword
$ownerUserId = $null
$otherUserId = $null

try {
    $ownerUserId = New-SyntheticIdentity -Email $ownerEmail -Password $ownerPassword
    $otherUserId = New-SyntheticIdentity -Email $otherEmail -Password $otherPassword
    Add-Check -Name "Local Admin API provisions two synthetic .invalid identities" -Condition $true

    $signupProbe = Invoke-LocalApi -Method "POST" -Path "/auth/v1/signup" -Headers @{
        apikey = $script:Credentials.AnonKey
    } -RawBody (@{ email = "t0049-signup-$runId@thrustline.invalid"; password = $ownerPassword } | ConvertTo-Json -Compress)
    Add-Check -Name "Public sign-up stays closed on the local stack" `
        -Condition ($signupProbe.Status -ge 400) `
        -Detail "observed HTTP $($signupProbe.Status)"

    $ownerToken = Get-SyntheticSessionToken -Email $ownerEmail -Password $ownerPassword
    $otherToken = Get-SyntheticSessionToken -Email $otherEmail -Password $otherPassword
    Add-Check -Name "Both synthetic identities obtain a non-anonymous local session" -Condition $true

    $ownerCompany = Invoke-EdgeFunction -Name "company-onboarding" -BearerToken $ownerToken -RawBody (
        @{ companyName = "Synthetic T0049 Owner"; idempotencyKey = [Guid]::NewGuid().ToString() } | ConvertTo-Json -Compress
    )
    Add-Check -Name "Owner onboarding succeeds through the real Edge Runtime" `
        -Condition ($ownerCompany.Status -eq 200 -and (Get-JsonText -Value $ownerCompany.Json -Path "state") -eq "active") `
        -Detail "observed HTTP $($ownerCompany.Status)"
    $ownerCompanyId = Get-JsonText -Value $ownerCompany.Json -Path "companyId"

    $otherCompany = Invoke-EdgeFunction -Name "company-onboarding" -BearerToken $otherToken -RawBody (
        @{ companyName = "Synthetic T0049 Other"; idempotencyKey = [Guid]::NewGuid().ToString() } | ConvertTo-Json -Compress
    )
    Add-Check -Name "Second identity onboarding succeeds through the real Edge Runtime" `
        -Condition ($otherCompany.Status -eq 200 -and (Get-JsonText -Value $otherCompany.Json -Path "state") -eq "active") `
        -Detail "observed HTTP $($otherCompany.Status)"

    $purchase = Invoke-EdgeFunction -Name "aircraft-purchase" -BearerToken $ownerToken -RawBody (
        @{ offerId = $script:AffordableOfferId; idempotencyKey = [Guid]::NewGuid().ToString() } | ConvertTo-Json -Compress
    )
    Add-Check -Name "Owner buys the seeded affordable aircraft through the real Edge Runtime" `
        -Condition ($purchase.Status -eq 200 -and (Get-JsonText -Value $purchase.Json -Path "state") -eq "owned") `
        -Detail "observed HTTP $($purchase.Status)"
    $aircraftId = Get-JsonText -Value $purchase.Json -Path "aircraftId"

    $privilegedValues = @($aircraftId, $ownerCompanyId, $ownerUserId, $ownerEmail)

    # Ownership refusal is exercised before any draft exists, so the rejection can
    # only come from the aircraft-to-company binding.
    $foreignAircraft = Invoke-EdgeFunction -Name "dispatch-draft" -BearerToken $otherToken -RawBody (
        New-DispatchDraftBody -AircraftId $aircraftId -DepartureIcao "LFPG" -ArrivalIcao "EGLL" `
            -IdempotencyKey ([Guid]::NewGuid().ToString())
    )
    Add-RedactedErrorChecks -Name "Dispatch on an aircraft owned by another identity" `
        -Response $foreignAircraft -ExpectedStatus 409 -ExpectedCode "dispatch_rejected" `
        -ForbiddenValues @($ownerCompanyId, $ownerUserId, $ownerEmail)

    $afterForeign = Get-EngineSqlRow -Sql "select count(*) from public.flight_dispatches;"
    Add-Check -Name "Refused cross-owner dispatch creates no row" `
        -Condition ($afterForeign -eq "0") `
        -Detail "observed '$afterForeign'"

    $unknownAircraft = Invoke-EdgeFunction -Name "dispatch-draft" -BearerToken $ownerToken -RawBody (
        New-DispatchDraftBody -AircraftId ([Guid]::NewGuid().ToString()) -DepartureIcao "LFPG" -ArrivalIcao "EGLL" `
            -IdempotencyKey ([Guid]::NewGuid().ToString())
    )
    Add-RedactedErrorChecks -Name "Dispatch on an unknown aircraft" `
        -Response $unknownAircraft -ExpectedStatus 409 -ExpectedCode "dispatch_rejected" `
        -ForbiddenValues $privilegedValues

    $nominalKey = [Guid]::NewGuid().ToString()
    $nominalBody = New-DispatchDraftBody -AircraftId $aircraftId -DepartureIcao "LFPG" -ArrivalIcao "EGLL" `
        -IdempotencyKey $nominalKey
    $nominal = Invoke-EdgeFunction -Name "dispatch-draft" -BearerToken $ownerToken -RawBody $nominalBody
    Add-Check -Name "Owned aircraft receives a draft through Auth then Edge then RPC" `
        -Condition ($nominal.Status -eq 200) `
        -Detail "observed HTTP $($nominal.Status)"
    Add-Check -Name "Draft response exposes exactly the seven public fields" `
        -Condition ((Get-JsonPropertyNames -Value $nominal.Json) -join "," -eq ($script:ExpectedDraftFields -join ",")) `
        -Detail "observed fields '$((Get-JsonPropertyNames -Value $nominal.Json) -join ",")'"
    $nominalState = Get-JsonText -Value $nominal.Json -Path "state"
    $nominalVersion = Get-JsonText -Value $nominal.Json -Path "schemaVersion"
    Add-Check -Name "Draft response states draft and schema version 1" `
        -Condition ($nominalState -eq "draft" -and $nominalVersion -eq "1") `
        -Detail "observed state '$nominalState' and version '$nominalVersion'"
    Add-Check -Name "Draft response carries Cache-Control no-store" `
        -Condition ($nominal.CacheControl -match "no-store") `
        -Detail "observed '$($nominal.CacheControl)'"
    Add-Check -Name "Draft response echoes the requested aircraft and both airports" `
        -Condition (
            (Get-JsonText -Value $nominal.Json -Path "aircraftId") -eq $aircraftId -and
            (Get-JsonText -Value $nominal.Json -Path "departureIcao") -eq "LFPG" -and
            (Get-JsonText -Value $nominal.Json -Path "arrivalIcao") -eq "EGLL"
        ) `
        -Detail "response payload diverges from the request"
    $nominalCreatedAt = Get-JsonText -Value $nominal.Json -Path "createdAt"
    $parsedCreatedAt = [datetime]::MinValue
    Add-Check -Name "Draft response timestamp is a parseable instant" `
        -Condition ([datetime]::TryParse(
                $nominalCreatedAt,
                [cultureinfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::RoundtripKind,
                [ref]$parsedCreatedAt)) `
        -Detail "createdAt is not parseable"
    $dispatchId = Get-JsonText -Value $nominal.Json -Path "dispatchId"

    $replay = Invoke-EdgeFunction -Name "dispatch-draft" -BearerToken $ownerToken -RawBody $nominalBody
    Add-Check -Name "Replaying the same intent returns the same dispatch identifier" `
        -Condition (
            $replay.Status -eq 200 -and
            (Get-JsonText -Value $replay.Json -Path "dispatchId") -eq $dispatchId -and
            (Get-JsonText -Value $replay.Json -Path "createdAt") -eq $nominalCreatedAt
        ) `
        -Detail "observed HTTP $($replay.Status)"

    $missingBearer = Invoke-LocalApi -Method "POST" -Path "/functions/v1/dispatch-draft" -RawBody $nominalBody
    Add-Check -Name "Call without a bearer token returns HTTP 401" `
        -Condition ($missingBearer.Status -eq 401) `
        -Detail "observed HTTP $($missingBearer.Status)"
    $unauthenticatedLeak = @(@($privilegedValues + @($dispatchId, $script:Credentials.ServiceRoleKey)) | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_) -and $missingBearer.Raw -like "*$_*"
        })
    Add-Check -Name "Unauthenticated refusal exposes no internal detail" `
        -Condition ($unauthenticatedLeak.Count -eq 0 -and $missingBearer.Raw.Length -le 512) `
        -Detail "$($unauthenticatedLeak.Count) forbidden value(s) or oversized body"

    $extraField = Invoke-EdgeFunction -Name "dispatch-draft" -BearerToken $ownerToken -RawBody (
        @{
            aircraftId     = $aircraftId
            arrivalIcao    = "EGLL"
            departureIcao  = "LFPG"
            idempotencyKey = [Guid]::NewGuid().ToString()
            state          = "active"
        } | ConvertTo-Json -Compress
    )
    Add-RedactedErrorChecks -Name "Unsupported extra field" `
        -Response $extraField -ExpectedStatus 400 -ExpectedCode "invalid_request" `
        -ForbiddenValues $privilegedValues

    $invalidIcao = Invoke-EdgeFunction -Name "dispatch-draft" -BearerToken $ownerToken -RawBody (
        New-DispatchDraftBody -AircraftId $aircraftId -DepartureIcao "LF1" -ArrivalIcao "EGLL" `
            -IdempotencyKey ([Guid]::NewGuid().ToString())
    )
    Add-RedactedErrorChecks -Name "Malformed ICAO code" `
        -Response $invalidIcao -ExpectedStatus 400 -ExpectedCode "invalid_airports" `
        -ForbiddenValues $privilegedValues

    $identicalIcao = Invoke-EdgeFunction -Name "dispatch-draft" -BearerToken $ownerToken -RawBody (
        New-DispatchDraftBody -AircraftId $aircraftId -DepartureIcao "LFPG" -ArrivalIcao "LFPG" `
            -IdempotencyKey ([Guid]::NewGuid().ToString())
    )
    Add-RedactedErrorChecks -Name "Identical departure and arrival" `
        -Response $identicalIcao -ExpectedStatus 400 -ExpectedCode "invalid_airports" `
        -ForbiddenValues $privilegedValues

    $secondDraft = Invoke-EdgeFunction -Name "dispatch-draft" -BearerToken $ownerToken -RawBody (
        New-DispatchDraftBody -AircraftId $aircraftId -DepartureIcao "LFPO" -ArrivalIcao "EGKK" `
            -IdempotencyKey ([Guid]::NewGuid().ToString())
    )
    Add-RedactedErrorChecks -Name "Second draft on the same aircraft with a new key" `
        -Response $secondDraft -ExpectedStatus 409 -ExpectedCode "dispatch_rejected" `
        -ForbiddenValues @($dispatchId, $ownerCompanyId, $ownerUserId, $ownerEmail)

    $finalState = Get-EngineSqlRow -Sql (
        "select (select count(*) from public.flight_dispatches), " +
        "(select count(*) from private.dispatch_draft_commands), " +
        "(select count(*) from public.flight_dispatches where state = 'draft'), " +
        "(select count(*) from public.flight_dispatches as d join public.companies as c on c.id = d.company_id " +
        "join auth.users as u on u.id = c.owner_id where u.email = '$ownerEmail');"
    )
    Add-Check -Name "Final PostgreSQL state is one draft and one command owned by the Auth subject" `
        -Condition ($finalState -eq "1|1|1|1") `
        -Detail "observed '$finalState'"

    Assert-SupabaseOuterBindings -DockerPath $script:DockerPath
    Add-Check -Name "Isolated engine still publishes only 54321-54323 on 127.0.0.1 after the run" -Condition $true
}
finally {
    # An identity that owns a company cannot be hard-deleted: companies_owner_id_fkey
    # deliberately refuses to orphan a company, and the authoritative removal path is
    # the T0018 account lifecycle rather than the Admin API. Destroying the disposable
    # stack is therefore what removes these identities, so pnpm backend:stop must
    # follow this script.
    $provisionedIdentities = @(@($ownerUserId, $otherUserId) | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        })
    $ownershipRefusals = 0
    foreach ($userId in $provisionedIdentities) {
        $deletion = Remove-SyntheticIdentity -UserId $userId
        if ($deletion.Status -eq 500 -and (Get-JsonText -Value $deletion.Json -Path "code") -eq "23503") {
            $ownershipRefusals++
        }
    }
    Add-Check -Name "Local Admin API refuses to orphan a company by hard-deleting its owner" `
        -Condition ($provisionedIdentities.Count -gt 0 -and $ownershipRefusals -eq $provisionedIdentities.Count) `
        -Detail "$ownershipRefusals of $($provisionedIdentities.Count) deletions refused by the ownership constraint"

    if ($provisionedIdentities.Count -gt 0) {
        $anonymousAttempt = Remove-SyntheticIdentity -UserId $provisionedIdentities[0] -UseAnonKey
        Add-Check -Name "The verbose Admin API refusal stays behind the privileged key" `
            -Condition (
                @(401, 403) -contains $anonymousAttempt.Status -and
                $anonymousAttempt.Raw -notlike "*23503*" -and
                $anonymousAttempt.Raw -notlike "*companies*"
            ) `
            -Detail "observed HTTP $($anonymousAttempt.Status)"
    }

    $residual = Get-EngineSqlRow -Sql "select count(*) from auth.users where email like 't0049-%@thrustline.invalid';"
    Add-Check -Name "Synthetic identities are confined to the disposable stack awaiting its destruction" `
        -Condition ($residual -eq [string]$provisionedIdentities.Count) `
        -Detail "observed '$residual' for $($provisionedIdentities.Count) provisioned identities"

    $ownerPassword = $null
    $otherPassword = $null
    $script:Credentials = $null
    [System.GC]::Collect()
}

Write-Output "T0049 dispatch draft runtime validation"
foreach ($check in $script:Checks) {
    Write-Output "  $check"
}
Write-Output "  ---"
Write-Output "  checks: $($script:Checks.Count), failures: $script:FailureCount"
Write-Output "  next: pnpm backend:reset before pnpm backend:test, then pnpm backend:stop to destroy the synthetic state."

if ($script:FailureCount -gt 0) {
    throw "The dispatch draft runtime validation failed $script:FailureCount check(s)."
}
