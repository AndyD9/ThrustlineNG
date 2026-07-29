[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$resolvedOutput = [System.IO.Path]::GetFullPath(
    (Join-Path $repositoryRoot $OutputDirectory)
)
$artifactsRoot = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot "artifacts"))
$artifactsPrefix = $artifactsRoot.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
if ($resolvedOutput -ne $artifactsRoot -and
    -not $resolvedOutput.StartsWith(
        $artifactsPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
    throw "Supply-chain reports must stay under the repository artifacts directory."
}
New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null

Push-Location $repositoryRoot
try {
    $pnpmRaw = & pnpm licenses list --json --long
    if ($LASTEXITCODE -ne 0) {
        throw "pnpm licence inventory failed."
    }
    $pnpmGroups = $pnpmRaw | ConvertFrom-Json
    if ($null -ne $pnpmGroups.PSObject.Properties["error"]) {
        throw "pnpm licence inventory returned an error payload."
    }

    $cargoRaw = & cargo metadata `
        --locked `
        --format-version 1 `
        --manifest-path apps/desktop/src-tauri/Cargo.toml
    if ($LASTEXITCODE -ne 0) {
        throw "Cargo licence inventory failed."
    }
    $cargoMetadata = $cargoRaw | ConvertFrom-Json

    $nugetRaw = & dotnet package list `
        --project ThrustlineNG.slnx `
        --include-transitive `
        --format json `
        --no-restore
    if ($LASTEXITCODE -ne 0) {
        throw "NuGet dependency inventory failed."
    }
    $nugetInventory = $nugetRaw | ConvertFrom-Json
}
finally {
    Pop-Location
}

$entries = [System.Collections.Generic.List[object]]::new()
foreach ($licenseProperty in $pnpmGroups.PSObject.Properties) {
    foreach ($package in @($licenseProperty.Value)) {
        foreach ($version in @($package.versions)) {
            $entries.Add([pscustomobject]@{
                ecosystem = "pnpm"
                name = [string]$package.name
                version = [string]$version
                license = [string]$licenseProperty.Name
            })
        }
    }
}

foreach ($package in @($cargoMetadata.packages | Where-Object { $null -ne $_.source })) {
    $entries.Add([pscustomobject]@{
        ecosystem = "cargo"
        name = [string]$package.name
        version = [string]$package.version
        license = [string]$package.license
    })
}

foreach ($project in @($nugetInventory.projects)) {
    foreach ($framework in @($project.frameworks)) {
        $topLevelPackages = if ($null -ne $framework.PSObject.Properties["topLevelPackages"]) {
            @($framework.topLevelPackages)
        }
        else {
            @()
        }
        $transitivePackages = if ($null -ne $framework.PSObject.Properties["transitivePackages"]) {
            @($framework.transitivePackages)
        }
        else {
            @()
        }
        $nugetPackages = @(
            @($topLevelPackages + $transitivePackages) |
                Where-Object { $null -ne $_ }
        )
        foreach ($package in $nugetPackages) {
            $entries.Add([pscustomobject]@{
                ecosystem = "nuget"
                name = [string]$package.id
                version = [string]$package.resolvedVersion
                license = "NOASSERTION"
            })
        }
    }
}

$deniedPattern = '(?i)(^|[^A-Z])(AGPL|GPL|SSPL|BUSL|UNLICENSED|NOASSERTION|UNKNOWN)([^A-Z]|$)'
$invalid = @(
    $entries | Where-Object {
        [string]::IsNullOrWhiteSpace($_.license) -or $_.license -match $deniedPattern
    }
)
if ($invalid.Count -gt 0) {
    $names = $invalid |
        ForEach-Object { "$($_.ecosystem):$($_.name)@$($_.version) [$($_.license)]" } |
        Sort-Object -Unique
    throw "Missing or denied dependency licences: $($names -join ', ')"
}

$report = [pscustomobject]@{
    schemaVersion = 1
    generatedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
    policy = [pscustomobject]@{
        denied = @("AGPL", "GPL", "SSPL", "BUSL", "UNLICENSED", "NOASSERTION", "UNKNOWN")
        scope = "third-party dependencies from committed lockfiles"
    }
    components = @($entries | Sort-Object ecosystem, name, version -Unique)
}
$reportPath = Join-Path $resolvedOutput "licenses.json"
[System.IO.File]::WriteAllText(
    $reportPath,
    ($report | ConvertTo-Json -Depth 8),
    [System.Text.UTF8Encoding]::new($false)
)
Write-Output "Licence report written with $($entries.Count) third-party components."
