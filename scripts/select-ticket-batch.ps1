[CmdletBinding()]
param(
    [string]$Root,

    # The unit of work is the feature since T0068; Andy fixed the ceiling at two
    # on 5 August 2026. -MaxFlows stays as an alias so callers written for the
    # three-flow model keep binding.
    [ValidateRange(1, 9)]
    [Alias('MaxFlows')]
    [int]$MaxConcurrent = 2,

    [string[]]$Only = @(),

    [switch]$AutonomousOnly,

    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}
$Root = (Resolve-Path -LiteralPath $Root).Path

$allowedStatuses = @(
    'Draft', 'Ready', 'In progress', 'Review', 'Verify', 'Done',
    'Blocked', 'Rejected', 'Superseded'
)
$startableStatuses = @('Ready')
$occupyingStatuses = @('In progress')
$blockedDependencyStatuses = @('Draft', 'Blocked', 'Rejected', 'Superseded')
$completedMilestoneStatuses = @('Done')

# Every work item touches these tracking files. They are not collisions, but they
# do require an explicit integration order: this is the index drift already
# observed during the T0043-T0050 merges. Script text stays ASCII so Windows
# PowerShell 5.1 parses it without a byte order mark.
$enDash = [char]0x2013
$emDash = [char]0x2014
$dashClass = "[$enDash$emDash-]"

# An unattended run may only start work whose remaining steps need no human. The
# vetoes below are deterministic and read from the file itself, so the boundary is
# reviewable in the ticket or feature rather than trusted to an agent. A file may
# also opt out explicitly with "Autonomous: No"; an unreadable or absent value
# never grants autonomy on its own.
# For a feature the boundary is evaluated on the next executable milestone, because
# a financial migration and a read-only panel do not carry the same risk.
# A single dot stands for any accented letter so the patterns stay ASCII and match
# both "decision" and its accented spelling.
$autonomyVetoPatterns = @(
    '(?i)d.cisions?\b',
    '(?i)\bAndy\b',
    '(?i)MSFS',
    '(?i)SimConnect',
    '(?i)install',
    '(?i)mat.riel',
    '(?i)v.rification humaine',
    '(?i)revue de phase',
    '(?i)revue phase'
)
$sharedTrackingPaths = @(
    'docs/tickets/readme.md',
    'docs/features/readme.md',
    'docs/current_state.md',
    'docs/known_issues.md',
    'docs/learnings.md',
    'docs/roadmap.md'
)

function Get-IndexRows {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$IdPrefix
    )

    $rows = [System.Collections.Generic.List[object]]::new()
    $lines = @(Get-Content -Encoding UTF8 -LiteralPath $Path)
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -notmatch "^\| $IdPrefix[^|]+\|") {
            continue
        }
        $cells = @($lines[$index].Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        $rows.Add([pscustomobject]@{ Cells = $cells; Line = $index + 1 })
    }
    return $rows
}

function Get-Section {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines,

        [Parameter(Mandatory)][string]$Heading
    )

    $bullets = [System.Collections.Generic.List[string]]::new()
    $inside = $false
    foreach ($line in $Lines) {
        if ($line -match '^##\s+(.+?)\s*$') {
            $inside = ($Matches[1] -eq $Heading)
            continue
        }
        if (-not $inside) {
            continue
        }
        if ($line -match '^\s*[-*]\s+(.+?)\s*$') {
            $bullets.Add($Matches[1])
        }
    }
    return $bullets
}

# A feature declares ordered milestones as "### J<n> - title" under "## Jalons".
# Each milestone may redeclare Status, Risk, Security-sensitive and Autonomous;
# the header values act as defaults. Values are collected as lists so a duplicated
# field is reported instead of silently taking the first one.
function Get-Milestones {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines
    )

    $milestones = [System.Collections.Generic.List[object]]::new()
    $inside = $false
    $current = $null
    foreach ($line in $Lines) {
        if ($line -match '^###\s+(J\d+)\b\s*(.*)$') {
            if (-not $inside) {
                continue
            }
            if ($null -ne $current) {
                $milestones.Add($current)
            }
            $current = [pscustomobject]@{
                id     = $Matches[1]
                title  = $Matches[2].Trim().Trim([char[]]@($emDash, $enDash, '-', ' '))
                fields = @{}
            }
            continue
        }
        if ($line -match '^##\s+(.+?)\s*$') {
            if ($null -ne $current) {
                $milestones.Add($current)
                $current = $null
            }
            $inside = ($Matches[1] -match '^Jalons\b')
            continue
        }
        if ($null -eq $current) {
            continue
        }
        if ($line -match '^(Status|Risk|Security-sensitive|Autonomous):\s*(.+?)\s*$') {
            $name = $Matches[1]
            $value = $Matches[2]
            if ($current.fields.ContainsKey($name)) {
                $current.fields[$name] = @($current.fields[$name]) + @($value)
            }
            else {
                $current.fields[$name] = @($value)
            }
        }
    }
    if ($null -ne $current) {
        $milestones.Add($current)
    }
    return $milestones
}

