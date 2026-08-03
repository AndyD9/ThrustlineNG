[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-AuthorityIssues {
    param(
        [Parameter(Mandatory)]
        [string]$Root
    )

    $issues = [System.Collections.Generic.List[string]]::new()
    $inventoryPath = Join-Path $Root "eng\authority-inventory.json"
    $packagePath = Join-Path $Root "package.json"
    if (-not (Test-Path -LiteralPath $inventoryPath -PathType Leaf)) {
        $issues.Add("Missing authority inventory.")
        return $issues
    }
    if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
        $issues.Add("Missing package manifest.")
        return $issues
    }

    try {
        $inventory = Get-Content -Raw -Encoding UTF8 $inventoryPath | ConvertFrom-Json
    }
    catch {
        $issues.Add("Authority inventory is not valid JSON.")
        return $issues
    }

    if ($inventory.schemaVersion -ne 1) {
        $issues.Add("Authority inventory schemaVersion must be 1.")
    }
    if ($inventory.policy.clientTrust -ne "untrusted" -or
        $inventory.policy.mutationRule -ne "server-command-only") {
        $issues.Add("Authority policy must keep clients untrusted and mutations server-command-only.")
    }

    $serviceCommands = @($inventory.policy.serviceOnlyCommands)
    if ($serviceCommands.Count -eq 0 -or $serviceCommands.Count -ne @($serviceCommands | Sort-Object -Unique).Count) {
        $issues.Add("Service-only command inventory must be non-empty and unique.")
    }

    $dataApiReads = @($inventory.policy.clientDataApiReads)
    $dataApiReadPaths = @($dataApiReads | ForEach-Object { ([string]$_.path).Replace('\', '/') })
    if ($dataApiReads.Count -eq 0 -or
        $dataApiReadPaths.Count -ne @($dataApiReadPaths | Sort-Object -Unique).Count) {
        $issues.Add("Client Data API read allowlist must be non-empty and have unique paths.")
    }
    foreach ($read in $dataApiReads) {
        $readPath = ([string]$read.path).Replace('\', '/')
        $resource = [string]$read.resource
        if ([System.IO.Path]::IsPathRooted($readPath) -or
            $readPath -match '(^|/)\.\.(/|$)' -or
            $readPath -notmatch '^apps/(desktop/src|desktop/src-tauri/src|bridge)/' -or
            $resource -notmatch '^[a-z][a-z0-9_]{1,62}$') {
            $issues.Add("Client Data API read allowlist contains an unsafe entry: $readPath")
            continue
        }
        $absoluteReadPath = Join-Path $Root $readPath
        if (-not (Test-Path -LiteralPath $absoluteReadPath -PathType Leaf)) {
            $issues.Add("Client Data API read allowlist path does not exist: $readPath")
            continue
        }
        $readText = Get-Content -Raw -Encoding UTF8 $absoluteReadPath
        if (-not $readText.Contains("/rest/v1/$resource")) {
            $issues.Add("Allowlisted Data API read path does not contain declared resource '$resource': $readPath")
        }
        if ($readText -notmatch '(?i)method\s*:\s*["'']GET["'']' -or
            $readText -match '(?i)method\s*:\s*["''](POST|PUT|PATCH|DELETE)["'']') {
            $issues.Add("Allowlisted Data API read path must use GET only: $readPath")
        }
    }

    $domains = @($inventory.domains)
    $domainIds = @($domains | ForEach-Object { [string]$_.id })
    if ($domainIds.Count -eq 0 -or $domainIds.Count -ne @($domainIds | Sort-Object -Unique).Count) {
        $issues.Add("Domain identifiers must be non-empty and unique.")
    }

    $allowedStatuses = @("server-authoritative", "external-authority", "not-implemented")
    $allowedCoverage = @("complete", "partial", "managed", "none")
    foreach ($domain in $domains) {
        $id = [string]$domain.id
        $status = [string]$domain.status
        $coverage = [string]$domain.coverage
        $boundaries = @($domain.serverBoundaries)
        $evidencePaths = @($domain.evidencePaths)
        $limitations = @($domain.limitations)
        $markerProperty = $domain.PSObject.Properties["evidenceMarkers"]
        $evidenceMarkers = @()
        if ($null -ne $markerProperty) {
            $evidenceMarkers = @($markerProperty.Value)
        }
        $evidenceText = [System.Text.StringBuilder]::new()

        if ($status -notin $allowedStatuses) {
            $issues.Add("Domain '$id' has unsupported authority status '$status'.")
        }
        if ($coverage -notin $allowedCoverage) {
            $issues.Add("Domain '$id' has unsupported coverage '$coverage'.")
        }
        if ($evidencePaths.Count -eq 0) {
            $issues.Add("Domain '$id' has no evidence path.")
        }
        foreach ($relativePath in $evidencePaths) {
            $relative = [string]$relativePath
            if ([System.IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[\\/])\.\.([\\/]|$)') {
                $issues.Add("Domain '$id' has an unsafe evidence path: $relative")
                continue
            }
            if (-not (Test-Path -LiteralPath (Join-Path $Root $relative) -PathType Leaf)) {
                $issues.Add("Domain '$id' evidence path does not exist: $relative")
            }
            else {
                [void]$evidenceText.AppendLine((Get-Content -Raw -Encoding UTF8 (Join-Path $Root $relative)))
            }
        }

        if ($status -eq "not-implemented") {
            if ($coverage -ne "none" -or $boundaries.Count -ne 0) {
                $issues.Add("Not-implemented domain '$id' must have no coverage or server boundary.")
            }
            if ($limitations.Count -eq 0) {
                $issues.Add("Not-implemented domain '$id' must state its missing capability.")
            }
        }
        else {
            if ($coverage -eq "none" -or $boundaries.Count -eq 0) {
                $issues.Add("Implemented domain '$id' must declare coverage and an authority boundary.")
            }
            if ($coverage -eq "partial" -and $limitations.Count -eq 0) {
                $issues.Add("Partial domain '$id' must state its limitations.")
            }
            if ($evidenceMarkers.Count -eq 0) {
                $issues.Add("Implemented domain '$id' must declare authority evidence markers.")
            }
            foreach ($marker in $evidenceMarkers) {
                if (-not $evidenceText.ToString().Contains([string]$marker)) {
                    $issues.Add("Domain '$id' authority marker not found in evidence: $marker")
                }
            }
        }
    }

    $steps = @($inventory.goldenPath)
    $stepNumbers = @($steps | ForEach-Object { [int]$_.step } | Sort-Object)
    if ($steps.Count -ne 10 -or ($stepNumbers -join ',') -ne '1,2,3,4,5,6,7,8,9,10') {
        $issues.Add("Golden path must contain exactly steps 1 through 10.")
    }
    $stepIds = @($steps | ForEach-Object { [string]$_.id })
    if ($stepIds.Count -ne @($stepIds | Sort-Object -Unique).Count) {
        $issues.Add("Golden-path identifiers must be unique.")
    }
    $referencedDomains = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($step in $steps) {
        $references = @($step.domains)
        if ($references.Count -eq 0) {
            $issues.Add("Golden-path step $($step.step) has no mutable domain.")
        }
        foreach ($reference in $references) {
            $domainId = [string]$reference
            [void]$referencedDomains.Add($domainId)
            if ($domainId -notin $domainIds) {
                $issues.Add("Golden-path step $($step.step) references unknown domain '$domainId'.")
            }
        }
    }
    foreach ($domainId in $domainIds) {
        if (-not $referencedDomains.Contains($domainId)) {
            $issues.Add("Domain '$domainId' is not referenced by the golden path.")
        }
    }

    $clientSurfaces = @($inventory.clientSurfaces)
    $requiredSurfaceIds = @("desktop-webview", "desktop-tauri", "local-bridge")
    $surfaceIds = @($clientSurfaces | ForEach-Object { [string]$_.id } | Sort-Object)
    if (($surfaceIds -join ',') -ne (($requiredSurfaceIds | Sort-Object) -join ',')) {
        $issues.Add("Client surfaces must be exactly desktop-webview, desktop-tauri and local-bridge.")
    }

    $escapedCommands = @($serviceCommands | ForEach-Object { [regex]::Escape([string]$_) })
    $forbiddenPatterns = @(
        @{ Pattern = '(?i)SUPABASE_SERVICE_ROLE_KEY|\bservice_role\b'; Message = "privileged service-role reference" },
        @{ Pattern = '(?is)\.from\s*\([^)]*\)\s*\.\s*(insert|update|upsert|delete)\s*\('; Message = "direct Supabase table mutation" },
        @{ Pattern = '(?i)\b(insert\s+into|update\s+(public|private|auth)\.|delete\s+from|truncate\s+table)\b'; Message = "embedded direct SQL mutation" }
    )
    if ($escapedCommands.Count -gt 0) {
        $forbiddenPatterns += @{
            Pattern = '(?i)\b(' + ($escapedCommands -join '|') + ')\b'
            Message = "service-only command reference"
        }
    }

    foreach ($surface in $clientSurfaces) {
        $relativeRoot = [string]$surface.path
        if ([System.IO.Path]::IsPathRooted($relativeRoot) -or $relativeRoot -match '(^|[\\/])\.\.([\\/]|$)') {
            $issues.Add("Client surface '$($surface.id)' has an unsafe path.")
            continue
        }
        $surfaceRoot = Join-Path $Root $relativeRoot
        if (-not (Test-Path -LiteralPath $surfaceRoot -PathType Container)) {
            $issues.Add("Client surface '$($surface.id)' does not exist: $relativeRoot")
            continue
        }
        $sourceExtensions = @($surface.sourceExtensions | ForEach-Object { ([string]$_).ToLowerInvariant() })
        $knownExtensions = @($sourceExtensions + @($surface.nonExecutableExtensions | ForEach-Object { ([string]$_).ToLowerInvariant() }))
        $excludedDirectories = @($surface.excludedDirectories | ForEach-Object { [string]$_ })
        if (@($excludedDirectories | Where-Object { $_ -notin @("bin", "obj") }).Count -gt 0) {
            $issues.Add("Client surface '$($surface.id)' has an unsupported directory exclusion.")
            continue
        }
        if ($sourceExtensions.Count -eq 0) {
            $issues.Add("Client surface '$($surface.id)' has no source extension.")
            continue
        }
        foreach ($file in Get-ChildItem -LiteralPath $surfaceRoot -File -Recurse) {
            $relativeToSurface = $file.FullName.Substring($surfaceRoot.Length).TrimStart('\', '/')
            $segments = @($relativeToSurface -split '[\\/]')
            if (@($segments | Where-Object { $_ -in $excludedDirectories }).Count -gt 0) {
                continue
            }
            $extension = $file.Extension.ToLowerInvariant()
            if ($extension -notin $knownExtensions) {
                $issues.Add("Client surface '$($surface.id)' contains unclassified extension '$extension': $($file.Name)")
                continue
            }
            if ($extension -notin $sourceExtensions) {
                continue
            }
            $text = Get-Content -Raw -Encoding UTF8 $file.FullName
            $relativeFile = $file.FullName.Substring($Root.Length).TrimStart('\', '/').Replace('\', '/')
            $dataApiMatches = @([regex]::Matches($text, '(?i)/rest/v1/([a-z][a-z0-9_]*)'))
            if ($dataApiMatches.Count -gt 0) {
                $allowlistedRead = @($dataApiReads | Where-Object {
                    ([string]$_.path).Replace('\', '/') -eq $relativeFile
                })
                if ($allowlistedRead.Count -ne 1) {
                    $issues.Add("Client source contains undeclared direct Supabase Data API access: $relativeFile")
                }
                else {
                    $declaredResource = [string]$allowlistedRead[0].resource
                    foreach ($match in $dataApiMatches) {
                        if ($match.Groups[1].Value -cne $declaredResource) {
                            $issues.Add("Client source Data API resource differs from allowlist: $relativeFile")
                        }
                    }
                }
            }
            foreach ($rule in $forbiddenPatterns) {
                if ($text -match $rule.Pattern) {
                    $issues.Add("Client source contains $($rule.Message): $relativeFile")
                }
            }
        }
    }

    $package = Get-Content -Raw -Encoding UTF8 $packagePath | ConvertFrom-Json
    if ([string]$package.scripts.'authority:check' -ne
        'powershell -NoProfile -ExecutionPolicy Bypass -File ./tests/authority/run.ps1') {
        $issues.Add("package.json must expose the canonical authority:check command.")
    }

    return $issues
}

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$baselineIssues = @(Get-AuthorityIssues -Root $repositoryRoot)
if ($baselineIssues.Count -gt 0) {
    $baselineIssues | ForEach-Object { Write-Error $_ }
    exit 1
}

function New-AuthorityTestRoot {
    $testRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
        "thrustline-t0024-" + [Guid]::NewGuid().ToString("N")
    )
    New-Item -ItemType Directory -Force -Path $testRoot | Out-Null

    $inventory = Get-Content -Raw -Encoding UTF8 (Join-Path $repositoryRoot "eng\authority-inventory.json") |
        ConvertFrom-Json
    $relativeFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    [void]$relativeFiles.Add("eng\authority-inventory.json")
    [void]$relativeFiles.Add("package.json")
    foreach ($domain in @($inventory.domains)) {
        foreach ($evidencePath in @($domain.evidencePaths)) {
            [void]$relativeFiles.Add(([string]$evidencePath).Replace('/', '\'))
        }
    }
    foreach ($surface in @($inventory.clientSurfaces)) {
        $sourceRoot = Join-Path $repositoryRoot ([string]$surface.path)
        $excludedDirectories = @($surface.excludedDirectories | ForEach-Object { [string]$_ })
        foreach ($file in Get-ChildItem -LiteralPath $sourceRoot -File -Recurse) {
            $relativeToSurface = $file.FullName.Substring($sourceRoot.Length).TrimStart('\', '/')
            $segments = @($relativeToSurface -split '[\\/]')
            if (@($segments | Where-Object { $_ -in $excludedDirectories }).Count -gt 0) {
                continue
            }
            [void]$relativeFiles.Add($file.FullName.Substring($repositoryRoot.Length).TrimStart('\', '/'))
        }
    }
    foreach ($relativeFile in $relativeFiles) {
        $source = Join-Path $repositoryRoot $relativeFile
        $destination = Join-Path $testRoot $relativeFile
        New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination
    }
    return $testRoot
}

$temporaryRoots = [System.Collections.Generic.List[string]]::new()
try {
    $missingStepRoot = New-AuthorityTestRoot
    $temporaryRoots.Add($missingStepRoot)
    $path = Join-Path $missingStepRoot "eng\authority-inventory.json"
    $mutation = Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json
    $mutation.goldenPath = @($mutation.goldenPath | Where-Object step -ne 10)
    [System.IO.File]::WriteAllText($path, ($mutation | ConvertTo-Json -Depth 12), [System.Text.UTF8Encoding]::new($false))
    if (-not (@(Get-AuthorityIssues -Root $missingStepRoot) -match "exactly steps 1 through 10")) {
        throw "Harness self-test failed to detect a missing golden-path step."
    }

    $badStatusRoot = New-AuthorityTestRoot
    $temporaryRoots.Add($badStatusRoot)
    $path = Join-Path $badStatusRoot "eng\authority-inventory.json"
    $mutation = Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json
    ($mutation.domains | Where-Object id -eq "company").status = "client-authoritative"
    [System.IO.File]::WriteAllText($path, ($mutation | ConvertTo-Json -Depth 12), [System.Text.UTF8Encoding]::new($false))
    if (-not (@(Get-AuthorityIssues -Root $badStatusRoot) -match "unsupported authority status")) {
        throw "Harness self-test failed to detect client authority."
    }

    $missingEvidenceRoot = New-AuthorityTestRoot
    $temporaryRoots.Add($missingEvidenceRoot)
    $path = Join-Path $missingEvidenceRoot "eng\authority-inventory.json"
    $mutation = Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json
    ($mutation.domains | Where-Object id -eq "finance").evidenceMarkers = @("missing_authority_marker")
    [System.IO.File]::WriteAllText($path, ($mutation | ConvertTo-Json -Depth 12), [System.Text.UTF8Encoding]::new($false))
    if (-not (@(Get-AuthorityIssues -Root $missingEvidenceRoot) -match "authority marker not found")) {
        throw "Harness self-test failed to detect a missing authority marker."
    }

    $directMutationRoot = New-AuthorityTestRoot
    $temporaryRoots.Add($directMutationRoot)
    $injectedPath = Join-Path $directMutationRoot "apps\desktop\src\direct-mutation.ts"
    [System.IO.File]::WriteAllText($injectedPath, 'client.from("companies").insert({ name: "unsafe" });', [System.Text.UTF8Encoding]::new($false))
    if (-not (@(Get-AuthorityIssues -Root $directMutationRoot) -match "direct Supabase table mutation")) {
        throw "Harness self-test failed to detect a direct client mutation."
    }

    $unknownExtensionRoot = New-AuthorityTestRoot
    $temporaryRoots.Add($unknownExtensionRoot)
    $injectedPath = Join-Path $unknownExtensionRoot "apps\bridge\mutation.py"
    [System.IO.File]::WriteAllText($injectedPath, '# unclassified client language', [System.Text.UTF8Encoding]::new($false))
    if (-not (@(Get-AuthorityIssues -Root $unknownExtensionRoot) -match "unclassified extension")) {
        throw "Harness self-test failed to detect an unclassified client extension."
    }

    $undeclaredReadRoot = New-AuthorityTestRoot
    $temporaryRoots.Add($undeclaredReadRoot)
    $injectedPath = Join-Path $undeclaredReadRoot "apps\desktop\src\undeclared-read.ts"
    [System.IO.File]::WriteAllText($injectedPath, 'new URL("/rest/v1/aircraft_purchase_offers", baseUrl);', [System.Text.UTF8Encoding]::new($false))
    if (-not (@(Get-AuthorityIssues -Root $undeclaredReadRoot) -match "undeclared direct Supabase Data API access")) {
        throw "Harness self-test failed to detect an undeclared Data API read."
    }

    $divergentReadRoot = New-AuthorityTestRoot
    $temporaryRoots.Add($divergentReadRoot)
    $path = Join-Path $divergentReadRoot "apps\desktop\src\features\aircraft-catalog\aircraftCatalog.ts"
    $mutation = (Get-Content -Raw -Encoding UTF8 $path).Replace(
        "/rest/v1/aircraft_purchase_offers",
        "/rest/v1/companies"
    )
    [System.IO.File]::WriteAllText($path, $mutation, [System.Text.UTF8Encoding]::new($false))
    if (-not (@(Get-AuthorityIssues -Root $divergentReadRoot) -match "differs from allowlist")) {
        throw "Harness self-test failed to detect a divergent Data API resource."
    }

    $duplicateReadRoot = New-AuthorityTestRoot
    $temporaryRoots.Add($duplicateReadRoot)
    $path = Join-Path $duplicateReadRoot "eng\authority-inventory.json"
    $mutation = Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json
    $mutation.policy.clientDataApiReads += $mutation.policy.clientDataApiReads[0]
    [System.IO.File]::WriteAllText($path, ($mutation | ConvertTo-Json -Depth 12), [System.Text.UTF8Encoding]::new($false))
    if (-not (@(Get-AuthorityIssues -Root $duplicateReadRoot) -match "must be non-empty and have unique paths")) {
        throw "Harness self-test failed to detect a duplicate Data API allowlist path."
    }

    $orphanReadRoot = New-AuthorityTestRoot
    $temporaryRoots.Add($orphanReadRoot)
    $path = Join-Path $orphanReadRoot "eng\authority-inventory.json"
    $mutation = Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json
    $mutation.policy.clientDataApiReads += [pscustomobject]@{
        path = "apps/desktop/src/features/auth/session.ts"
        resource = "companies"
    }
    [System.IO.File]::WriteAllText($path, ($mutation | ConvertTo-Json -Depth 12), [System.Text.UTF8Encoding]::new($false))
    if (-not (@(Get-AuthorityIssues -Root $orphanReadRoot) -match "does not contain declared resource")) {
        throw "Harness self-test failed to detect an orphaned Data API allowlist entry."
    }
}
finally {
    foreach ($temporaryRoot in $temporaryRoots) {
        if (Test-Path -LiteralPath $temporaryRoot) {
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
        }
    }
}

Write-Output "Authority inventory checks passed (10 golden-path steps, 13 domains, 3 client surfaces, 9 mutation scenarios)."
