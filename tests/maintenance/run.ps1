[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-DataRows {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$RowPattern
    )

    $rows = [System.Collections.Generic.List[object]]::new()
    $lines = @(Get-Content -Encoding UTF8 -LiteralPath $Path)
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -notmatch $RowPattern) {
            continue
        }
        $cells = @($lines[$index].Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        $rows.Add([pscustomobject]@{ Cells = $cells; Line = $index + 1 })
    }
    return $rows
}

function Get-MaintenanceIssues {
    param(
        [Parameter(Mandatory)]
        [string]$Root
    )

    $issues = [System.Collections.Generic.List[string]]::new()
    $knownIssuesPath = Join-Path $Root 'docs/KNOWN_ISSUES.md'
    $ticketIndexPath = Join-Path $Root 'docs/tickets/README.md'
    $ticketsRoot = Join-Path $Root 'docs/tickets'
    # T0068 : l'unité de suivi est la fonctionnalité. Une dette peut donc être
    # résolue par une `FXXXX` autant que par un ticket d'archive `TXXXX`.
    $featuresRoot = Join-Path $Root 'docs/features'

    foreach ($requiredPath in @($knownIssuesPath, $ticketIndexPath, $ticketsRoot, $featuresRoot)) {
        if (-not (Test-Path -LiteralPath $requiredPath)) {
            $issues.Add("Missing maintenance input: $requiredPath")
        }
    }
    if ($issues.Count -gt 0) {
        return $issues
    }

    $currentStatePath = Join-Path $Root 'docs/CURRENT_STATE.md'
    if (Test-Path -LiteralPath $currentStatePath) {
        $currentStateLineCount = @(Get-Content -Encoding UTF8 -LiteralPath $currentStatePath).Count
        if ($currentStateLineCount -gt 200) {
            $issues.Add("CURRENT_STATE.md exceeds its 200-line budget ($currentStateLineCount lines): keep it one page and move history to docs/archive/.")
        }
    }

    $knownIssuesText = Get-Content -Raw -Encoding UTF8 -LiteralPath $knownIssuesPath
    if (-not [regex]::IsMatch($knownIssuesText, '(?m)^\| ID \| [^|]+ \| Zone \| [^|]+ \| Preuve \| Ticket cible \| Statut \|\r?$')) {
        $issues.Add('KNOWN_ISSUES.md has an invalid table schema.')
    }
    $knownRows = @(Get-DataRows -Path $knownIssuesPath -RowPattern '^\| KI-[^|]+\|')
    if ($knownRows.Count -eq 0) {
        $issues.Add('KNOWN_ISSUES.md must contain the canonical issue table.')
        return $issues
    }

    $knownById = @{}
    $allowedSeverities = @('Critical', 'High', 'Medium', 'Low')
    $allowedIssueStatuses = @('Open', 'Accepted', 'Scheduled', 'Resolved', 'Invalid')
    foreach ($row in $knownRows) {
        if ($row.Cells.Count -ne 7) {
            $issues.Add("KNOWN_ISSUES.md line $($row.Line) must contain exactly 7 columns.")
            continue
        }
        $id, $severity, $zone, $summary, $evidence, $target, $status = $row.Cells
        if ($id -notmatch '^KI-\d{3}$') {
            $issues.Add("Invalid known-issue identifier at line $($row.Line): $id")
            continue
        }
        if ($knownById.ContainsKey($id)) {
            $issues.Add("Duplicate known-issue identifier: $id")
        }
        else {
            $knownById[$id] = $status
        }
        if ($severity -notin $allowedSeverities) {
            $issues.Add("Invalid severity for ${id}: $severity")
        }
        if ($status -notin $allowedIssueStatuses) {
            $issues.Add("Invalid status for ${id}: $status")
        }
        foreach ($field in @{
            Zone = $zone
            Summary = $summary
            Evidence = $evidence
            Target = $target
        }.GetEnumerator()) {
            if ([string]::IsNullOrWhiteSpace($field.Value) -or
                $field.Value -eq [char]0x2014) {
                $issues.Add("$id has no $($field.Key.ToLowerInvariant()).")
            }
        }
        if ($status -eq 'Resolved') {
            # Une dette résolue cite l'unité qui l'a résolue : un ticket
            # d'archive `TXXXX` sous `docs/tickets`, ou une fonctionnalité
            # `FXXXX` sous `docs/features`. Chaque référence doit résoudre vers
            # exactement un fichier de son répertoire — une dette ne peut pas se
            # déclarer résolue par une unité qui n'existe pas.
            $unitIds = @([regex]::Matches($target, '[TF]\d{4}') | ForEach-Object { $_.Value })
            if ($unitIds.Count -eq 0) {
                $issues.Add("Resolved issue $id must reference a ticket or a feature.")
            }
            foreach ($unitId in $unitIds) {
                $isFeature = $unitId.StartsWith('F')
                $unitRoot = if ($isFeature) { $featuresRoot } else { $ticketsRoot }
                $unitLabel = if ($isFeature) { 'feature' } else { 'ticket' }
                if (@(Get-ChildItem -LiteralPath $unitRoot -Filter "$unitId-*.md" -File).Count -ne 1) {
                    $issues.Add(
                        "Resolved issue $id references missing or ambiguous $unitLabel $unitId."
                    )
                }
            }
        }
        if ($status -eq 'Accepted' -and $evidence -notmatch '(?i)ADR-\d{4}|Andy') {
            $issues.Add("Accepted issue $id must cite an ADR or Andy's explicit decision.")
        }
    }

    $ticketIndexText = Get-Content -Raw -Encoding UTF8 -LiteralPath $ticketIndexPath
    if (-not [regex]::IsMatch($ticketIndexText, '(?m)^\| ID \| Titre \| Phase \| [^|]+ \| Statut \|\r?$')) {
        $issues.Add('Ticket README has an invalid index schema.')
    }
    $indexRows = @(Get-DataRows -Path $ticketIndexPath -RowPattern '^\| T[^|]+\|')
    if ($indexRows.Count -eq 0) {
        $issues.Add('Ticket README must contain the canonical ticket index.')
        return $issues
    }

    $allowedTicketStatuses = @(
        'Draft', 'Ready', 'In progress', 'Review', 'Verify', 'Done',
        'Blocked', 'Rejected', 'Superseded'
    )
    $indexById = @{}
    foreach ($row in $indexRows) {
        if ($row.Cells.Count -ne 5) {
            $issues.Add("Ticket index line $($row.Line) must contain exactly 5 columns.")
            continue
        }
        $id = $row.Cells[0]
        $status = $row.Cells[4]
        if ($id -notmatch '^T\d{4}$') {
            $issues.Add("Invalid ticket identifier at index line $($row.Line): $id")
            continue
        }
        if ($indexById.ContainsKey($id)) {
            $issues.Add("Duplicate ticket index identifier: $id")
        }
        else {
            $indexById[$id] = $status
        }
        if ($status -notin $allowedTicketStatuses) {
            $issues.Add("Invalid ticket index status for ${id}: $status")
        }
    }

    $ticketFiles = @(Get-ChildItem -LiteralPath $ticketsRoot -Filter 'T????-*.md' -File)
    foreach ($ticketFile in $ticketFiles) {
        if ($ticketFile.BaseName -notmatch '^(T\d{4})-') {
            $issues.Add("Invalid ticket filename: $($ticketFile.Name)")
            continue
        }
        $ticketId = $Matches[1]
        $statusLine = @(Select-String -LiteralPath $ticketFile.FullName -Pattern '^Status: (.+)$')
        if ($statusLine.Count -ne 1) {
            $issues.Add("Ticket $ticketId must contain exactly one Status field.")
            continue
        }
        $ticketStatus = $statusLine[0].Matches[0].Groups[1].Value.Trim()
        if ($ticketStatus -notin $allowedTicketStatuses) {
            $issues.Add("Invalid status in ticket ${ticketId}: $ticketStatus")
        }
        if (-not $indexById.ContainsKey($ticketId)) {
            $issues.Add("Ticket $ticketId is missing from docs/tickets/README.md.")
        }
        elseif ($indexById[$ticketId] -ne $ticketStatus) {
            $issues.Add("Ticket $ticketId status differs: index '$($indexById[$ticketId])', file '$ticketStatus'.")
        }
    }
    foreach ($ticketId in $indexById.Keys) {
        if (@(Get-ChildItem -LiteralPath $ticketsRoot -Filter "$ticketId-*.md" -File).Count -ne 1) {
            $issues.Add("Ticket index entry $ticketId has no unique ticket file.")
        }
    }

    $sourceRoots = @('apps', 'eng', 'scripts', 'supabase/functions')
    $sourceExtensions = @('.cs', '.json', '.ps1', '.rs', '.ts', '.tsx')
    foreach ($relativeRoot in $sourceRoots) {
        $sourceRoot = Join-Path $Root $relativeRoot
        if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
            continue
        }
        $sourceFiles = Get-ChildItem -LiteralPath $sourceRoot -Recurse -File | Where-Object {
            $_.Extension -in $sourceExtensions -and
            $_.FullName -notmatch '[\\/](bin|coverage|node_modules|obj|target)[\\/]'
        }
        foreach ($sourceFile in $sourceFiles) {
            $lineMatches = @(Select-String -LiteralPath $sourceFile.FullName -Pattern '\b(?:TODO|FIXME|HACK|XXX)\b' -AllMatches)
            foreach ($lineMatch in $lineMatches) {
                foreach ($markerMatch in $lineMatch.Matches) {
                    $markerText = $lineMatch.Line.Substring($markerMatch.Index)
                    if ($markerText -notmatch '^(?:TODO|FIXME|HACK|XXX)\(KI-(\d{3})\):') {
                        $separator = [System.IO.Path]::DirectorySeparatorChar
                        $rootPrefix = $Root.TrimEnd($separator) + $separator
                        $relativePath = if ($sourceFile.FullName.StartsWith(
                            $rootPrefix,
                            [System.StringComparison]::OrdinalIgnoreCase
                        )) {
                            $sourceFile.FullName.Substring($rootPrefix.Length)
                        }
                        else {
                            $sourceFile.FullName
                        }
                        $issues.Add("Untracked debt marker at ${relativePath}:$($lineMatch.LineNumber). Use TODO(KI-NNN): or remove it.")
                        continue
                    }
                    $issueId = "KI-$($Matches[1])"
                    if (-not $knownById.ContainsKey($issueId)) {
                        $issues.Add("Debt marker references unknown issue $issueId at $($sourceFile.FullName):$($lineMatch.LineNumber).")
                    }
                    elseif ($knownById[$issueId] -notin @('Open', 'Scheduled')) {
                        $issues.Add("Debt marker references inactive issue $issueId at $($sourceFile.FullName):$($lineMatch.LineNumber).")
                    }
                }
            }
        }
    }

    return $issues
}