function Get-HeaderValues {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines,

        [Parameter(Mandatory)][string]$Name
    )

    # Only the preamble counts. A feature repeats Status, Risk, Security-sensitive
    # and Autonomous inside each milestone, so reading the whole file would let a
    # milestone value pass for the header one.
    $values = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $Lines) {
        if ($line -match '^##') {
            break
        }
        if ($line -match "^$Name" + ':\s*(.+?)\s*$') {
            $values.Add($Matches[1])
        }
    }
    return $values
}

function Get-DependencyIds {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Bullets
    )

    $ids = [System.Collections.Generic.List[string]]::new()
    foreach ($bullet in $Bullets) {
        foreach ($prefix in @('T', 'F')) {
            $rangeMatches = [regex]::Matches($bullet, "$prefix(\d{4})\s*$dashClass\s*$prefix(\d{4})")
            foreach ($rangeMatch in $rangeMatches) {
                $first = [int]$rangeMatch.Groups[1].Value
                $last = [int]$rangeMatch.Groups[2].Value
                if ($last -lt $first) {
                    continue
                }
                for ($number = $first; $number -le $last; $number++) {
                    $ids.Add("$prefix{0:D4}" -f $number)
                }
            }
            foreach ($single in [regex]::Matches($bullet, "$prefix\d{4}")) {
                $ids.Add($single.Value)
            }
        }
    }
    return @($ids | Sort-Object -Unique)
}

function Get-HumanPrerequisites {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Bullets
    )

    $prerequisites = [System.Collections.Generic.List[string]]::new()
    foreach ($bullet in $Bullets) {
        $residual = [regex]::Replace($bullet, "[TF]\d{4}(\s*$dashClass\s*[TF]\d{4})?", '')
        foreach ($fragment in $residual.Split(',')) {
            $candidate = $fragment.Trim([char[]]@(' ', "`t", '.', ';', ':', '-', $enDash, $emDash))
            if ($candidate.Length -lt 3) {
                continue
            }
            $prerequisites.Add($candidate)
        }
    }
    return @($prerequisites | Sort-Object -Unique)
}

function Get-AllowedPaths {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Bullets
    )

    $paths = [System.Collections.Generic.List[string]]::new()
    foreach ($bullet in $Bullets) {
        $tokens = @([regex]::Matches($bullet, '`([^`]+)`') | ForEach-Object { $_.Groups[1].Value })
        if ($tokens.Count -eq 0) {
            $tokens = @($bullet -split '\s+')
        }
        foreach ($token in $tokens) {
            $candidate = $token.Trim().Trim(',', ';', '.', ')', '(', '"', "'", '*')
            $candidate = $candidate -replace '\\', '/'
            $candidate = $candidate.TrimEnd('/')
            if ([string]::IsNullOrWhiteSpace($candidate)) {
                continue
            }
            if ($candidate -notmatch '^[A-Za-z0-9][A-Za-z0-9._/@{}-]*$') {
                continue
            }
            if ($candidate -notmatch '/' -and $candidate -notmatch '\.[A-Za-z0-9]+$') {
                continue
            }
            $paths.Add($candidate.ToLowerInvariant())
        }
    }
    return @($paths | Sort-Object -Unique)
}

function Test-PathCollision {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Left,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Right
    )

    foreach ($leftPath in $Left) {
        foreach ($rightPath in $Right) {
            if ($leftPath -eq $rightPath) {
                return $leftPath
            }
            if ($leftPath.StartsWith("$rightPath/")) {
                return $leftPath
            }
            if ($rightPath.StartsWith("$leftPath/")) {
                return $rightPath
            }
        }
    }
    return $null
}

