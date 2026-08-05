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

# A feature is the current unit of work: one file, one branch, one pull request and
# ordered milestones. Each milestone may redeclare Risk, Security-sensitive and
# Autonomous, and the selector evaluates the unattended boundary on the first
# milestone that is not Done.
function New-FeatureFile {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Dependencies,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$AllowedAreas,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$MilestoneStatuses
    )

    $dependencyBlock = if ($Dependencies.Count -eq 0) {
        "- Aucune."
    }
    else {
        ($Dependencies | ForEach-Object { "- $_" }) -join "`n"
    }
    $allowedBlock = ($AllowedAreas | ForEach-Object { "- ``$_``" }) -join "`n"

    $milestoneBlocks = @()
    for ($position = 0; $position -lt $MilestoneStatuses.Count; $position++) {
        $milestoneId = 'J{0}' -f ($position + 1)
        $milestoneBlocks += @"
### $milestoneId - Jalon $milestoneId de la fixture

Status: $($MilestoneStatuses[$position])
Risk: Low
Security-sensitive: No
Autonomous: Yes

- resultat : comportement observable du jalon $milestoneId.
- frontiere : fixture.
- validations : aucune commande reelle.
- revue : fixture only.
"@
    }
    $milestoneSection = $milestoneBlocks -join "`n"

    return @"
# $Id - Fixture feature $Id

Status: $Status
Owner: Fixture
Branch: ``feature/$($Id.ToLowerInvariant())-fixture``
Phase: 1
Risk: Low
Security-sensitive: No
Autonomous: Yes

## Goal

Capacite observable de la fixture $Id.

## Dependencies

$dependencyBlock

## Allowed areas

$allowedBlock

## Do not touch

- Tout le reste.

## Jalons

$milestoneSection

## Acceptance criteria

- [ ] Fixture only.
"@
}