function Copy-MaintenanceFixture {
    param(
        [Parameter(Mandatory)]
        [string]$SourceRoot,

        [Parameter(Mandatory)]
        [string]$DestinationRoot
    )

    New-Item -ItemType Directory -Force -Path (Join-Path $DestinationRoot 'docs/tickets') | Out-Null
    Copy-Item -LiteralPath (Join-Path $SourceRoot 'docs/KNOWN_ISSUES.md') -Destination (Join-Path $DestinationRoot 'docs/KNOWN_ISSUES.md')
    Copy-Item -LiteralPath (Join-Path $SourceRoot 'docs/tickets/README.md') -Destination (Join-Path $DestinationRoot 'docs/tickets/README.md')
    Get-ChildItem -LiteralPath (Join-Path $SourceRoot 'docs/tickets') -Filter 'T*.md' -File |
        Copy-Item -Destination (Join-Path $DestinationRoot 'docs/tickets')
    # Les fonctionnalités résolvent les dettes au même titre que les tickets :
    # la fixture doit donc les porter, sinon une entrée `Resolved` citant une
    # `FXXXX` réelle serait rejetée dans le harnais alors qu'elle est valide.
    New-Item -ItemType Directory -Force -Path (Join-Path $DestinationRoot 'docs/features') | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $SourceRoot 'docs/features') -Filter 'F*.md' -File |
        Copy-Item -Destination (Join-Path $DestinationRoot 'docs/features')
    New-Item -ItemType Directory -Force -Path (Join-Path $DestinationRoot 'apps/fixture') | Out-Null
}

