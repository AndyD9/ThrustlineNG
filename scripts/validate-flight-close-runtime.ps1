#requires -Version 7.0
<#
    F0002 J2 — Validate the flight close boundary on the real local Edge Runtime.

    The script drives only public HTTP surfaces of the isolated stack started by
    scripts/start-supabase-local.ps1: the local Admin API, Auth, and the Edge
    Functions. It never modifies the schema, the seed, or a handler, it creates
    exclusively synthetic identities, and it prints no secret, JWT, email,
    identifier, or SQL detail.

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
$script:ExpectedCloseFields = @(
    "aircraftId",
    "blockMinutes",
    "closedAt",
    "currencyCode",
    "dispatchId",
    "distanceNm",
    "outcome",
    "schemaVersion",
    "settledAmountMinor",
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
    return "F0002!" + [Convert]::ToBase64String($bytes).Replace("/", "_").Replace("+", "-").Replace("=", "")
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
        [string]$UserId
    )

    $key = $script:Credentials.ServiceRoleKey
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

function New-FlightCloseBody {
    param(
        [Parameter(Mandatory)]
        [string]$DispatchId,

        [Parameter(Mandatory)]
        [string]$IdempotencyKey,

        [int]$BlockMinutes = 1,

        [string]$Outcome = "completed"
    )

    return @{
        dispatchId     = $DispatchId
        idempotencyKey = $IdempotencyKey
        report         = @{
            blockMinutes = $BlockMinutes
            outcome      = $Outcome
        }
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

$baseline = Get-EngineSqlRow -Sql (
    "select (select count(*) from public.flight_dispatches), " +
    "(select count(*) from private.flight_close_commands), " +
    "(select count(*) from private.flight_reports), " +
    "(select count(*) from private.company_reputation_events), " +
    "(select count(*) from private.financial_ledger_entries where entry_type = 'flight_settlement');"
)
Add-Check -Name "Baseline PostgreSQL state holds no dispatch, closure, report, reputation or settlement" `
    -Condition ($baseline -eq "0|0|0|0|0") `
    -Detail "observed '$baseline'; run pnpm backend:reset first"
if ($baseline -ne "0|0|0|0|0") {
    throw "Refusing to validate on a stack whose closure baseline reads '$baseline'."
}

$script:Credentials = Get-IsolatedSupabaseCredentials

$runId = [Guid]::NewGuid().ToString("N").Substring(0, 8)
$ownerEmail = "f0002-owner-$runId@thrustline.invalid"
$otherEmail = "f0002-other-$runId@thrustline.invalid"
$ownerPassword = New-SyntheticPassword
$otherPassword = New-SyntheticPassword
$ownerUserId = $null
$otherUserId = $null

try {
    $ownerUserId = New-SyntheticIdentity -Email $ownerEmail -Password $ownerPassword
    $otherUserId = New-SyntheticIdentity -Email $otherEmail -Password $otherPassword
    Add-Check -Name "Local Admin API provisions two synthetic .invalid identities" -Condition $true

    $ownerToken = Get-SyntheticSessionToken -Email $ownerEmail -Password $ownerPassword
    $otherToken = Get-SyntheticSessionToken -Email $otherEmail -Password $otherPassword
    Add-Check -Name "Both synthetic identities obtain a non-anonymous local session" -Condition $true

    $ownerCompany = Invoke-EdgeFunction -Name "company-onboarding" -BearerToken $ownerToken -RawBody (
        @{ companyName = "Synthetic F0002 Owner"; idempotencyKey = [Guid]::NewGuid().ToString() } | ConvertTo-Json -Compress
    )
    Add-Check -Name "Owner onboarding succeeds through the real Edge Runtime" `
        -Condition ($ownerCompany.Status -eq 200 -and (Get-JsonText -Value $ownerCompany.Json -Path "state") -eq "active") `
        -Detail "observed HTTP $($ownerCompany.Status)"
    $ownerCompanyId = Get-JsonText -Value $ownerCompany.Json -Path "companyId"

    $otherCompany = Invoke-EdgeFunction -Name "company-onboarding" -BearerToken $otherToken -RawBody (
        @{ companyName = "Synthetic F0002 Other"; idempotencyKey = [Guid]::NewGuid().ToString() } | ConvertTo-Json -Compress
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

    $draft = Invoke-EdgeFunction -Name "dispatch-draft" -BearerToken $ownerToken -RawBody (
        @{
            aircraftId     = $aircraftId
            arrivalIcao    = "EGLL"
            departureIcao  = "LFPG"
            idempotencyKey = [Guid]::NewGuid().ToString()
        } | ConvertTo-Json -Compress
    )
    Add-Check -Name "Owner prepares a dispatch draft through the real Edge Runtime" `
        -Condition ($draft.Status -eq 200 -and (Get-JsonText -Value $draft.Json -Path "state") -eq "draft") `
        -Detail "observed HTTP $($draft.Status)"
    $dispatchId = Get-JsonText -Value $draft.Json -Path "dispatchId"

    $start = Invoke-EdgeFunction -Name "flight-start" -BearerToken $ownerToken -RawBody (
        @{ dispatchId = $dispatchId; idempotencyKey = [Guid]::NewGuid().ToString() } | ConvertTo-Json -Compress
    )
    Add-Check -Name "Owner departs the drafted flight through the real Edge Runtime" `
        -Condition ($start.Status -eq 200 -and (Get-JsonText -Value $start.Json -Path "state") -eq "active") `
        -Detail "observed HTTP $($start.Status)"

    $privilegedValues = @($aircraftId, $ownerCompanyId, $ownerUserId, $ownerEmail)

    # Ownership refusal is exercised before any closure exists, so the rejection
    # can only come from the dispatch-to-company binding.
    $foreignClose = Invoke-EdgeFunction -Name "flight-close" -BearerToken $otherToken -RawBody (
        New-FlightCloseBody -DispatchId $dispatchId -IdempotencyKey ([Guid]::NewGuid().ToString())
    )
    Add-RedactedErrorChecks -Name "Flight close on a flight owned by another identity" `
        -Response $foreignClose -ExpectedStatus 409 -ExpectedCode "flight_close_rejected" `
        -ForbiddenValues @($ownerCompanyId, $ownerUserId, $ownerEmail, $aircraftId)

    $afterForeign = Get-EngineSqlRow -Sql (
        "select (select count(*) from public.flight_dispatches where state in ('completed', 'interrupted')), " +
        "(select count(*) from private.flight_close_commands), " +
        "(select count(*) from private.financial_ledger_entries where entry_type = 'flight_settlement');"
    )
    Add-Check -Name "Refused cross-owner closure terminates nothing and settles nothing" `
        -Condition ($afterForeign -eq "0|0|0") `
        -Detail "observed '$afterForeign'"

    $unknownClose = Invoke-EdgeFunction -Name "flight-close" -BearerToken $ownerToken -RawBody (
        New-FlightCloseBody -DispatchId ([Guid]::NewGuid().ToString()) -IdempotencyKey ([Guid]::NewGuid().ToString())
    )
    Add-RedactedErrorChecks -Name "Flight close on an unknown dispatch" `
        -Response $unknownClose -ExpectedStatus 409 -ExpectedCode "flight_close_rejected" `
        -ForbiddenValues $privilegedValues

    $foreignRaw = $foreignClose.Raw
    Add-Check -Name "Unknown and foreign closure refusals are indistinguishable" `
        -Condition (
            -not [string]::IsNullOrWhiteSpace($foreignRaw) -and
            $unknownClose.Raw -eq $foreignRaw -and
            $unknownClose.Status -eq $foreignClose.Status
        ) `
        -Detail "refusal bodies or statuses diverge, or bodies are empty"

    $forgedAmount = Invoke-EdgeFunction -Name "flight-close" -BearerToken $ownerToken -RawBody (
        @{
            dispatchId     = $dispatchId
            idempotencyKey = [Guid]::NewGuid().ToString()
            report         = @{
                blockMinutes       = 1
                outcome            = "completed"
                settledAmountMinor = 2000000
            }
        } | ConvertTo-Json -Compress
    )
    Add-RedactedErrorChecks -Name "Report carrying a forged settled amount" `
        -Response $forgedAmount -ExpectedStatus 400 -ExpectedCode "invalid_report" `
        -ForbiddenValues $privilegedValues

    $nominalKey = [Guid]::NewGuid().ToString()
    $nominalBody = New-FlightCloseBody -DispatchId $dispatchId -IdempotencyKey $nominalKey -BlockMinutes 1
    $nominal = Invoke-EdgeFunction -Name "flight-close" -BearerToken $ownerToken -RawBody $nominalBody
    Add-Check -Name "Owned active flight closes through Auth then Edge then RPC" `
        -Condition ($nominal.Status -eq 200) `
        -Detail "observed HTTP $($nominal.Status)"
    Add-Check -Name "Close response exposes exactly the ten public fields" `
        -Condition ((Get-JsonPropertyNames -Value $nominal.Json) -join "," -eq ($script:ExpectedCloseFields -join ",")) `
        -Detail "observed fields '$((Get-JsonPropertyNames -Value $nominal.Json) -join ",")'"
    $nominalState = Get-JsonText -Value $nominal.Json -Path "state"
    $nominalOutcome = Get-JsonText -Value $nominal.Json -Path "outcome"
    $nominalVersion = Get-JsonText -Value $nominal.Json -Path "schemaVersion"
    Add-Check -Name "Close response states completed and schema version 1" `
        -Condition ($nominalState -eq "completed" -and $nominalOutcome -eq "completed" -and $nominalVersion -eq "1") `
        -Detail "observed state '$nominalState', outcome '$nominalOutcome' and version '$nominalVersion'"
    Add-Check -Name "Close response carries Cache-Control no-store" `
        -Condition ($nominal.CacheControl -match "no-store") `
        -Detail "observed '$($nominal.CacheControl)'"
    Add-Check -Name "Close response echoes the requested dispatch and the purchased aircraft" `
        -Condition (
            (Get-JsonText -Value $nominal.Json -Path "dispatchId") -eq $dispatchId -and
            (Get-JsonText -Value $nominal.Json -Path "aircraftId") -eq $aircraftId
        ) `
        -Detail "response payload diverges from the request"
    $settledAmount = Get-JsonValue -Value $nominal.Json -Path "settledAmountMinor"
    $settledBlock = Get-JsonValue -Value $nominal.Json -Path "blockMinutes"
    $currencyCode = Get-JsonText -Value $nominal.Json -Path "currencyCode"
    Add-Check -Name "Close response settles a positive EUR amount within the policy cap" `
        -Condition ($null -ne $settledAmount -and [long]$settledAmount -gt 0 -and [long]$settledAmount -le 2000000 -and $currencyCode -eq "EUR") `
        -Detail "observed amount '$settledAmount' and currency '$currencyCode'"
    Add-Check -Name "Server retains min(declared, elapsed) so the settled block time never exceeds the declaration" `
        -Condition ($null -ne $settledBlock -and [int]$settledBlock -ge 0 -and [int]$settledBlock -le 1) `
        -Detail "observed settled block '$settledBlock' for a declared 1"
    $nominalClosedAt = Get-JsonText -Value $nominal.Json -Path "closedAt"
    $parsedClosedAt = [datetime]::MinValue
    Add-Check -Name "Close response timestamp is a parseable instant" `
        -Condition ([datetime]::TryParse(
                $nominalClosedAt,
                [cultureinfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::RoundtripKind,
                [ref]$parsedClosedAt)) `
        -Detail "closedAt is not parseable"
    Add-Check -Name "Close response never carries a ledger entry identifier" `
        -Condition ($nominal.Raw -notlike "*ledgerEntryId*") `
        -Detail "the public projection leaked the ledger entry identifier"

    $settlementState = Get-EngineSqlRow -Sql (
        "select (select count(*) from private.flight_close_commands), " +
        "(select count(*) from private.flight_reports), " +
        "(select count(*) from private.company_reputation_events where delta = 1), " +
        "(select count(*) from private.financial_ledger_entries where entry_type = 'flight_settlement' and amount_minor = $([long]$settledAmount)), " +
        "(select count(*) from public.flight_dispatches where state = 'completed' and closed_at is not null);"
    )
    Add-Check -Name "One command, one report, one +1 reputation event and one matching net credit are recorded" `
        -Condition ($settlementState -eq "1|1|1|1|1") `
        -Detail "observed '$settlementState'"

    $replay = Invoke-EdgeFunction -Name "flight-close" -BearerToken $ownerToken -RawBody $nominalBody
    Add-Check -Name "Replaying the same closure returns the settled response byte for byte" `
        -Condition ($replay.Status -eq 200 -and $replay.Raw -eq $nominal.Raw) `
        -Detail "observed HTTP $($replay.Status) or a diverging replay body"

    $afterReplay = Get-EngineSqlRow -Sql (
        "select (select count(*) from private.flight_close_commands), " +
        "(select count(*) from private.flight_reports), " +
        "(select count(*) from private.company_reputation_events), " +
        "(select count(*) from private.financial_ledger_entries where entry_type = 'flight_settlement');"
    )
    Add-Check -Name "Replay creates no second settlement, report, reputation event or command" `
        -Condition ($afterReplay -eq "1|1|1|1") `
        -Detail "observed '$afterReplay'"

    $missingBearer = Invoke-LocalApi -Method "POST" -Path "/functions/v1/flight-close" -RawBody $nominalBody
    Add-Check -Name "Call without a bearer token returns HTTP 401" `
        -Condition ($missingBearer.Status -eq 401) `
        -Detail "observed HTTP $($missingBearer.Status)"
    $unauthenticatedLeak = @(@($privilegedValues + @($dispatchId, $script:Credentials.ServiceRoleKey)) | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_) -and $missingBearer.Raw -like "*$_*"
        })
    Add-Check -Name "Unauthenticated refusal exposes no internal detail" `
        -Condition ($unauthenticatedLeak.Count -eq 0 -and $missingBearer.Raw.Length -le 512) `
        -Detail "$($unauthenticatedLeak.Count) forbidden value(s) or oversized body"

    $extraField = Invoke-EdgeFunction -Name "flight-close" -BearerToken $ownerToken -RawBody (
        @{
            dispatchId     = $dispatchId
            idempotencyKey = [Guid]::NewGuid().ToString()
            ownerId        = $ownerUserId
            report         = @{ blockMinutes = 1; outcome = "completed" }
        } | ConvertTo-Json -Compress
    )
    Add-RedactedErrorChecks -Name "Unsupported extra field" `
        -Response $extraField -ExpectedStatus 400 -ExpectedCode "invalid_request" `
        -ForbiddenValues $privilegedValues

    $oversizedBody = '{"dispatchId":"' + $dispatchId + '","idempotencyKey":"' +
        [Guid]::NewGuid().ToString() + '","report":{"blockMinutes":1,"outcome":"completed","padding":"' + ("x" * 5000) + '"}}'
    $oversized = Invoke-EdgeFunction -Name "flight-close" -BearerToken $ownerToken -RawBody $oversizedBody
    Add-RedactedErrorChecks -Name "Five-kilobyte body" `
        -Response $oversized -ExpectedStatus 413 -ExpectedCode "request_too_large" `
        -ForbiddenValues $privilegedValues

    $alreadyClosed = Invoke-EdgeFunction -Name "flight-close" -BearerToken $ownerToken -RawBody (
        New-FlightCloseBody -DispatchId $dispatchId -IdempotencyKey ([Guid]::NewGuid().ToString())
    )
    Add-RedactedErrorChecks -Name "Second closure of the already closed flight with a new key" `
        -Response $alreadyClosed -ExpectedStatus 409 -ExpectedCode "flight_close_rejected" `
        -ForbiddenValues @($dispatchId, $ownerCompanyId, $ownerUserId, $ownerEmail)
    Add-Check -Name "Already closed refusal is indistinguishable from unknown and foreign" `
        -Condition ($alreadyClosed.Raw -eq $foreignRaw) `
        -Detail "the already-closed refusal body diverges from the other refusals"

    $redispatch = Invoke-EdgeFunction -Name "dispatch-draft" -BearerToken $ownerToken -RawBody (
        @{
            aircraftId     = $aircraftId
            arrivalIcao    = "LFPG"
            departureIcao  = "EGLL"
            idempotencyKey = [Guid]::NewGuid().ToString()
        } | ConvertTo-Json -Compress
    )
    Add-Check -Name "Closed aircraft becomes dispatchable again through the real Edge Runtime" `
        -Condition ($redispatch.Status -eq 200 -and (Get-JsonText -Value $redispatch.Json -Path "state") -eq "draft") `
        -Detail "observed HTTP $($redispatch.Status)"

    $finalState = Get-EngineSqlRow -Sql (
        "select (select count(*) from public.flight_dispatches), " +
        "(select count(*) from public.flight_dispatches where state = 'completed'), " +
        "(select count(*) from public.flight_dispatches where state = 'draft'), " +
        "(select count(*) from private.flight_close_commands), " +
        "(select count(*) from private.financial_ledger_entries where entry_type = 'flight_settlement'), " +
        "(select count(*) from public.flight_dispatches as d join public.companies as c on c.id = d.company_id " +
        "join auth.users as u on u.id = c.owner_id where u.email = '$ownerEmail' and d.state = 'completed');"
    )
    Add-Check -Name "Final PostgreSQL state is one completed flight, one new draft, one settlement, owned by the Auth subject" `
        -Condition ($finalState -eq "2|1|1|1|1|1") `
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

    $residual = Get-EngineSqlRow -Sql "select count(*) from auth.users where email like 'f0002-%@thrustline.invalid';"
    Add-Check -Name "Synthetic identities are confined to the disposable stack awaiting its destruction" `
        -Condition ($residual -eq [string]$provisionedIdentities.Count) `
        -Detail "observed '$residual' for $($provisionedIdentities.Count) provisioned identities"

    $ownerPassword = $null
    $otherPassword = $null
    $script:Credentials = $null
    [System.GC]::Collect()
}

Write-Output "F0002 J2 flight close runtime validation"
foreach ($check in $script:Checks) {
    Write-Output "  $check"
}
Write-Output "  ---"
Write-Output "  checks: $($script:Checks.Count), failures: $script:FailureCount"
Write-Output "  next: pnpm backend:reset before pnpm backend:test, then pnpm backend:stop to destroy the synthetic state."

if ($script:FailureCount -gt 0) {
    throw "The flight close runtime validation failed $script:FailureCount check(s)."
}
