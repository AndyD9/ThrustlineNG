[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sourceRelativePath = 'eng/product-version.json'
$buildScriptRelativePath = 'scripts/build-windows-package.ps1'
$packageTestRelativePath = 'scripts/test-windows-package.ps1'
$expectedTargetIds = @('frontend', 'tauri', 'rustCrate', 'bridge', 'display')

$semanticVersionPattern =
    '^(?<major>0|[1-9]\d*)\.(?<minor>0|[1-9]\d*)\.(?<patch>0|[1-9]\d*)' +
    '(?:-(?<prerelease>(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)' +
    '(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?' +
    '(?:\+(?<build>[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$'
$orderedPrereleasePattern = '^(?:alpha|beta|rc)\.[1-9]\d*$'

function Get-JsonValue {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if ($null -eq $Object -or
        $null -eq $Object.PSObject.Properties[$Name]) {
        return $null
    }
    return $Object.PSObject.Properties[$Name].Value
}

function Get-DeclaredVersion {
    param(
        [Parameter(Mandatory = $true)][string]$TargetId,
        [Parameter(Mandatory = $true)][string]$Text
    )

    switch ($TargetId) {
        { $_ -in @('frontend', 'tauri') } {
            try {
                return [string](Get-JsonValue -Object ($Text | ConvertFrom-Json) -Name 'version')
            }
            catch {
                return ''
            }
        }
        'rustCrate' {
            $match = [regex]::Match($Text, '(?ms)^\[package\].*?^version\s*=\s*"([^"]*)"')
            if (-not $match.Success) { return '' }
            return $match.Groups[1].Value
        }
        'bridge' {
            $match = [regex]::Match($Text, '<Version>([^<]*)</Version>')
            if (-not $match.Success) { return '' }
            return $match.Groups[1].Value
        }
        'display' {
            $match = [regex]::Match($Text, 'PRODUCT_VERSION\s*=\s*"([^"]*)"')
            if (-not $match.Success) { return '' }
            return $match.Groups[1].Value
        }
        default {
            return ''
        }
    }
}

function Get-ProductVersionIssues {
    param(
        [Parameter(Mandatory = $true)][string]$SourceText,
        [Parameter(Mandatory = $true)][hashtable]$TargetTexts,
        [Parameter(Mandatory = $true)][string]$BuildScriptText,
        [Parameter(Mandatory = $true)][string]$PackageTestScriptText
    )

    $issues = [System.Collections.Generic.List[string]]::new()

    try {
        $source = $SourceText | ConvertFrom-Json
    }
    catch {
        $issues.Add('The canonical product version source is not valid JSON.')
        return $issues
    }

    if ([string](Get-JsonValue -Object $source -Name 'schemaVersion') -ne '1') {
        $issues.Add('The canonical source must declare schemaVersion 1.')
    }
    if ([string](Get-JsonValue -Object $source -Name 'channel') -ne 'internal-alpha') {
        $issues.Add('The canonical source must declare the internal alpha channel.')
    }
    if ((Get-JsonValue -Object $source -Name 'publicRelease') -ne $false -or
        (Get-JsonValue -Object $source -Name 'signed') -ne $false) {
        $issues.Add('The internal alpha must stay unsigned and non-public.')
    }

    $version = [string](Get-JsonValue -Object $source -Name 'productVersion')
    $versionMatch = [regex]::Match($version, $semanticVersionPattern)
    if (-not $versionMatch.Success) {
        $issues.Add("The product version is not a valid SemVer 2.0.0 version: $version")
    }
    else {
        if ($versionMatch.Groups['build'].Success) {
            $issues.Add('The canonical product version must carry no build metadata.')
        }
        if ($versionMatch.Groups['major'].Value -ne '0') {
            $issues.Add('Only 0.x.y is allowed before the first public stable release.')
        }
        if (-not $versionMatch.Groups['prerelease'].Success) {
            $issues.Add('The internal alpha must declare an ordered prerelease.')
        }
        elseif ($versionMatch.Groups['prerelease'].Value -notmatch $orderedPrereleasePattern) {
            $issues.Add(
                'The prerelease must be an ordered alpha.N, beta.N or rc.N identifier: ' +
                $versionMatch.Groups['prerelease'].Value
            )
        }
    }

    $buildMetadataPattern = [string](Get-JsonValue -Object $source -Name 'buildMetadataPattern')
    if ([string]::IsNullOrWhiteSpace($buildMetadataPattern)) {
        $issues.Add('The canonical source must bound the internal build metadata pattern.')
    }
    elseif (('+20260804.g0a1b2c3' -notmatch $buildMetadataPattern) -or
        ('+aeb458345' -match $buildMetadataPattern)) {
        $issues.Add('The build metadata pattern must accept +YYYYMMDD.gSHORTSHA only.')
    }

    $template = [string](Get-JsonValue -Object $source -Name 'installerNameTemplate')
    $placeholderCount = ([regex]::Matches($template, '\{productVersion\}')).Count
    $installerName = $template.Replace('{productVersion}', $version)
    if ($placeholderCount -ne 1 -or
        ([regex]::Matches($template, '\{')).Count -ne 1) {
        $issues.Add('The installer template must interpolate the product version exactly once.')
    }
    if ($installerName -ne "Thrustline-$version-win-x64.exe") {
        $issues.Add("The installer name does not carry the product version: $installerName")
    }
    if ($installerName -match '[\\/:]' -or
        $installerName -notmatch '\.exe$') {
        $issues.Add('The installer name must stay a bare .exe filename without any path.')
    }

    $targets = Get-JsonValue -Object $source -Name 'targets'
    $declaredTargetIds = @()
    if ($null -ne $targets) {
        $declaredTargetIds = @($targets.PSObject.Properties.Name)
    }
    foreach ($expectedTargetId in $expectedTargetIds) {
        if ($declaredTargetIds -notcontains $expectedTargetId) {
            $issues.Add("The canonical source no longer covers the target: $expectedTargetId")
        }
    }
    foreach ($declaredTargetId in $declaredTargetIds) {
        if ($expectedTargetIds -notcontains $declaredTargetId) {
            $issues.Add("The canonical source declares an unknown target: $declaredTargetId")
        }
    }

    $independentPaths = @(Get-JsonValue -Object $source -Name 'independentVersions')
    foreach ($declaredTargetId in $declaredTargetIds) {
        $targetPath = [string]$targets.PSObject.Properties[$declaredTargetId].Value
        if ($independentPaths -contains $targetPath) {
            $issues.Add("A target cannot also be declared independent: $targetPath")
        }
        if (-not $TargetTexts.ContainsKey($declaredTargetId)) {
            $issues.Add("The declared target was not readable: $targetPath")
            continue
        }
        $declaredVersion = Get-DeclaredVersion `
            -TargetId $declaredTargetId `
            -Text ([string]$TargetTexts[$declaredTargetId])
        if ($declaredVersion -ne $version) {
            $issues.Add(
                "$targetPath declares '$declaredVersion' instead of the canonical '$version'."
            )
        }
        if ($declaredTargetId -eq 'bridge' -and
            ([string]$TargetTexts[$declaredTargetId]) -notmatch
            '<IncludeSourceRevisionInInformationalVersion>false' +
            '</IncludeSourceRevisionInInformationalVersion>') {
            $issues.Add(
                "$targetPath must disable the commit concatenation added to the .NET " +
                'informational version.'
            )
        }
    }

    if ($BuildScriptText -notmatch 'eng\\product-version\.json' -or
        $BuildScriptText -notmatch 'installerNameTemplate' -or
        $BuildScriptText -notmatch 'productVersion\s*=\s*\$productVersion') {
        $issues.Add(
            'The build script must derive the installer name and the manifest version ' +
            'from the canonical source.'
        )
    }
    if ($PackageTestScriptText -notmatch 'eng\\product-version\.json' -or
        $PackageTestScriptText -notmatch '\$manifest\.productVersion') {
        $issues.Add('The package test must compare the manifest version to the canonical source.')
    }

    return $issues
}

function Read-RepositoryText {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    return Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $repositoryRoot $RelativePath)
}

