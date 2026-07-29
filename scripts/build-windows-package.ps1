[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$artifactsRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot 'artifacts\t0014'))
$output = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $OutputDirectory))
$staging = [IO.Path]::GetFullPath((Join-Path $artifactsRoot 'staging'))
$bridgeStaging = Join-Path $staging 'bridge'
$bundleDirectory = [IO.Path]::GetFullPath(
    (Join-Path $repositoryRoot 'apps\desktop\src-tauri\target\x86_64-pc-windows-msvc\release\bundle\nsis')
)

function Assert-ChildPath {
    param(
        [Parameter(Mandatory = $true)][string]$Parent,
        [Parameter(Mandatory = $true)][string]$Child,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $parentPrefix = $Parent.TrimEnd('\') + '\'
    if (-not $Child.StartsWith($parentPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label must stay under the approved directory."
    }
}

function Reset-ApprovedDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$Parent,
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$Label
    )

    Assert-ChildPath -Parent $Parent -Child $Target -Label $Label
    if (Test-Path -LiteralPath $Target) {
        Remove-Item -LiteralPath $Target -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Target -Force | Out-Null
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][scriptblock]$Command
    )

    Write-Host "==> $Label"
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}

if ($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitOperatingSystem) {
    throw 'T0014 packaging requires a 64-bit Windows host.'
}

Assert-ChildPath -Parent $artifactsRoot -Child $output -Label 'OutputDirectory'
Assert-ChildPath -Parent $artifactsRoot -Child $staging -Label 'Staging directory'
Reset-ApprovedDirectory -Parent $artifactsRoot -Target $output -Label 'OutputDirectory'
Reset-ApprovedDirectory -Parent $artifactsRoot -Target $staging -Label 'Staging directory'

if (Test-Path -LiteralPath $bundleDirectory) {
    $targetRoot = [IO.Path]::GetFullPath(
        (Join-Path $repositoryRoot 'apps\desktop\src-tauri\target')
    )
    Assert-ChildPath -Parent $targetRoot -Child $bundleDirectory -Label 'Tauri bundle directory'
    Remove-Item -LiteralPath $bundleDirectory -Recurse -Force
}

$expectedVersions = Get-Content -Raw -LiteralPath (
    Join-Path $repositoryRoot 'eng\versions.json'
) | ConvertFrom-Json

$actualNode = (& node --version).TrimStart('v').Trim()
$actualPnpm = (& pnpm.cmd --version).Trim()
$actualDotnet = (& dotnet --version).Trim()
$rustVersionLine = (& rustc --version).Trim()

if ($actualNode -ne [string]$expectedVersions.node) {
    throw "Node version mismatch: expected $($expectedVersions.node), got $actualNode."
}
if ($actualPnpm -ne [string]$expectedVersions.pnpm) {
    throw "pnpm version mismatch: expected $($expectedVersions.pnpm), got $actualPnpm."
}
if ($actualDotnet -ne [string]$expectedVersions.dotnetSdk) {
    throw ".NET SDK version mismatch: expected $($expectedVersions.dotnetSdk), got $actualDotnet."
}
if ($rustVersionLine -notmatch ('^rustc\s+' + [regex]::Escape([string]$expectedVersions.rust) + '\s')) {
    throw "Rust version mismatch: expected $($expectedVersions.rust), got $rustVersionLine."
}

Push-Location $repositoryRoot
try {
    Invoke-Checked 'Restore locked bridge runtime packs' {
        & dotnet restore apps/bridge/Thrustline.Bridge.csproj `
            --runtime win-x64 `
            --locked-mode `
            --configfile .\NuGet.Config `
            --source https://api.nuget.org/v3/index.json
    }
    Invoke-Checked 'Publish self-contained bridge' {
        & dotnet publish apps/bridge/Thrustline.Bridge.csproj `
            --configuration Release `
            --runtime win-x64 `
            --self-contained true `
            --no-restore `
            --output $bridgeStaging
    }

    $bridgeExecutable = Join-Path $bridgeStaging 'Thrustline.Bridge.exe'
    $bridgeRuntimeConfig = Join-Path $bridgeStaging 'Thrustline.Bridge.runtimeconfig.json'
    if (-not (Test-Path -LiteralPath $bridgeExecutable) -or
        -not (Test-Path -LiteralPath $bridgeRuntimeConfig)) {
        throw 'The complete self-contained bridge publication was not staged.'
    }

    Invoke-Checked 'Validate Windows package invariants' {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass `
            -File .\tests\windows-package\run.ps1
    }
    Invoke-Checked 'Build unsigned NSIS package' {
        & pnpm.cmd --dir apps/desktop tauri build `
            --target x86_64-pc-windows-msvc `
            --bundles nsis `
            --config src-tauri/tauri.package.conf.json
    }
}
finally {
    Pop-Location
}

$installers = @(
    Get-ChildItem -LiteralPath $bundleDirectory -Filter '*-setup.exe' -File
)
if ($installers.Count -ne 1) {
    throw "Expected exactly one NSIS installer, found $($installers.Count)."
}

$desktopExecutable = Join-Path $repositoryRoot (
    'apps\desktop\src-tauri\target\x86_64-pc-windows-msvc\release\thrustline-desktop.exe'
)
foreach ($requiredFile in @($desktopExecutable, $bridgeExecutable, $installers[0].FullName)) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Required packaging artifact is missing: $([IO.Path]::GetFileName($requiredFile))."
    }
    $signature = Get-AuthenticodeSignature -LiteralPath $requiredFile
    if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::NotSigned) {
        throw "Expected an unsigned artifact: $([IO.Path]::GetFileName($requiredFile))."
    }
}

$installerDestination = Join-Path $output $installers[0].Name
Copy-Item -LiteralPath $installers[0].FullName -Destination $installerDestination

$bridgeFiles = @(Get-ChildItem -LiteralPath $bridgeStaging -File -Recurse)
$manifestFiles = @(
    [pscustomobject]@{
        role = 'installer'
        path = $installers[0].Name
        bytes = (Get-Item -LiteralPath $installerDestination).Length
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $installerDestination).Hash
        authenticode = 'NotSigned'
    },
    [pscustomobject]@{
        role = 'desktop-build-output'
        path = 'build-output/thrustline-desktop.exe'
        bytes = (Get-Item -LiteralPath $desktopExecutable).Length
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $desktopExecutable).Hash
        authenticode = 'NotSigned'
    },
    [pscustomobject]@{
        role = 'bridge'
        path = 'bridge/Thrustline.Bridge.exe'
        bytes = (Get-Item -LiteralPath $bridgeExecutable).Length
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $bridgeExecutable).Hash
        authenticode = 'NotSigned'
    }
)

$manifest = [ordered]@{
    schemaVersion = 1
    packageType = 'nsis'
    target = 'x86_64-pc-windows-msvc'
    installMode = 'currentUser'
    signed = $false
    webviewInstallMode = 'downloadBootstrapper'
    bridgeFileCount = $bridgeFiles.Count
    bridgeBytes = [long](($bridgeFiles | Measure-Object Length -Sum).Sum)
    files = $manifestFiles
}
$manifest | ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath (Join-Path $output 'package-manifest.json') -Encoding UTF8

Write-Host "Unsigned NSIS package created: $($installers[0].Name)"
Write-Host "Bridge files included: $($bridgeFiles.Count)"