$blocking = [System.Collections.Generic.List[string]]::new()
$items = [System.Collections.Generic.List[object]]::new()

# Tickets are the frozen archive format and features are the current one. Both are
# read with the same consistency rules so the transition cannot hide a drift on
# either side.
$kinds = @(
    [pscustomobject]@{
        Kind      = 'ticket'
        Label     = 'Ticket'
        IdPrefix  = 'T'
        Directory = 'docs/tickets'
        FileGlob  = 'T????-*.md'
        IndexName = 'docs/tickets/README.md'
        Required  = $true
    }
    [pscustomobject]@{
        Kind      = 'feature'
        Label     = 'Feature'
        IdPrefix  = 'F'
        Directory = 'docs/features'
        FileGlob  = 'F????-*.md'
        IndexName = 'docs/features/README.md'
        Required  = $false
    }
)

foreach ($kind in $kinds) {
    $kindRoot = Join-Path $Root $kind.Directory
    $indexPath = Join-Path $Root $kind.IndexName

    if (-not (Test-Path -LiteralPath $kindRoot)) {
        if ($kind.Required) {
            throw "Missing required path: $kindRoot"
        }
        continue
    }
    if (-not (Test-Path -LiteralPath $indexPath)) {
        # The directory exists, so its index is mandatory: without it a file could
        # carry any status unchecked.
        if ($kind.Required) {
            throw "Missing required path: $indexPath"
        }
        $blocking.Add("$($kind.Directory) exists without $($kind.IndexName).")
        continue
    }

    $indexById = @{}
    foreach ($row in (Get-IndexRows -Path $indexPath -IdPrefix $kind.IdPrefix)) {
        if ($row.Cells.Count -ne 5) {
            $blocking.Add("$($kind.Label) index line $($row.Line) must contain exactly 5 columns.")
            continue
        }
        $id = $row.Cells[0]
        if ($id -notmatch "^$($kind.IdPrefix)\d{4}$") {
            $blocking.Add("Invalid $($kind.Kind) identifier at index line $($row.Line): $id")
            continue
        }
        if ($indexById.ContainsKey($id)) {
            $blocking.Add("Duplicate $($kind.Kind) index identifier: $id")
            continue
        }
        $indexById[$id] = [pscustomobject]@{
            Title  = $row.Cells[1]
            Phase  = $row.Cells[2]
            Status = $row.Cells[4]
        }
    }

    if ($kind.Required -and $indexById.Count -eq 0) {
        $blocking.Add("$($kind.Label) index carries no $($kind.Kind) row.")
    }

    foreach ($file in @(Get-ChildItem -LiteralPath $kindRoot -Filter $kind.FileGlob -File | Sort-Object Name)) {
        if ($file.BaseName -notmatch "^($($kind.IdPrefix)\d{4})-") {
            $blocking.Add("Invalid $($kind.Kind) filename: $($file.Name)")
            continue
        }
        $id = $Matches[1]
        $lines = @(Get-Content -Encoding UTF8 -LiteralPath $file.FullName)

        $statusValues = @(Get-HeaderValues -Lines $lines -Name 'Status')
        if ($statusValues.Count -ne 1) {
            $blocking.Add("$($kind.Label) $id must contain exactly one Status field.")
            continue
        }
        $status = $statusValues[0]
        if ($status -notin $allowedStatuses) {
            $blocking.Add("Invalid status in $($kind.Kind) ${id}: $status")
            continue
        }
        if (-not $indexById.ContainsKey($id)) {
            $blocking.Add("$($kind.Label) $id is missing from $($kind.IndexName).")
            continue
        }
        if ($indexById[$id].Status -ne $status) {
            $blocking.Add(
                "$($kind.Label) $id status differs: index '$($indexById[$id].Status)', file '$status'."
            )
            continue
        }

        $branch = ''
        $branchValues = @(Get-HeaderValues -Lines $lines -Name 'Branch')
        if ($branchValues.Count -ge 1) {
            $branch = $branchValues[0].Trim('`')
        }
        $securityValues = @(Get-HeaderValues -Lines $lines -Name 'Security-sensitive')
        $securitySensitive = ($securityValues.Count -ge 1) -and ($securityValues[0] -match '(?i)^yes')
        $risk = ''
        $riskValues = @(Get-HeaderValues -Lines $lines -Name 'Risk')
        if ($riskValues.Count -ge 1) {
            $risk = $riskValues[0]
        }
        $autonomousValues = @(Get-HeaderValues -Lines $lines -Name 'Autonomous')
        $autonomousOptOut = ($autonomousValues.Count -ge 1) -and ($autonomousValues[0] -notmatch '(?i)^yes')

        $dependencyBullets = @(Get-Section -Lines $lines -Heading 'Dependencies')
        $allowedBullets = @(Get-Section -Lines $lines -Heading 'Allowed areas')

        $autonomyVetoes = [System.Collections.Generic.List[string]]::new()
        if ($autonomousOptOut) {
            $autonomyVetoes.Add("$($kind.Kind) declares Autonomous: No")
        }

        # A ticket carries its whole boundary in the header. A feature moves it to the
        # next executable milestone, so the two are computed separately.
        $milestones = [System.Collections.Generic.List[object]]::new()
        $nextMilestone = $null
        if ($kind.Kind -eq 'ticket') {
            if ($securitySensitive) {
                $autonomyVetoes.Add('security sensitive')
            }
            if ($risk -match '(?i)high') {
                $autonomyVetoes.Add("risk is '$risk'")
            }
        }
        else {
            # @() is required: PowerShell unrolls a returned collection, so a feature
            # with a single milestone would arrive as a scalar, and .Count does not
            # exist on a scalar under Windows PowerShell 5.1 with StrictMode.
            $milestones = @(Get-Milestones -Lines $lines)
            if ($milestones.Count -eq 0) {
                $blocking.Add("$($kind.Label) $id declares no milestone under '## Jalons'.")
                continue
            }

            $milestoneInvalid = $false
            for ($position = 0; $position -lt $milestones.Count; $position++) {
                $milestone = $milestones[$position]
                $expectedId = 'J{0}' -f ($position + 1)
                if ($milestone.id -ne $expectedId) {
                    $blocking.Add(
                        "$($kind.Label) $id milestones are not sequential: expected $expectedId, found $($milestone.id)."
                    )
                    $milestoneInvalid = $true
                    break
                }
                if (-not $milestone.fields.ContainsKey('Status')) {
                    $blocking.Add("$($kind.Label) $id milestone $($milestone.id) has no Status field.")
                    $milestoneInvalid = $true
                    break
                }
                $milestoneStatuses = @($milestone.fields['Status'])
                if ($milestoneStatuses.Count -ne 1) {
                    $blocking.Add(
                        "$($kind.Label) $id milestone $($milestone.id) must contain exactly one Status field."
                    )
                    $milestoneInvalid = $true
                    break
                }
                if ($milestoneStatuses[0] -notin $allowedStatuses) {
                    $blocking.Add(
                        "Invalid status in $($kind.Kind) $id milestone $($milestone.id): $($milestoneStatuses[0])"
                    )
                    $milestoneInvalid = $true
                    break
                }
            }
            if ($milestoneInvalid) {
                continue
            }

            $nextMilestone = @(
                $milestones | Where-Object { @($_.fields['Status'])[0] -notin $completedMilestoneStatuses }
            ) | Select-Object -First 1
            if ($null -eq $nextMilestone -and $status -in $startableStatuses) {
                $blocking.Add(
                    "$($kind.Label) $id is '$status' while every milestone is Done."
                )
                continue
            }

            if ($null -ne $nextMilestone) {
                # The header values are the defaults; a milestone that redeclares one
                # of them wins, because the boundary belongs where the work is.
                $milestoneSecurity = $securitySensitive
                if ($nextMilestone.fields.ContainsKey('Security-sensitive')) {
                    $milestoneSecurity = (@($nextMilestone.fields['Security-sensitive'])[0] -match '(?i)^yes')
                }
                $milestoneRisk = $risk
                if ($nextMilestone.fields.ContainsKey('Risk')) {
                    $milestoneRisk = @($nextMilestone.fields['Risk'])[0]
                }
                if ($nextMilestone.fields.ContainsKey('Autonomous') -and
                    (@($nextMilestone.fields['Autonomous'])[0] -notmatch '(?i)^yes')) {
                    $autonomyVetoes.Add("milestone $($nextMilestone.id) declares Autonomous: No")
                }
                if ($milestoneSecurity) {
                    $autonomyVetoes.Add("milestone $($nextMilestone.id) is security sensitive")
                }
                if ($milestoneRisk -match '(?i)high') {
                    $autonomyVetoes.Add("milestone $($nextMilestone.id) risk is '$milestoneRisk'")
                }
            }
        }

        foreach ($bullet in $dependencyBullets) {
            foreach ($pattern in $autonomyVetoPatterns) {
                if ($bullet -match $pattern) {
                    $autonomyVetoes.Add("dependency needs a human: $bullet")
                    break
                }
            }
        }

        $declaredPaths = @(Get-AllowedPaths -Bullets $allowedBullets)
        $exclusivePaths = @($declaredPaths | Where-Object { $_ -notin $sharedTrackingPaths })
        $sharedPaths = @($declaredPaths | Where-Object { $_ -in $sharedTrackingPaths })

        $items.Add([pscustomobject]@{
            kind              = $kind.Kind
            id                = $id
            title             = $indexById[$id].Title
            phase             = $indexById[$id].Phase
            status            = $status
            branch            = $branch
            risk              = $risk
            securitySensitive = $securitySensitive
            autonomy          = if ($autonomyVetoes.Count -eq 0) { 'autonomous' } else { 'human required' }
            autonomyVetoes    = @($autonomyVetoes)
            file              = "$($kind.Directory)/$($file.Name)"
            dependencies      = @(Get-DependencyIds -Bullets $dependencyBullets)
            humanPrerequisites = @(Get-HumanPrerequisites -Bullets $dependencyBullets)
            declaredPaths     = $declaredPaths
            exclusivePaths    = $exclusivePaths
            sharedPaths       = $sharedPaths
            milestones        = @($milestones | ForEach-Object {
                [pscustomobject]@{ id = $_.id; title = $_.title; status = @($_.fields['Status'])[0] }
            })
            nextMilestone     = if ($null -eq $nextMilestone) { $null } else { $nextMilestone.id }
        })
    }

    foreach ($id in $indexById.Keys) {
        if (@(Get-ChildItem -LiteralPath $kindRoot -Filter "$id-*.md" -File).Count -ne 1) {
            $blocking.Add("$($kind.Label) index entry $id has no unique $($kind.Kind) file.")
        }
    }
}