function Get-AvailableFixtureId {
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [string]$Prefix,

        [Parameter(Mandatory)]
        [int]$Maximum,

        [Parameter(Mandatory)]
        [string]$Format
    )

    for ($candidate = $Maximum; $candidate -ge 1; $candidate--) {
        $identifier = $Prefix + $candidate.ToString($Format)
        if ($Text -notmatch "(?m)^\| $([regex]::Escape($identifier)) \|") {
            return $identifier
        }
    }

    throw "No synthetic $Prefix identifier is available for the maintenance self-test."
}

function Reset-KnownIssuesFixture {
    param(
        [Parameter(Mandatory)]
        [string]$SourceRoot,

        [Parameter(Mandatory)]
        [string]$DestinationPath,

        [Parameter(Mandatory)]
        [string]$FixtureIssueId
    )

    Copy-Item -Force -LiteralPath (Join-Path $SourceRoot 'docs/KNOWN_ISSUES.md') -Destination $DestinationPath
    $knownText = Get-Content -Raw -Encoding UTF8 -LiteralPath $DestinationPath
    $fixtureRow = "| $FixtureIssueId | Medium | Harness | Synthetic maintenance self-test issue. | Generated only inside the temporary fixture. | Harness self-test | Scheduled |"
    $knownText += "`r`n$fixtureRow`r`n"
    [System.IO.File]::WriteAllText($DestinationPath, $knownText)
}

