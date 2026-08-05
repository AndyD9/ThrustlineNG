[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$selectorPath = Join-Path $repositoryRoot 'scripts/select-ticket-batch.ps1'
if (-not (Test-Path -LiteralPath $selectorPath -PathType Leaf)) {
    throw "Missing selector script: $selectorPath"
}

$hostExecutable = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
$assertionCount = 0
$failures = [System.Collections.Generic.List[string]]::new()

# Ticket files are LF in the repository (`.gitattributes`: `*.md text eol=lf`), so
# the fixture must be LF too. `Set-Content` writes CRLF on Windows, and in .NET a
# `$` anchor under `(?m)` matches before `\n` but never before `\r\n`: a mutation
# pattern such as '^Status: Ready$' then silently matches nothing. This script is
# itself stored with CRLF, so its here-strings carry CRLF and must be normalised.
function Set-FixtureText {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )

    $normalised = $Text -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($Path, $normalised, (New-Object System.Text.UTF8Encoding($false)))
}

function New-TicketFile {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Dependencies,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$AllowedAreas
    )

    $dependencyBlock = if ($Dependencies.Count -eq 0) {
        "- Aucune."
    }
    else {
        ($Dependencies | ForEach-Object { "- $_" }) -join "`n"
    }
    $allowedBlock = ($AllowedAreas | ForEach-Object { "- ``$_``" }) -join "`n"

    return @"
# $Id - Fixture ticket $Id

Status: $Status
Owner: Fixture
Branch: ``chore/$($Id.ToLowerInvariant())-fixture``
Phase: 1
Risk: Low
Security-sensitive: No

## Goal

Resultat observable de la fixture $Id.

## Dependencies

$dependencyBlock

## Allowed areas

$allowedBlock

## Do not touch

- Tout le reste.

## Requirements

- Aucune exigence reelle.

## Acceptance criteria

- [ ] Fixture only.
"@
}

function New-Fixture {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("ticket-automation-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path (Join-Path $root 'docs/tickets') | Out-Null

    $definitions = @(
        [pscustomobject]@{
            Id = 'T0001'; Title = 'Fixture baseline'; Status = 'Done'
            Dependencies = @(); AllowedAreas = @('apps/bridge')
        },
        [pscustomobject]@{
            Id = 'T0002'; Title = 'Fixture desktop slice'; Status = 'Ready'
            Dependencies = @('T0001'); AllowedAreas = @('apps/desktop/src/features/alpha', 'docs/tickets/README.md')
        },
        [pscustomobject]@{
            Id = 'T0003'; Title = 'Fixture backend slice'; Status = 'Ready'
            Dependencies = @('T0001'); AllowedAreas = @('supabase/migrations', 'docs/tickets/README.md')
        },
        [pscustomobject]@{
            Id = 'T0004'; Title = 'Fixture bridge slice'; Status = 'Ready'
            Dependencies = @('T0001'); AllowedAreas = @('apps/bridge/src/Telemetry', 'docs/tickets/README.md')
        },
        [pscustomobject]@{
            Id = 'T0005'; Title = 'Fixture fourth slice'; Status = 'Ready'
            Dependencies = @('T0001'); AllowedAreas = @('tests/fixture-only', 'docs/tickets/README.md')
        }
    )

    $rows = foreach ($definition in $definitions) {
        $dependencyCell = if ($definition.Dependencies.Count -eq 0) { '-' } else { $definition.Dependencies -join ', ' }
        "| $($definition.Id) | $($definition.Title) | 1 | $dependencyCell | $($definition.Status) |"
    }

    $index = @(
        '# Tickets de fixture',
        '',
        '| ID | Titre | Phase | Depend de | Statut |',
        '| --- | --- | --- | --- | --- |'
    ) + $rows
    Set-FixtureText -Path (Join-Path $root 'docs/tickets/README.md') -Text (($index -join "`n") + "`n")

    foreach ($definition in $definitions) {
        $content = New-TicketFile `
            -Id $definition.Id `
            -Status $definition.Status `
            -Dependencies $definition.Dependencies `
            -AllowedAreas $definition.AllowedAreas
        $fileName = "$($definition.Id)-fixture.md"
        Set-FixtureText -Path (Join-Path $root "docs/tickets/$fileName") -Text $content
    }

    return $root
}

function Invoke-Selector {
    param(
        [Parameter(Mandatory)][string]$Root,
        [string[]]$AdditionalArguments = @()
    )

    $arguments = @('-NoProfile', '-File', $selectorPath, '-Root', $Root, '-Json') + $AdditionalArguments
    $output = & $hostExecutable @arguments 2>&1
    $exitCode = $LASTEXITCODE
    $text = ($output | Out-String)
    $report = $null
    try {
        $report = $text | ConvertFrom-Json
    }
    catch {
        $report = $null
    }
    return [pscustomobject]@{ ExitCode = $exitCode; Text = $text; Report = $report }
}

function Set-TicketField {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Replacement
    )

    $path = Join-Path $Root "docs/tickets/$Id-fixture.md"
    $text = [System.IO.File]::ReadAllText($path)
    $mutated = [regex]::Replace($text, $Pattern, $Replacement)
    # Fail closed: a negative scenario whose mutation changes nothing proves
    # nothing, and it would report as a selector defect instead of a test defect.
    if ($mutated -eq $text) {
        throw "Pattern '$Pattern' changed nothing in $Id; the mutation would prove nothing."
    }
    Set-FixtureText -Path $path -Text $mutated
}