$statusById = @{}
$kindById = @{}
foreach ($item in $items) {
    $statusById[$item.id] = $item.status
    $kindById[$item.id] = $item.kind
}

$occupying = @($items | Where-Object { $_.status -in $occupyingStatuses })
$capacity = $MaxConcurrent - $occupying.Count
if ($capacity -lt 0) {
    $capacity = 0
}

# Invoked through -File, "-Only T0061,T0062" arrives as a single string under
# PowerShell 7 and as two elements under Windows PowerShell 5.1. The -split
# operator is used because String.Split with an object[] separator does not split
# under PowerShell 7. Both forms must bind identically.
$requested = @(
    $Only |
        Where-Object { $_ } |
        ForEach-Object { $_ -split '[,;\s]+' } |
        ForEach-Object { $_.Trim().ToUpperInvariant() } |
        Where-Object { $_ } |
        Sort-Object -Unique
)
foreach ($requestedId in $requested) {
    if (-not $statusById.ContainsKey($requestedId)) {
        $blocking.Add("Requested $requestedId has no ticket or feature file.")
    }
}

$candidates = @($items | Where-Object { $_.status -in $startableStatuses })
if ($requested.Count -gt 0) {
    $candidates = @($candidates | Where-Object { $_.id -in $requested })
    foreach ($requestedId in $requested) {
        if ($statusById.ContainsKey($requestedId) -and
            $statusById[$requestedId] -notin $startableStatuses) {
            $blocking.Add(
                "Requested $($kindById[$requestedId]) $requestedId is '$($statusById[$requestedId])', not Ready."
            )
        }
    }
}