function Add-TicketFixture {
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [Parameter(Mandatory)]
        [string]$FixtureTicketId
    )

    $ticketIndexPath = Join-Path $Root 'docs/tickets/README.md'
    $ticketIndexText = Get-Content -Raw -Encoding UTF8 -LiteralPath $ticketIndexPath
    $ticketIndexText += "`r`n| $FixtureTicketId | Maintenance self-test fixture | Harness | none | Ready |`r`n"
    [System.IO.File]::WriteAllText($ticketIndexPath, $ticketIndexText)

    $ticketPath = Join-Path $Root "docs/tickets/$FixtureTicketId-maintenance-self-test.md"
    [System.IO.File]::WriteAllText($ticketPath, "# $FixtureTicketId - Maintenance self-test fixture`r`n`r`nStatus: Ready`r`n")
}

function Assert-MaintenanceIssue {
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [Parameter(Mandatory)]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [string]$FailureMessage
    )

    $actualIssues = @(Get-MaintenanceIssues -Root $Root)
    if (-not ($actualIssues -match $Pattern)) {
        $details = if ($actualIssues.Count -eq 0) {
            'no maintenance issue was reported'
        }
        else {
            $actualIssues -join '; '
        }
        throw "$FailureMessage Actual result: $details."
    }
}

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$repositoryIssues = @(Get-MaintenanceIssues -Root $repositoryRoot)
if ($repositoryIssues.Count -gt 0) {
    $repositoryIssues | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    exit 1
}