$sourceText = Read-RepositoryText -RelativePath $sourceRelativePath
$buildScriptText = Read-RepositoryText -RelativePath $buildScriptRelativePath
$packageTestScriptText = Read-RepositoryText -RelativePath $packageTestRelativePath

$targetTexts = @{}
$targetPaths = ($sourceText | ConvertFrom-Json).targets
foreach ($targetProperty in $targetPaths.PSObject.Properties) {
    $targetTexts[$targetProperty.Name] = Read-RepositoryText -RelativePath ([string]$targetProperty.Value)
}

$issues = @(Get-ProductVersionIssues `
        -SourceText $sourceText `
        -TargetTexts $targetTexts `
        -BuildScriptText $buildScriptText `
        -PackageTestScriptText $packageTestScriptText)
if ($issues.Count -gt 0) {
    $issues | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    throw "$($issues.Count) product version invariant(s) failed."
}

function Assert-Mutation {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$ExpectedPattern,
        [string]$MutatedSourceText = $sourceText,
        [hashtable]$MutatedTargetTexts = $targetTexts,
        [string]$MutatedBuildScriptText = $buildScriptText,
        [string]$MutatedPackageTestScriptText = $packageTestScriptText
    )

    $mutationIssues = @(Get-ProductVersionIssues `
            -SourceText $MutatedSourceText `
            -TargetTexts $MutatedTargetTexts `
            -BuildScriptText $MutatedBuildScriptText `
            -PackageTestScriptText $MutatedPackageTestScriptText)
    if (-not ($mutationIssues -match $ExpectedPattern)) {
        $details = if ($mutationIssues.Count -eq 0) {
            'no issue was reported'
        }
        else {
            $mutationIssues -join '; '
        }
        throw "The $Label mutation was not detected. Actual result: $details."
    }
}

