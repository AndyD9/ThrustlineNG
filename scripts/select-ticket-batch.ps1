[CmdletBinding()]
param(
    [string]$Root,

    [ValidateRange(1, 9)]
    [int]$MaxFlows = 3,

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

# Every ticket touches these tracking files. They are not collisions, but they do
# require an explicit integration order: this is the index drift already observed
# during the T0043-T0050 merges. Script text stays ASCII so Windows PowerShell
# 5.1 parses it without a byte order mark.
$enDash = [char]0x2013
$emDash = [char]0x2014
$dashClass = "[$enDash$emDash-]"

# An unattended run may only start a ticket whose remaining work needs no human.
# The vetoes below are deterministic and read from the ticket itself, so the
# boundary is reviewable in the ticket rather than trusted to an agent. A ticket
# may also opt out explicitly with "Autonomous: No"; an unreadable or absent
# value never grants autonomy on its own.
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
    'docs/current_state.md',
    'docs/known_issues.md',
    'docs/learnings.md',
    'docs/roadmap.md'
)

function Get-IndexRows {
    param([Parameter(Mandatory)][string]$Path)

    $rows = [System.Collections.Generic.List[object]]::new()
    $lines = @(Get-Content -Encoding UTF8 -LiteralPath $Path)
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -notmatch '^\| T[^|]+\|') {
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

function Get-DependencyIds {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Bullets
    )

    $ids = [System.Collections.Generic.List[string]]::new()
    foreach ($bullet in $Bullets) {
        $rangeMatches = [regex]::Matches($bullet, "T(\d{4})\s*$dashClass\s*T(\d{4})")
        foreach ($rangeMatch in $rangeMatches) {
            $first = [int]$rangeMatch.Groups[1].Value
            $last = [int]$rangeMatch.Groups[2].Value
            if ($last -lt $first) {
                continue
            }
            for ($number = $first; $number -le $last; $number++) {
                $ids.Add('T{0:D4}' -f $number)
            }
        }
        foreach ($single in [regex]::Matches($bullet, 'T\d{4}')) {
            $ids.Add($single.Value)
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
        $residual = [regex]::Replace($bullet, "T\d{4}(\s*$dashClass\s*T\d{4})?", '')
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
$ticketsRoot = Join-Path $Root 'docs/tickets'
$indexPath = Join-Path $ticketsRoot 'README.md'

foreach ($requiredPath in @($ticketsRoot, $indexPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Missing required path: $requiredPath"
    }
}

$indexById = @{}
foreach ($row in (Get-IndexRows -Path $indexPath)) {
    if ($row.Cells.Count -ne 5) {
        $blocking.Add("Ticket index line $($row.Line) must contain exactly 5 columns.")
        continue
    }
    $id = $row.Cells[0]
    if ($id -notmatch '^T\d{4}$') {
        $blocking.Add("Invalid ticket identifier at index line $($row.Line): $id")
        continue
    }
    if ($indexById.ContainsKey($id)) {
        $blocking.Add("Duplicate ticket index identifier: $id")
        continue
    }
    $indexById[$id] = [pscustomobject]@{
        Title  = $row.Cells[1]
        Phase  = $row.Cells[2]
        Status = $row.Cells[4]
    }
}

if ($indexById.Count -eq 0) {
    $blocking.Add('Ticket index carries no ticket row.')
}

$tickets = [System.Collections.Generic.List[object]]::new()
foreach ($file in @(Get-ChildItem -LiteralPath $ticketsRoot -Filter 'T????-*.md' -File | Sort-Object Name)) {
    if ($file.BaseName -notmatch '^(T\d{4})-') {
        $blocking.Add("Invalid ticket filename: $($file.Name)")
        continue
    }
    $id = $Matches[1]
    $lines = @(Get-Content -Encoding UTF8 -LiteralPath $file.FullName)
    $statusLines = @($lines | Where-Object { $_ -match '^Status:\s*(.+?)\s*$' })
    if ($statusLines.Count -ne 1) {
        $blocking.Add("Ticket $id must contain exactly one Status field.")
        continue
    }
    $statusLines[0] -match '^Status:\s*(.+?)\s*$' | Out-Null
    $status = $Matches[1]
    if ($status -notin $allowedStatuses) {
        $blocking.Add("Invalid status in ticket ${id}: $status")
        continue
    }
    if (-not $indexById.ContainsKey($id)) {
        $blocking.Add("Ticket $id is missing from docs/tickets/README.md.")
        continue
    }
    if ($indexById[$id].Status -ne $status) {
        $blocking.Add(
            "Ticket $id status differs: index '$($indexById[$id].Status)', file '$status'."
        )
        continue
    }

    $branch = ''
    $branchLines = @($lines | Where-Object { $_ -match '^Branch:\s*(.+?)\s*$' })
    if ($branchLines.Count -ge 1) {
        $branchLines[0] -match '^Branch:\s*(.+?)\s*$' | Out-Null
        $branch = $Matches[1].Trim('`')
    }
    $securitySensitive = $false
    $securityLines = @($lines | Where-Object { $_ -match '^Security-sensitive:\s*(.+?)\s*$' })
    if ($securityLines.Count -ge 1) {
        $securityLines[0] -match '^Security-sensitive:\s*(.+?)\s*$' | Out-Null
        $securitySensitive = ($Matches[1] -match '(?i)^yes')
    }
    $risk = ''
    $riskLines = @($lines | Where-Object { $_ -match '^Risk:\s*(.+?)\s*$' })
    if ($riskLines.Count -ge 1) {
        $riskLines[0] -match '^Risk:\s*(.+?)\s*$' | Out-Null
        $risk = $Matches[1]
    }
    $autonomousOptOut = $false
    $autonomousLines = @($lines | Where-Object { $_ -match '^Autonomous:\s*(.+?)\s*$' })
    if ($autonomousLines.Count -ge 1) {
        $autonomousLines[0] -match '^Autonomous:\s*(.+?)\s*$' | Out-Null
        $autonomousOptOut = ($Matches[1] -notmatch '(?i)^yes')
    }

    $dependencyBullets = @(Get-Section -Lines $lines -Heading 'Dependencies')
    $allowedBullets = @(Get-Section -Lines $lines -Heading 'Allowed areas')
    $autonomyVetoes = [System.Collections.Generic.List[string]]::new()
    if ($autonomousOptOut) {
        $autonomyVetoes.Add('ticket declares Autonomous: No')
    }
    if ($securitySensitive) {
        $autonomyVetoes.Add('security sensitive')
    }
    if ($risk -match '(?i)high') {
        $autonomyVetoes.Add("risk is '$risk'")
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

    $tickets.Add([pscustomobject]@{
        id                = $id
        title             = $indexById[$id].Title
        phase             = $indexById[$id].Phase
        status            = $status
        branch            = $branch
        risk              = $risk
        securitySensitive = $securitySensitive
        autonomy          = if ($autonomyVetoes.Count -eq 0) { 'autonomous' } else { 'human required' }
        autonomyVetoes    = @($autonomyVetoes)
        file              = "docs/tickets/$($file.Name)"
        dependencies      = @(Get-DependencyIds -Bullets $dependencyBullets)
        humanPrerequisites = @(Get-HumanPrerequisites -Bullets $dependencyBullets)
        declaredPaths     = $declaredPaths
        exclusivePaths    = $exclusivePaths
        sharedPaths       = $sharedPaths
    })
}

foreach ($id in $indexById.Keys) {
    if (@(Get-ChildItem -LiteralPath $ticketsRoot -Filter "$id-*.md" -File).Count -ne 1) {
        $blocking.Add("Ticket index entry $id has no unique ticket file.")
    }
}

$statusById = @{}
foreach ($ticket in $tickets) {
    $statusById[$ticket.id] = $ticket.status
}

$occupying = @($tickets | Where-Object { $_.status -in $occupyingStatuses })
$capacity = $MaxFlows - $occupying.Count
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
        $blocking.Add("Requested ticket $requestedId has no ticket file.")
    }
}

$candidates = @($tickets | Where-Object { $_.status -in $startableStatuses })
if ($requested.Count -gt 0) {
    $candidates = @($candidates | Where-Object { $_.id -in $requested })
    foreach ($requestedId in $requested) {
        if ($statusById.ContainsKey($requestedId) -and
            $statusById[$requestedId] -notin $startableStatuses) {
            $blocking.Add(
                "Requested ticket $requestedId is '$($statusById[$requestedId])', not Ready."
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
            reason = "flow capacity reached ($MaxFlows max, $($occupying.Count) occupied)"
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
    maxFlows         = $MaxFlows
    autonomousOnly   = [bool]$AutonomousOnly
    capacity         = $capacity
    ticketCount      = $tickets.Count
    blocking         = @($blocking)
    occupied         = @($occupying | ForEach-Object {
        [pscustomobject]@{ id = $_.id; branch = $_.branch; exclusivePaths = $_.exclusivePaths }
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
    Write-Host "Tickets: $($tickets.Count); flow capacity: $capacity of $MaxFlows"
    if ($report.blocking.Count -gt 0) {
        Write-Host 'Blocking:'
        foreach ($issue in $report.blocking) { Write-Host "  - $issue" }
    }
    if ($report.occupied.Count -gt 0) {
        Write-Host 'Occupied flows:'
        foreach ($item in $report.occupied) { Write-Host "  - $($item.id) on $($item.branch)" }
    }
    Write-Host 'Selected:'
    if ($selected.Count -eq 0) { Write-Host '  - none' }
    foreach ($item in $selected) {
        Write-Host "  - $($item.id) [$($item.autonomy)] $($item.title)"
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