$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    'thrustline-maintenance-' + [Guid]::NewGuid().ToString('N')
)
try {
    Copy-MaintenanceFixture -SourceRoot $repositoryRoot -DestinationRoot $temporaryRoot

    $knownIssuesCopy = Join-Path $temporaryRoot 'docs/KNOWN_ISSUES.md'
    $repositoryKnownText = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $repositoryRoot 'docs/KNOWN_ISSUES.md')
    $fixtureIssueId = Get-AvailableFixtureId -Text $repositoryKnownText -Prefix 'KI-' -Maximum 999 -Format '000'
    $repositoryTicketIndexText = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $repositoryRoot 'docs/tickets/README.md')
    $fixtureTicketId = Get-AvailableFixtureId -Text $repositoryTicketIndexText -Prefix 'T' -Maximum 9999 -Format '0000'
    Reset-KnownIssuesFixture -SourceRoot $repositoryRoot -DestinationPath $knownIssuesCopy -FixtureIssueId $fixtureIssueId
    Add-TicketFixture -Root $temporaryRoot -FixtureTicketId $fixtureTicketId

    $knownText = Get-Content -Raw -Encoding UTF8 -LiteralPath $knownIssuesCopy
    $knownText = $knownText.Replace("| $fixtureIssueId | Medium |", "| $fixtureIssueId | Urgent |")
    [System.IO.File]::WriteAllText($knownIssuesCopy, $knownText)
    Assert-MaintenanceIssue -Root $temporaryRoot -Pattern "Invalid severity for $fixtureIssueId" -FailureMessage 'Harness self-test failed to detect an invalid severity.'

    Reset-KnownIssuesFixture -SourceRoot $repositoryRoot -DestinationPath $knownIssuesCopy -FixtureIssueId $fixtureIssueId
    $knownText = Get-Content -Raw -Encoding UTF8 -LiteralPath $knownIssuesCopy
    $knownText = [regex]::Replace(
        $knownText,
        '(?m)^\| ID \| [^|]+ \| Zone \| [^|]+ \| Preuve \| Ticket cible \| Statut \|\r?$',
        '| ID | invalid-schema |'
    )
    [System.IO.File]::WriteAllText($knownIssuesCopy, $knownText)
    Assert-MaintenanceIssue -Root $temporaryRoot -Pattern 'invalid table schema' -FailureMessage 'Harness self-test failed to detect an invalid registry schema.'

    Reset-KnownIssuesFixture -SourceRoot $repositoryRoot -DestinationPath $knownIssuesCopy -FixtureIssueId $fixtureIssueId
    $knownText = Get-Content -Raw -Encoding UTF8 -LiteralPath $knownIssuesCopy
    $fixtureIssueRow = ([regex]::Match($knownText, "(?m)^\| $([regex]::Escape($fixtureIssueId)) .+$")).Value
    $invalidStatusRow = $fixtureIssueRow.Replace('| Scheduled |', '| Waiting |')
    $knownText = $knownText.Replace($fixtureIssueRow, $invalidStatusRow)
    [System.IO.File]::WriteAllText($knownIssuesCopy, $knownText)
    Assert-MaintenanceIssue -Root $temporaryRoot -Pattern "Invalid status for $fixtureIssueId" -FailureMessage 'Harness self-test failed to detect an invalid issue status.'

    Reset-KnownIssuesFixture -SourceRoot $repositoryRoot -DestinationPath $knownIssuesCopy -FixtureIssueId $fixtureIssueId
    $knownText = Get-Content -Raw -Encoding UTF8 -LiteralPath $knownIssuesCopy
    $fixtureIssueRow = ([regex]::Match($knownText, "(?m)^\| $([regex]::Escape($fixtureIssueId)) .+$")).Value
    $missingEvidence = [regex]::Replace($fixtureIssueRow, "^(\| $([regex]::Escape($fixtureIssueId)) \|[^|]+\|[^|]+\|[^|]+\|)[^|]+(\|)", '$1  $2')
    $knownText = $knownText.Replace($fixtureIssueRow, $missingEvidence)
    [System.IO.File]::WriteAllText($knownIssuesCopy, $knownText)
    Assert-MaintenanceIssue -Root $temporaryRoot -Pattern "$fixtureIssueId has no evidence" -FailureMessage 'Harness self-test failed to detect missing evidence.'

    # Aucune mutation ne couvrait la règle des entrées `Resolved` avant que
    # celle-ci n'apprenne les `FXXXX` : les deux chemins d'échec sont désormais
    # prouvés — une dette résolue sans unité citée, et une dette résolue par une
    # unité qui n'existe pas.
    Reset-KnownIssuesFixture -SourceRoot $repositoryRoot -DestinationPath $knownIssuesCopy -FixtureIssueId $fixtureIssueId
    $knownText = Get-Content -Raw -Encoding UTF8 -LiteralPath $knownIssuesCopy
    $fixtureIssueRow = ([regex]::Match($knownText, "(?m)^\| $([regex]::Escape($fixtureIssueId)) .+$")).Value
    $unreferencedResolvedRow = $fixtureIssueRow.Replace('| Harness self-test | Scheduled |', '| Harness self-test | Resolved |')
    $knownText = $knownText.Replace($fixtureIssueRow, $unreferencedResolvedRow)
    [System.IO.File]::WriteAllText($knownIssuesCopy, $knownText)
    Assert-MaintenanceIssue -Root $temporaryRoot -Pattern "Resolved issue $fixtureIssueId must reference a ticket or a feature" -FailureMessage 'Harness self-test failed to detect a resolved issue citing no unit.'

    Reset-KnownIssuesFixture -SourceRoot $repositoryRoot -DestinationPath $knownIssuesCopy -FixtureIssueId $fixtureIssueId
    $knownText = Get-Content -Raw -Encoding UTF8 -LiteralPath $knownIssuesCopy
    $fixtureIssueRow = ([regex]::Match($knownText, "(?m)^\| $([regex]::Escape($fixtureIssueId)) .+$")).Value
    $missingFeatureRow = $fixtureIssueRow.Replace('| Harness self-test | Scheduled |', '| F9999 | Resolved |')
    $knownText = $knownText.Replace($fixtureIssueRow, $missingFeatureRow)
    [System.IO.File]::WriteAllText($knownIssuesCopy, $knownText)
    Assert-MaintenanceIssue -Root $temporaryRoot -Pattern "Resolved issue $fixtureIssueId references missing or ambiguous feature F9999" -FailureMessage 'Harness self-test failed to detect a resolved issue citing a missing feature.'

    Reset-KnownIssuesFixture -SourceRoot $repositoryRoot -DestinationPath $knownIssuesCopy -FixtureIssueId $fixtureIssueId
    $knownText = Get-Content -Raw -Encoding UTF8 -LiteralPath $knownIssuesCopy
    $firstRow = ([regex]::Match($knownText, '(?m)^\| KI-001 .+$')).Value
    $knownText = $knownText.Replace($firstRow, "$firstRow`r`n$firstRow")
    [System.IO.File]::WriteAllText($knownIssuesCopy, $knownText)
    Assert-MaintenanceIssue -Root $temporaryRoot -Pattern 'Duplicate known-issue identifier: KI-001' -FailureMessage 'Harness self-test failed to detect a duplicate issue.'

    Reset-KnownIssuesFixture -SourceRoot $repositoryRoot -DestinationPath $knownIssuesCopy -FixtureIssueId $fixtureIssueId
    $ticketCopy = Get-ChildItem -LiteralPath (Join-Path $temporaryRoot 'docs/tickets') -Filter "$fixtureTicketId-*.md" -File
    $ticketText = Get-Content -Raw -Encoding UTF8 -LiteralPath $ticketCopy.FullName
    $ticketText = $ticketText.Replace('Status: Ready', 'Status: Review')
    [System.IO.File]::WriteAllText($ticketCopy.FullName, $ticketText)
    Assert-MaintenanceIssue -Root $temporaryRoot -Pattern "Ticket $fixtureTicketId status differs" -FailureMessage 'Harness self-test failed to detect ticket/index drift.'

    [System.IO.File]::WriteAllText($ticketCopy.FullName, "# $fixtureTicketId - Maintenance self-test fixture`r`n`r`nStatus: Ready`r`n")
    $markerPath = Join-Path $temporaryRoot 'apps/fixture/debt.ts'
    [System.IO.File]::WriteAllText($markerPath, '// TODO: untracked debt')
    Assert-MaintenanceIssue -Root $temporaryRoot -Pattern 'Untracked debt marker' -FailureMessage 'Harness self-test failed to detect an untracked debt marker.'

    [System.IO.File]::WriteAllText($markerPath, "// TODO($fixtureIssueId): tracked; FIXME: untracked debt")
    Assert-MaintenanceIssue -Root $temporaryRoot -Pattern 'Untracked debt marker' -FailureMessage 'Harness self-test failed to detect a second untracked marker on a tracked line.'

    [System.IO.File]::WriteAllText($markerPath, "// TODO($fixtureIssueId): tracked governance debt")
    if (@(Get-MaintenanceIssues -Root $temporaryRoot).Count -ne 0) {
        throw 'Harness self-test rejected a debt marker linked to a scheduled issue.'
    }

    $currentStateCopy = Join-Path $temporaryRoot 'docs/CURRENT_STATE.md'
    [System.IO.File]::WriteAllText($currentStateCopy, ("# Fixture" + ("`r`nligne de recit ressuscite par une fusion" * 205)))
    Assert-MaintenanceIssue -Root $temporaryRoot -Pattern 'CURRENT_STATE.md exceeds its 200-line budget' -FailureMessage 'Harness self-test failed to detect an oversized current state.'
    Remove-Item -LiteralPath $currentStateCopy
    if (@(Get-MaintenanceIssues -Root $temporaryRoot).Count -ne 0) {
        throw 'Harness self-test rejected a fixture without a current state file.'
    }
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}

Write-Output 'Maintenance checks passed (registry, ticket and feature references, debt markers, current-state budget and 11 mutation scenarios).'