function New-Fixture {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("ticket-automation-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path (Join-Path $root 'docs/tickets') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $root 'docs/features') | Out-Null

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

    $featureDefinitions = @(
        [pscustomobject]@{
            Id = 'F0001'; Title = 'Fixture feature slice'; Status = 'Ready'
            Dependencies = @('T0001')
            AllowedAreas = @('apps/desktop/src/features/gamma', 'docs/features/README.md')
            MilestoneStatuses = @('Done', 'Ready')
        },
        [pscustomobject]@{
            Id = 'F0002'; Title = 'Fixture feature draft'; Status = 'Draft'
            Dependencies = @('T0001')
            AllowedAreas = @('supabase/functions/fixture', 'docs/features/README.md')
            MilestoneStatuses = @('Draft')
        }
    )

    $featureRows = foreach ($definition in $featureDefinitions) {
        $dependencyCell = if ($definition.Dependencies.Count -eq 0) { '-' } else { $definition.Dependencies -join ', ' }
        "| $($definition.Id) | $($definition.Title) | 1 | $dependencyCell | $($definition.Status) |"
    }

    $featureIndex = @(
        '# Fonctionnalites de fixture',
        '',
        '| ID | Titre | Phase | Depend de | Statut |',
        '| --- | --- | --- | --- | --- |'
    ) + $featureRows
    Set-FixtureText -Path (Join-Path $root 'docs/features/README.md') -Text (($featureIndex -join "`n") + "`n")

    foreach ($definition in $featureDefinitions) {
        $content = New-FeatureFile `
            -Id $definition.Id `
            -Status $definition.Status `
            -Dependencies $definition.Dependencies `
            -AllowedAreas $definition.AllowedAreas `
            -MilestoneStatuses $definition.MilestoneStatuses
        Set-FixtureText -Path (Join-Path $root "docs/features/$($definition.Id)-fixture.md") -Text $content
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

function Set-FeatureField {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Replacement
    )

    $path = Join-Path $Root "docs/features/$Id-fixture.md"
    $text = [System.IO.File]::ReadAllText($path)
    $mutated = [regex]::Replace($text, $Pattern, $Replacement)
    if ($mutated -eq $text) {
        throw "Pattern '$Pattern' changed nothing in $Id; the mutation would prove nothing."
    }
    Set-FixtureText -Path $path -Text $mutated
}

function Set-IndexStatus {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Status,

        # Tickets and features each own their index; both are checked with the same
        # rules, so the mutation helper serves both.
        [ValidateSet('docs/tickets', 'docs/features')]
        [string]$Directory = 'docs/tickets'
    )

    $path = Join-Path $Root "$Directory/README.md"
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

# Reference scenario: two units of work selected, the rest deferred by capacity.
# Andy fixed the ceiling at two on 5 August 2026, when the feature became the unit
# of tracking and integration: a vertical slice occupies what used to be two flows.
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
            -Label 'reference fixture selects two units of work' `
            -Condition (($referenceSelected -join ',') -eq 'T0002,T0003') `
            -Detail "got '$($referenceSelected -join ',')'"
        Assert-Condition `
            -Label 'reference fixture reports the integration order' `
            -Condition ((@($reference.Report.integrationOrder) -join ',') -eq 'T0002,T0003') `
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
    -ExpectedSelected @('T0003', 'T0004')

Assert-Scenario `
    -Label 'mutation 2 - invalid ticket status' `
    -Mutate { param($root) Set-TicketField -Root $root -Id 'T0002' -Pattern '(?m)^Status: Ready$' -Replacement 'Status: Almost done' } `
    -ExpectedExitCode 1 `
    -ExpectedBlockingPattern 'Invalid status in ticket T0002' `
    -ExpectedSelected @('T0003', 'T0004')

Assert-Scenario `
    -Label 'mutation 3 - missing Status field' `
    -Mutate { param($root) Set-TicketField -Root $root -Id 'T0002' -Pattern '(?m)^Status: Ready\r?\n' -Replacement '' } `
    -ExpectedExitCode 1 `
    -ExpectedBlockingPattern 'Ticket T0002 must contain exactly one Status field' `
    -ExpectedSelected @('T0003', 'T0004')

Assert-Scenario `
    -Label 'mutation 4 - ticket file absent from the index' `
    -Mutate {
        param($root)
        $content = New-TicketFile -Id 'T0006' -Status 'Ready' -Dependencies @('T0001') -AllowedAreas @('packages/fixture')
        Set-FixtureText -Path (Join-Path $root 'docs/tickets/T0006-fixture.md') -Text $content
    } `
    -ExpectedExitCode 1 `
    -ExpectedBlockingPattern 'Ticket T0006 is missing from docs/tickets/README.md' `
    -ExpectedSelected @('T0002', 'T0003')

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
    -ExpectedSelected @('T0002', 'T0003')

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
    -ExpectedSelected @('T0002', 'T0004') `
    -ExpectedDeferredPattern 'allowed area collision on apps/desktop/src/features/alpha/panel' `
    -ExpectedDeferredId 'T0003'

Assert-Scenario `
    -Label 'mutation 8 - an In progress unit consumes capacity and claims its paths' `
    -Mutate {
        param($root)
        Set-TicketField -Root $root -Id 'T0001' -Pattern '(?m)^Status: Done$' -Replacement 'Status: In progress'
        Set-IndexStatus -Root $root -Id 'T0001' -Status 'In progress'
    } `
    -ExpectedExitCode 0 `
    -ExpectedSelected @('T0002') `
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

Assert-Scenario `
    -Label 'reference fixture is fully autonomous' `
    -Mutate { param($root) $null = $root } `
    -ExpectedExitCode 0 `
    -ExpectedSelected @('T0002', 'T0003') `
    -AdditionalArguments @('-AutonomousOnly')

Assert-Scenario `
    -Label 'mutation 11 - explicit Autonomous: No vetoes an unattended run' `
    -Mutate {
        param($root)
        Set-TicketField -Root $root -Id 'T0002' -Pattern '(?m)^Risk: Low$' -Replacement "Risk: Low`nAutonomous: No"
    } `
    -ExpectedExitCode 0 `
    -ExpectedSelected @('T0003', 'T0004') `
    -ExpectedDeferredPattern 'human required: ticket declares Autonomous: No' `
    -ExpectedDeferredId 'T0002' `
    -AdditionalArguments @('-AutonomousOnly')

Assert-Scenario `
    -Label 'mutation 12 - a security sensitive ticket is never unattended' `
    -Mutate {
        param($root)
        Set-TicketField -Root $root -Id 'T0002' -Pattern '(?m)^Security-sensitive: No$' -Replacement 'Security-sensitive: Yes'
    } `
    -ExpectedExitCode 0 `
    -ExpectedSelected @('T0003', 'T0004') `
    -ExpectedDeferredPattern 'human required: security sensitive' `
    -ExpectedDeferredId 'T0002' `
    -AdditionalArguments @('-AutonomousOnly')

Assert-Scenario `
    -Label 'mutation 13 - a High risk ticket is never unattended' `
    -Mutate {
        param($root)
        Set-TicketField -Root $root -Id 'T0002' -Pattern '(?m)^Risk: Low$' -Replacement 'Risk: High'
    } `
    -ExpectedExitCode 0 `
    -ExpectedSelected @('T0003', 'T0004') `
    -ExpectedDeferredPattern "human required: risk is 'High'" `
    -ExpectedDeferredId 'T0002' `
    -AdditionalArguments @('-AutonomousOnly')

Assert-Scenario `
    -Label 'mutation 14 - a dependency naming a human decision vetoes an unattended run' `
    -Mutate {
        param($root)
        Set-TicketField -Root $root -Id 'T0002' -Pattern '(?m)^- T0001$' -Replacement '- T0001, decision Andy'
    } `
    -ExpectedExitCode 0 `
    -ExpectedSelected @('T0003', 'T0004') `
    -ExpectedDeferredPattern 'human required: dependency needs a human' `
    -ExpectedDeferredId 'T0002' `
    -AdditionalArguments @('-AutonomousOnly')

Assert-Scenario `
    -Label 'mutation 15 - the same veto does not block an attended run' `
    -Mutate {
        param($root)
        Set-TicketField -Root $root -Id 'T0002' -Pattern '(?m)^Risk: Low$' -Replacement 'Risk: High'
    } `
    -ExpectedExitCode 0 `
    -ExpectedSelected @('T0002', 'T0003')

# Feature scenarios. Since T0068 the feature is the unit of tracking, branch and
# integration, and the unattended boundary is evaluated on the first milestone that
# is not Done. The fixture feature F0001 is Ready with J1 Done and J2 Ready, so
# every milestone mutation below targets J2 through its heading.
Assert-Scenario `
    -Label 'mutation 16 - feature status diverges from the feature index' `
    -Mutate { param($root) Set-IndexStatus -Root $root -Id 'F0001' -Status 'Done' -Directory 'docs/features' } `
    -ExpectedExitCode 1 `
    -ExpectedBlockingPattern "Feature F0001 status differs: index 'Done', file 'Ready'" `
    -ExpectedSelected @('T0002', 'T0003')

Assert-Scenario `
    -Label 'mutation 17 - feature file absent from the feature index' `
    -Mutate {
        param($root)
        $content = New-FeatureFile `
            -Id 'F0003' -Status 'Ready' -Dependencies @('T0001') `
            -AllowedAreas @('packages/fixture-feature') -MilestoneStatuses @('Ready')
        Set-FixtureText -Path (Join-Path $root 'docs/features/F0003-fixture.md') -Text $content
    } `
    -ExpectedExitCode 1 `
    -ExpectedBlockingPattern 'Feature F0003 is missing from docs/features/README.md' `
    -ExpectedSelected @('T0002', 'T0003')

Assert-Scenario `
    -Label 'mutation 18 - a milestone carries an invalid status' `
    -Mutate {
        param($root)
        Set-FeatureField -Root $root -Id 'F0001' `
            -Pattern '(?s)(### J2 .*?)Status: Ready' -Replacement '${1}Status: Presque fini'
    } `
    -ExpectedExitCode 1 `
    -ExpectedBlockingPattern 'Invalid status in feature F0001 milestone J2: Presque fini' `
    -ExpectedSelected @('T0002', 'T0003')

Assert-Scenario `
    -Label 'mutation 19 - milestones are not sequential' `
    -Mutate {
        param($root)
        Set-FeatureField -Root $root -Id 'F0001' -Pattern '### J2 -' -Replacement '### J3 -'
    } `
    -ExpectedExitCode 1 `
    -ExpectedBlockingPattern 'Feature F0001 milestones are not sequential: expected J2, found J3' `
    -ExpectedSelected @('T0002', 'T0003')

Assert-Scenario `
    -Label 'mutation 20 - a milestone with no Status field is refused' `
    -Mutate {
        param($root)
        Set-FeatureField -Root $root -Id 'F0001' `
            -Pattern '(?s)(### J2 .*?)Status: Ready\r?\n' -Replacement '${1}'
    } `
    -ExpectedExitCode 1 `
    -ExpectedBlockingPattern 'Feature F0001 milestone J2 has no Status field' `
    -ExpectedSelected @('T0002', 'T0003')

Assert-Scenario `
    -Label 'mutation 21 - a Ready feature whose every milestone is Done is refused' `
    -Mutate {
        param($root)
        Set-FeatureField -Root $root -Id 'F0001' `
            -Pattern '(?s)(### J2 .*?)Status: Ready' -Replacement '${1}Status: Done'
    } `
    -ExpectedExitCode 1 `
    -ExpectedBlockingPattern "Feature F0001 is 'Ready' while every milestone is Done" `
    -ExpectedSelected @('T0002', 'T0003')

# The next four scenarios are the point of T0068: the boundary follows the
# milestone, not the feature header, which still declares Risk Low,
# Security-sensitive No and Autonomous Yes in all of them.
Assert-Scenario `
    -Label 'the fixture feature is autonomous on its next milestone' `
    -Mutate { param($root) $null = $root } `
    -ExpectedExitCode 0 `
    -ExpectedSelected @('F0001') `
    -AdditionalArguments @('-Only', 'F0001', '-AutonomousOnly')

Assert-Scenario `
    -Label 'mutation 22 - the next milestone declares Autonomous: No' `
    -Mutate {
        param($root)
        Set-FeatureField -Root $root -Id 'F0001' `
            -Pattern '(?s)(### J2 .*?)Autonomous: Yes' -Replacement '${1}Autonomous: No'
    } `
    -ExpectedExitCode 0 `
    -ExpectedSelected @() `
    -ExpectedDeferredPattern 'human required: milestone J2 declares Autonomous: No' `
    -ExpectedDeferredId 'F0001' `
    -AdditionalArguments @('-Only', 'F0001', '-AutonomousOnly')

Assert-Scenario `
    -Label 'mutation 23 - the next milestone is security sensitive' `
    -Mutate {
        param($root)
        Set-FeatureField -Root $root -Id 'F0001' `
            -Pattern '(?s)(### J2 .*?)Security-sensitive: No' -Replacement '${1}Security-sensitive: Yes'
    } `
    -ExpectedExitCode 0 `
    -ExpectedSelected @() `
    -ExpectedDeferredPattern 'human required: milestone J2 is security sensitive' `
    -ExpectedDeferredId 'F0001' `
    -AdditionalArguments @('-Only', 'F0001', '-AutonomousOnly')

Assert-Scenario `
    -Label 'mutation 24 - the next milestone carries a High risk' `
    -Mutate {
        param($root)
        Set-FeatureField -Root $root -Id 'F0001' `
            -Pattern '(?s)(### J2 .*?)Risk: Low' -Replacement '${1}Risk: High'
    } `
    -ExpectedExitCode 0 `
    -ExpectedSelected @() `
    -ExpectedDeferredPattern "human required: milestone J2 risk is 'High'" `
    -ExpectedDeferredId 'F0001' `
    -AdditionalArguments @('-Only', 'F0001', '-AutonomousOnly')

Assert-Scenario `
    -Label 'mutation 25 - a High risk on an already Done milestone does not veto' `
    -Mutate {
        param($root)
        Set-FeatureField -Root $root -Id 'F0001' `
            -Pattern '(?s)(### J1 .*?)Risk: Low' -Replacement '${1}Risk: High'
    } `
    -ExpectedExitCode 0 `
    -ExpectedSelected @('F0001') `
    -AdditionalArguments @('-Only', 'F0001', '-AutonomousOnly')

Assert-Scenario `
    -Label 'mutation 26 - a feature directory without its index is refused' `
    -Mutate {
        param($root)
        Remove-Item -Force -LiteralPath (Join-Path $root 'docs/features/README.md')
    } `
    -ExpectedExitCode 1 `
    -ExpectedBlockingPattern 'docs/features exists without docs/features/README.md' `
    -ExpectedSelected @('T0002', 'T0003')

Assert-Scenario `
    -Label 'a feature and an archive ticket remain selectable together during the transition' `
    -Mutate { param($root) $null = $root } `
    -ExpectedExitCode 0 `
    -ExpectedSelected @('T0002', 'F0001') `
    -AdditionalArguments @('-Only', 'T0002,F0001')

Assert-Scenario `
    -Label 'mutation 27 - the work ceiling of two defers the third unit' `
    -Mutate { param($root) $null = $root } `
    -ExpectedExitCode 0 `
    -ExpectedSelected @('T0002', 'T0003') `
    -ExpectedDeferredPattern 'work capacity reached \(2 max, 0 occupied\)' `
    -ExpectedDeferredId 'T0004'

if ($failures.Count -gt 0) {
    Write-Host "Ticket automation gate failed with $($failures.Count) of $assertionCount assertions:"
    foreach ($failure in $failures) {
        Write-Host "  - $failure"
    }
    exit 1
}

Write-Host "Ticket batch selector invariants passed: $assertionCount assertions, 27 negative mutations."
exit 0