$selected = [System.Collections.Generic.List[object]]::new()
$deferred = [System.Collections.Generic.List[object]]::new()
$claimedPaths = [System.Collections.Generic.List[string]]::new()
foreach ($occupied in $occupying) {
    foreach ($path in $occupied.exclusivePaths) {
        $claimedPaths.Add($path)
    }
}

foreach ($candidate in $candidates) {
    $unsatisfied = @(
        $candidate.dependencies |
            Where-Object { $_ -ne $candidate.id } |
            Where-Object {
                (-not $statusById.ContainsKey($_)) -or
                ($statusById[$_] -in $blockedDependencyStatuses)
            }
    )
    if ($unsatisfied.Count -gt 0) {
        $deferred.Add([pscustomobject]@{
            id     = $candidate.id
            reason = "unsatisfied dependency: $($unsatisfied -join ', ')"
        })
        continue
    }

    if ($AutonomousOnly -and $candidate.autonomy -ne 'autonomous') {
        $deferred.Add([pscustomobject]@{
            id     = $candidate.id
            reason = "human required: $($candidate.autonomyVetoes -join '; ')"
        })
        continue
    }

    if ($candidate.declaredPaths.Count -eq 0) {
        $deferred.Add([pscustomobject]@{
            id     = $candidate.id
            reason = 'no parsable Allowed areas path'
        })
        continue
    }

    $collision = Test-PathCollision -Left $candidate.exclusivePaths -Right @($claimedPaths)
    if ($null -ne $collision) {
        $deferred.Add([pscustomobject]@{
            id     = $candidate.id
            reason = "allowed area collision on $collision"
        })
        continue
    }

    if ($selected.Count -ge $capacity) {
        $deferred.Add([pscustomobject]@{
            id     = $candidate.id
            reason = "work capacity reached ($MaxConcurrent max, $($occupying.Count) occupied)"
        })
        continue
    }

    $selected.Add($candidate)
    foreach ($path in $candidate.exclusivePaths) {
        $claimedPaths.Add($path)
    }
}

