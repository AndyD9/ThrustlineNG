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

    foreach ($requiredPath in @($knownIssuesPath, $ticketIndexPath, $ticketsRoot)) {
        if (-not (Test-Path -LiteralPath $requiredPath)) {
            $issues.Add("Missing maintenance input: $requiredPath")
        }
    }
    if ($issues.Count -gt 0) {
        return $issues
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
            $ticketIds = @([regex]::Matches($target, 'T\d{4}') | ForEach-Object { $_.Value })
            if ($ticketIds.Count -eq 0) {
                $issues.Add("Resolved issue $id must reference a ticket.")
            }
            foreach ($ticketId in $ticketIds) {
                if (@(Get-ChildItem -LiteralPath $ticketsRoot -Filter "$ticketId-*.md" -File).Count -ne 1) {
                    $issues.Add("Resolved issue $id references missing or ambiguous ticket $ticketId.")
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
    New-Item -ItemType Directory -Force -Path (Join-Path $DestinationRoot 'apps/fixture') | Out-Null
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
    $knownText = Get-Content -Raw -Encoding UTF8 -LiteralPath $knownIssuesCopy
    $knownText = $knownText.Replace('| KI-022 | Medium |', '| KI-022 | Urgent |')
    [System.IO.File]::WriteAllText($knownIssuesCopy, $knownText)
    if (@(Get-MaintenanceIssues -Root $temporaryRoot) -notmatch 'Invalid severity for KI-022') {
        throw 'Harness self-test failed to detect an invalid severity.'
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot 'docs/KNOWN_ISSUES.md') -Destination $knownIssuesCopy
    $knownText = Get-Content -Raw -Encoding UTF8 -LiteralPath $knownIssuesCopy
    $knownText = [regex]::Replace(
        $knownText,
        '(?m)^\| ID \| [^|]+ \| Zone \| [^|]+ \| Preuve \| Ticket cible \| Statut \|\r?$',
        '| ID | invalid-schema |'
    )
    [System.IO.File]::WriteAllText($knownIssuesCopy, $knownText)
    if (@(Get-MaintenanceIssues -Root $temporaryRoot) -notmatch 'invalid table schema') {
        throw 'Harness self-test failed to detect an invalid registry schema.'
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot 'docs/KNOWN_ISSUES.md') -Destination $knownIssuesCopy
    $knownText = Get-Content -Raw -Encoding UTF8 -LiteralPath $knownIssuesCopy
    $knownText = $knownText.Replace('| T0030 | Scheduled |', '| T0030 | Waiting |')
    [System.IO.File]::WriteAllText($knownIssuesCopy, $knownText)
    if (@(Get-MaintenanceIssues -Root $temporaryRoot) -notmatch 'Invalid status for KI-022') {
        throw 'Harness self-test failed to detect an invalid issue status.'
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot 'docs/KNOWN_ISSUES.md') -Destination $knownIssuesCopy
    $knownText = Get-Content -Raw -Encoding UTF8 -LiteralPath $knownIssuesCopy
    $ki022 = ([regex]::Match($knownText, '(?m)^\| KI-022 .+$')).Value
    $missingEvidence = [regex]::Replace($ki022, '^(\| KI-022 \|[^|]+\|[^|]+\|[^|]+\|)[^|]+(\|)', '$1  $2')
    $knownText = $knownText.Replace($ki022, $missingEvidence)
    [System.IO.File]::WriteAllText($knownIssuesCopy, $knownText)
    if (@(Get-MaintenanceIssues -Root $temporaryRoot) -notmatch 'KI-022 has no evidence') {
        throw 'Harness self-test failed to detect missing evidence.'
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot 'docs/KNOWN_ISSUES.md') -Destination $knownIssuesCopy
    $knownText = Get-Content -Raw -Encoding UTF8 -LiteralPath $knownIssuesCopy
    $firstRow = ([regex]::Match($knownText, '(?m)^\| KI-001 .+$')).Value
    $knownText = $knownText.Replace($firstRow, "$firstRow`r`n$firstRow")
    [System.IO.File]::WriteAllText($knownIssuesCopy, $knownText)
    if (@(Get-MaintenanceIssues -Root $temporaryRoot) -notmatch 'Duplicate known-issue identifier: KI-001') {
        throw 'Harness self-test failed to detect a duplicate issue.'
    }

    Copy-Item -Force -LiteralPath (Join-Path $repositoryRoot 'docs/KNOWN_ISSUES.md') -Destination $knownIssuesCopy
    $ticketCopy = Get-ChildItem -LiteralPath (Join-Path $temporaryRoot 'docs/tickets') -Filter 'T0030-*.md' -File
    $ticketText = Get-Content -Raw -Encoding UTF8 -LiteralPath $ticketCopy.FullName
    $ticketText = $ticketText.Replace('Status: In progress', 'Status: Review')
    [System.IO.File]::WriteAllText($ticketCopy.FullName, $ticketText)
    if (@(Get-MaintenanceIssues -Root $temporaryRoot) -notmatch 'Ticket T0030 status differs') {
        throw 'Harness self-test failed to detect ticket/index drift.'
    }

    Copy-Item -Force -LiteralPath (Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'docs/tickets') -Filter 'T0030-*.md' -File).FullName -Destination $ticketCopy.FullName
    $markerPath = Join-Path $temporaryRoot 'apps/fixture/debt.ts'
    [System.IO.File]::WriteAllText($markerPath, '// TODO: untracked debt')
    if (@(Get-MaintenanceIssues -Root $temporaryRoot) -notmatch 'Untracked debt marker') {
        throw 'Harness self-test failed to detect an untracked debt marker.'
    }

    [System.IO.File]::WriteAllText($markerPath, '// TODO(KI-022): tracked; FIXME: untracked debt')
    if (@(Get-MaintenanceIssues -Root $temporaryRoot) -notmatch 'Untracked debt marker') {
        throw 'Harness self-test failed to detect a second untracked marker on a tracked line.'
    }

    [System.IO.File]::WriteAllText($markerPath, '// TODO(KI-022): tracked governance debt')
    if (@(Get-MaintenanceIssues -Root $temporaryRoot).Count -ne 0) {
        throw 'Harness self-test rejected a debt marker linked to a scheduled issue.'
    }
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}

Write-Output 'Maintenance checks passed (registry, ticket index, debt markers and 8 mutation scenarios).'