function Set-IndexStatus {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Status
    )

    $path = Join-Path $Root 'docs/tickets/README.md'
    $lines = @(Get-Content -Encoding UTF8 -LiteralPath $path)
    $touched = 0
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -notmatch "^\|\s*$Id\s*\|") {
            continue
        }
        $cells = @($lines[$index].Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        $cells[4] = $Status
        $lines[$index] = '| ' + ($cells -join ' | ') + ' |'
        $touched++
    }
    if ($touched -eq 0) {
        throw "No index row matched $Id; the mutation would prove nothing."
    }
    Set-FixtureText -Path $path -Text (($lines -join "`n") + "`n")
}

function Assert-Condition {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Detail
    )

    $script:assertionCount++
    if (-not $Condition) {
        $script:failures.Add("${Label}: $Detail")
    }
}

function Assert-Scenario {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][scriptblock]$Mutate,
        [int]$ExpectedExitCode = 0,
        [string]$ExpectedBlockingPattern = '',
        [string[]]$ExpectedSelected = @(),
        [string]$ExpectedDeferredPattern = '',
        [string]$ExpectedDeferredId = '',
        [string[]]$AdditionalArguments = @()
    )

    $root = New-Fixture
    try {
        try {
            & $Mutate $root
        }
        catch {
            Assert-Condition `
                -Label $Label `
                -Condition $false `
                -Detail "the mutation itself failed: $($_.Exception.Message)"
            return
        }
        $result = Invoke-Selector -Root $root -AdditionalArguments $AdditionalArguments

        Assert-Condition `
            -Label $Label `
            -Condition ($result.ExitCode -eq $ExpectedExitCode) `
            -Detail "expected exit $ExpectedExitCode, got $($result.ExitCode). Output: $($result.Text)"

        if ($null -eq $result.Report) {
            Assert-Condition -Label $Label -Condition $false -Detail "no JSON report. Output: $($result.Text)"
            return
        }

        if ($ExpectedBlockingPattern) {
            $blocking = @($result.Report.blocking)
            $matched = @($blocking | Where-Object { $_ -match $ExpectedBlockingPattern })
            Assert-Condition `
                -Label $Label `
                -Condition ($matched.Count -ge 1) `
                -Detail "no blocking entry matched '$ExpectedBlockingPattern'. Blocking: $($blocking -join ' / ')"
        }

        $selectedIds = @(@($result.Report.selected) | ForEach-Object { $_.id })
        Assert-Condition `
            -Label $Label `
            -Condition (($selectedIds -join ',') -eq ($ExpectedSelected -join ',')) `
            -Detail "expected selection '$($ExpectedSelected -join ',')', got '$($selectedIds -join ',')'"

        if ($ExpectedDeferredPattern) {
            $deferred = @($result.Report.deferred | Where-Object {
                $_.reason -match $ExpectedDeferredPattern -and
                (-not $ExpectedDeferredId -or $_.id -eq $ExpectedDeferredId)
            })
            $rendered = @(@($result.Report.deferred) | ForEach-Object { "$($_.id)=$($_.reason)" }) -join ' / '
            Assert-Condition `
                -Label $Label `
                -Condition ($deferred.Count -ge 1) `
                -Detail "no deferred entry matched '$ExpectedDeferredPattern' for '$ExpectedDeferredId'. Deferred: $rendered"
        }
    }
    finally {
        Remove-Item -Recurse -Force -LiteralPath $root -ErrorAction SilentlyContinue
    }
}

# Reference scenario: three flows selected, the fourth candidate deferred by capacity.
$referenceRoot = New-Fixture
try {
    $reference = Invoke-Selector -Root $referenceRoot
    Assert-Condition `
        -Label 'reference fixture' `
        -Condition ($reference.ExitCode -eq 0) `
        -Detail "expected exit 0, got $($reference.ExitCode). Output: $($reference.Text)"
    if ($null -ne $reference.Report) {
        $referenceSelected = @(@($reference.Report.selected) | ForEach-Object { $_.id })
        Assert-Condition `
            -Label 'reference fixture selects three flows' `
            -Condition (($referenceSelected -join ',') -eq 'T0002,T0003,T0004') `
            -Detail "got '$($referenceSelected -join ',')'"
        Assert-Condition `
            -Label 'reference fixture reports the integration order' `
            -Condition ((@($reference.Report.integrationOrder) -join ',') -eq 'T0002,T0003,T0004') `
            -Detail "got '$(@($reference.Report.integrationOrder) -join ',')'"
        Assert-Condition `
            -Label 'reference fixture reports shared index contention' `
            -Condition (@($reference.Report.sharedContention | Where-Object {
                $_ -match 'docs/tickets/readme\.md'
            }).Count -eq 1) `
            -Detail "got '$(@($reference.Report.sharedContention) -join ' / ')'"
        Assert-Condition `
            -Label 'reference fixture keeps the shared index out of collisions' `
            -Condition (@(@($reference.Report.selected)[0].exclusivePaths) -notcontains 'docs/tickets/readme.md') `
            -Detail "got '$(@(@($reference.Report.selected)[0].exclusivePaths) -join ' / ')'"
    }
    else {
        Assert-Condition -Label 'reference fixture' -Condition $false -Detail "no JSON report. Output: $($reference.Text)"
    }
}
finally {
    Remove-Item -Recurse -Force -LiteralPath $referenceRoot -ErrorAction SilentlyContinue
}

Assert-Scenario `
    -Label 'mutation 1 - ticket status diverges from the index' `
    -Mutate { param($root) Set-TicketField -Root $root -Id 'T0002' -Pattern '(?m)^Status: Ready$' -Replacement 'Status: Review' } `
    -ExpectedExitCode 1 `
    -ExpectedBlockingPattern "Ticket T0002 status differs" `
    -ExpectedSelected @('T0003', 'T0004', 'T0005')

Assert-Scenario `
    -Label 'mutation 2 - invalid ticket status' `
    -Mutate { param($root) Set-TicketField -Root $root -Id 'T0002' -Pattern '(?m)^Status: Ready$' -Replacement 'Status: Almost done' } `
    -ExpectedExitCode 1 `
    -ExpectedBlockingPattern 'Invalid status in ticket T0002' `
    -ExpectedSelected @('T0003', 'T0004', 'T0005')

Assert-Scenario `
    -Label 'mutation 3 - missing Status field' `
    -Mutate { param($root) Set-TicketField -Root $root -Id 'T0002' -Pattern '(?m)^Status: Ready\r?\n' -Replacement '' } `
    -ExpectedExitCode 1 `
    -ExpectedBlockingPattern 'Ticket T0002 must contain exactly one Status field' `
    -ExpectedSelected @('T0003', 'T0004', 'T0005')

Assert-Scenario `
    -Label 'mutation 4 - ticket file absent from the index' `
    -Mutate {
        param($root)
        $content = New-TicketFile -Id 'T0006' -Status 'Ready' -Dependencies @('T0001') -AllowedAreas @('packages/fixture')
        Set-FixtureText -Path (Join-Path $root 'docs/tickets/T0006-fixture.md') -Text $content
    } `
    -ExpectedExitCode 1 `
    -ExpectedBlockingPattern 'Ticket T0006 is missing from docs/tickets/README.md' `
    -ExpectedSelected @('T0002', 'T0003', 'T0004')

Assert-Scenario `
    -Label 'mutation 5 - duplicate index identifier' `
    -Mutate {
        param($root)
        $path = Join-Path $root 'docs/tickets/README.md'
        $lines = @(Get-Content -Encoding UTF8 -LiteralPath $path)
        $duplicate = @($lines | Where-Object { $_ -match '^\|\s*T0002\s*\|' })[0]
        if (-not $duplicate) {
            throw 'No T0002 index row to duplicate; the mutation would prove nothing.'
        }
        Set-FixtureText -Path $path -Text (((@($lines) + @($duplicate)) -join "`n") + "`n")
    } `
    -ExpectedExitCode 1 `
    -ExpectedBlockingPattern 'Duplicate ticket index identifier: T0002' `
    -ExpectedSelected @('T0002', 'T0003', 'T0004')

Assert-Scenario `
    -Label 'mutation 6 - dependency returned to Draft' `
    -Mutate {
        param($root)
        Set-TicketField -Root $root -Id 'T0001' -Pattern '(?m)^Status: Done$' -Replacement 'Status: Draft'
        Set-IndexStatus -Root $root -Id 'T0001' -Status 'Draft'
    } `
    -ExpectedExitCode 0 `
    -ExpectedSelected @() `
    -ExpectedDeferredPattern 'unsatisfied dependency: T0001' `
    -ExpectedDeferredId 'T0002'

Assert-Scenario `
    -Label 'mutation 7 - allowed area collision between two candidates' `
    -Mutate {
        param($root)
        Set-TicketField `
            -Root $root `
            -Id 'T0003' `
            -Pattern '`supabase/migrations`' `
            -Replacement '`apps/desktop/src/features/alpha/panel`'
    } `
    -ExpectedExitCode 0 `
    -ExpectedSelected @('T0002', 'T0004', 'T0005') `
    -ExpectedDeferredPattern 'allowed area collision on apps/desktop/src/features/alpha/panel' `
    -ExpectedDeferredId 'T0003'

Assert-Scenario `
    -Label 'mutation 8 - an In progress flow consumes capacity and claims its paths' `
    -Mutate {
        param($root)
        Set-TicketField -Root $root -Id 'T0001' -Pattern '(?m)^Status: Done$' -Replacement 'Status: In progress'
        Set-IndexStatus -Root $root -Id 'T0001' -Status 'In progress'
    } `
    -ExpectedExitCode 0 `
    -ExpectedSelected @('T0002', 'T0003') `
    -ExpectedDeferredPattern 'allowed area collision on apps/bridge/src/telemetry' `
    -ExpectedDeferredId 'T0004'

Assert-Scenario `
    -Label 'mutation 9 - requesting a ticket that is not Ready' `
    -Mutate { param($root) $null = $root } `
    -ExpectedExitCode 1 `
    -ExpectedBlockingPattern "Requested ticket T0001 is 'Done', not Ready" `
    -ExpectedSelected @() `
    -AdditionalArguments @('-Only', 'T0001')

Assert-Scenario `
    -Label 'mutation 10 - comma separated ticket request through -File' `
    -Mutate { param($root) $null = $root } `
    -ExpectedExitCode 0 `
    -ExpectedSelected @('T0003', 'T0004') `
    -AdditionalArguments @('-Only', 'T0003,T0004')

if ($failures.Count -gt 0) {
    Write-Host "Ticket automation gate failed with $($failures.Count) of $assertionCount assertions:"
    foreach ($failure in $failures) {
        Write-Host "  - $failure"
    }
    exit 1
}

Write-Host "Ticket batch selector invariants passed: $assertionCount assertions, 10 negative mutations."
exit 0