$sharedContention = [System.Collections.Generic.List[string]]::new()
foreach ($path in $sharedTrackingPaths) {
    $owners = @($selected | Where-Object { $path -in $_.sharedPaths } | ForEach-Object { $_.id })
    if ($owners.Count -gt 1) {
        $sharedContention.Add("$path claimed by $($owners -join ', ')")
    }
}

$report = [pscustomobject]@{
    root             = $Root
    maxConcurrent    = $MaxConcurrent
    maxFlows         = $MaxConcurrent
    autonomousOnly   = [bool]$AutonomousOnly
    capacity         = $capacity
    itemCount        = $items.Count
    ticketCount      = @($items | Where-Object { $_.kind -eq 'ticket' }).Count
    featureCount     = @($items | Where-Object { $_.kind -eq 'feature' }).Count
    blocking         = @($blocking)
    occupied         = @($occupying | ForEach-Object {
        [pscustomobject]@{
            id             = $_.id
            kind           = $_.kind
            branch         = $_.branch
            exclusivePaths = $_.exclusivePaths
        }
    })
    selected         = @($selected)
    deferred         = @($deferred)
    integrationOrder = @($selected | ForEach-Object { $_.id })
    sharedContention = @($sharedContention)
}

if ($Json) {
    $report | ConvertTo-Json -Depth 6
}
else {
    Write-Host "Root: $Root"
    Write-Host (
        "Features: $($report.featureCount); tickets: $($report.ticketCount); " +
        "work capacity: $capacity of $MaxConcurrent"
    )
    if ($report.blocking.Count -gt 0) {
        Write-Host 'Blocking:'
        foreach ($issue in $report.blocking) { Write-Host "  - $issue" }
    }
    if ($report.occupied.Count -gt 0) {
        Write-Host 'Occupied:'
        foreach ($item in $report.occupied) { Write-Host "  - $($item.id) on $($item.branch)" }
    }
    Write-Host 'Selected:'
    if ($selected.Count -eq 0) { Write-Host '  - none' }
    foreach ($item in $selected) {
        $milestone = if ($item.nextMilestone) { " next $($item.nextMilestone)" } else { '' }
        Write-Host "  - $($item.id) [$($item.autonomy)]$milestone $($item.title)"
    }
    if ($report.deferred.Count -gt 0) {
        Write-Host 'Deferred:'
        foreach ($item in $report.deferred) { Write-Host "  - $($item.id): $($item.reason)" }
    }
    if ($report.sharedContention.Count -gt 0) {
        Write-Host 'Shared tracking files needing a serialised integration order:'
        foreach ($item in $report.sharedContention) { Write-Host "  - $item" }
    }
}

if ($report.blocking.Count -gt 0) {
    exit 1
}
exit 0