$divergentTargets = @{}
foreach ($key in $targetTexts.Keys) {
    $divergentTargets[$key] = $targetTexts[$key]
}
$divergentTargets['frontend'] = ([string]$targetTexts['frontend']).Replace(
    '"version": "0.1.0-alpha.1"',
    '"version": "0.2.0-alpha.1"'
)
Assert-Mutation `
    -Label 'divergent frontend target' `
    -ExpectedPattern 'apps/desktop/package\.json declares ' `
    -MutatedTargetTexts $divergentTargets

Assert-Mutation `
    -Label 'opaque product version' `
    -ExpectedPattern 'not a valid SemVer 2\.0\.0 version' `
    -MutatedSourceText $sourceText.Replace('"0.1.0-alpha.1"', '"1.0aeb458345"')

Assert-Mutation `
    -Label 'desynchronised installer name' `
    -ExpectedPattern 'does not carry the product version' `
    -MutatedSourceText $sourceText.Replace(
        '"Thrustline-{productVersion}-win-x64.exe"',
        '"Thrustline-0.1.0-alpha.0-win-x64.exe"'
    )

Assert-Mutation `
    -Label 'build metadata inside the canonical version' `
    -ExpectedPattern 'must carry no build metadata' `
    -MutatedSourceText $sourceText.Replace(
        '"productVersion": "0.1.0-alpha.1"',
        '"productVersion": "0.1.0-alpha.1+20260804.g0a1b2c3"'
    )

$commitConcatenatedTargets = @{}
foreach ($key in $targetTexts.Keys) {
    $commitConcatenatedTargets[$key] = $targetTexts[$key]
}
$commitConcatenatedTargets['bridge'] = ([string]$targetTexts['bridge']).Replace(
    '<IncludeSourceRevisionInInformationalVersion>false</IncludeSourceRevisionInInformationalVersion>',
    ''
)
Assert-Mutation `
    -Label 'commit concatenated into the bridge informational version' `
    -ExpectedPattern 'must disable the commit concatenation' `
    -MutatedTargetTexts $commitConcatenatedTargets

Assert-Mutation `
    -Label 'build script detached from the canonical source' `
    -ExpectedPattern 'must derive the installer name' `
    -MutatedBuildScriptText $buildScriptText.Replace('eng\product-version.json', 'eng\versions.json')

Write-Host "Product version invariants and 6 negative mutations passed ($($targetTexts.Count) targets)."
