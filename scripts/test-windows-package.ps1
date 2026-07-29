[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackageDirectory,

    [Parameter(Mandatory = $true)]
    [string]$ValidationDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$artifactsRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot 'artifacts\t0014'))
$packageRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $PackageDirectory))
$validationRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $ValidationDirectory))
$installRoot = Join-Path $validationRoot 'installed'

function Assert-ChildPath {
    param([string]$Parent, [string]$Child, [string]$Label)
    $parentPrefix = $Parent.TrimEnd('\') + '\'
    if (-not $Child.StartsWith($parentPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label must stay under the approved directory."
    }
}

function Wait-Until {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Condition,
        [int]$TimeoutSeconds = 15
    )
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        if (& $Condition) { return $true }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    return $false
}

function Get-AuthenticodeStatus {
    param([Parameter(Mandatory = $true)][string]$Path)

    $powerShell7 = Get-Command pwsh.exe -CommandType Application -ErrorAction SilentlyContinue
    if ($null -ne $powerShell7) {
        $previousTarget = $env:THRUSTLINE_AUTHENTICODE_TARGET
        try {
            $env:THRUSTLINE_AUTHENTICODE_TARGET = $Path
            $status = & $powerShell7.Source -NoProfile -NonInteractive -Command `
                '(Get-AuthenticodeSignature -LiteralPath $env:THRUSTLINE_AUTHENTICODE_TARGET).Status.ToString()'
            $authenticodeExitCode = $LASTEXITCODE
        }
        finally {
            $env:THRUSTLINE_AUTHENTICODE_TARGET = $previousTarget
        }
        if ($authenticodeExitCode -ne 0) {
            throw "PowerShell 7 could not inspect Authenticode: $([IO.Path]::GetFileName($Path))."
        }
        return ($status -join '').Trim()
    }

    return (Get-AuthenticodeSignature -LiteralPath $Path).Status.ToString()
}

function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][string]$Path)

    $stream = [IO.File]::OpenRead($Path)
    try {
        $sha256 = [Security.Cryptography.SHA256]::Create()
        try {
            $hash = $sha256.ComputeHash($stream)
        }
        finally {
            $sha256.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }

    return ([BitConverter]::ToString($hash)).Replace('-', '')
}

Assert-ChildPath -Parent $artifactsRoot -Child $packageRoot -Label 'PackageDirectory'
Assert-ChildPath -Parent $artifactsRoot -Child $validationRoot -Label 'ValidationDirectory'

$manifestPath = Join-Path $packageRoot 'package-manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw 'Package manifest is missing.'
}
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$installerEntry = @($manifest.files | Where-Object role -eq 'installer')
$desktopEntry = @($manifest.files | Where-Object role -eq 'desktop-build-output')
$bridgeEntry = @($manifest.files | Where-Object role -eq 'bridge')
if ($installerEntry.Count -ne 1) {
    throw 'Package manifest must contain exactly one installer.'
}
if ($desktopEntry.Count -ne 1 -or $bridgeEntry.Count -ne 1) {
    throw 'Package manifest must contain exactly one desktop build output and one bridge.'
}
$installer = Join-Path $packageRoot ([string]$installerEntry[0].path)
if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) {
    throw 'Installer referenced by the manifest is missing.'
}
if ((Get-Sha256Hex -Path $installer) -ne
    [string]$installerEntry[0].sha256) {
    throw 'Installer SHA-256 does not match the manifest.'
}
if ((Get-AuthenticodeStatus -Path $installer) -ne 'NotSigned') {
    throw 'Installer must remain unsigned in T0014.'
}
$desktopBuildOutput = Join-Path $repositoryRoot (
    'apps\desktop\src-tauri\target\x86_64-pc-windows-msvc\release\thrustline-desktop.exe'
)
if (-not (Test-Path -LiteralPath $desktopBuildOutput -PathType Leaf) -or
    (Get-Sha256Hex -Path $desktopBuildOutput) -ne
    [string]$desktopEntry[0].sha256) {
    throw 'Desktop build output does not match the package manifest.'
}
if ((Get-AuthenticodeStatus -Path $desktopBuildOutput) -ne 'NotSigned') {
    throw 'Desktop build output must remain unsigned in T0014.'
}

if (@(Get-Process -Name 'Thrustline', 'thrustline-desktop', 'Thrustline.Bridge' `
        -ErrorAction SilentlyContinue).Count -gt 0) {
    throw 'A Thrustline process is already running; validation would be ambiguous.'
}

if (Test-Path -LiteralPath $validationRoot) {
    Remove-Item -LiteralPath $validationRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $validationRoot -Force | Out-Null

$desktopProcess = $null
$uninstaller = Join-Path $installRoot 'uninstall.exe'
try {
    $install = Start-Process -FilePath $installer `
        -ArgumentList @('/S', "/D=$installRoot") `
        -Wait `
        -PassThru
    if ($install.ExitCode -ne 0) {
        throw "NSIS installation failed with exit code $($install.ExitCode)."
    }

    $bridgeExecutable = Join-Path $installRoot 'bridge\Thrustline.Bridge.exe'
    $desktopCandidates = @(
        Get-ChildItem -LiteralPath $installRoot -Filter '*.exe' -File |
            Where-Object Name -ne 'uninstall.exe'
    )
    if ($desktopCandidates.Count -ne 1) {
        throw "Expected one installed desktop executable, found $($desktopCandidates.Count)."
    }
    $desktopExecutable = $desktopCandidates[0].FullName
    if ($desktopCandidates[0].Name -ne 'thrustline-desktop.exe') {
        throw 'Installed desktop filename is unexpected.'
    }
    foreach ($file in @($desktopExecutable, $bridgeExecutable, $uninstaller)) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
            throw "Installed file is missing: $([IO.Path]::GetFileName($file))."
        }
    }
    foreach ($file in @($desktopExecutable, $bridgeExecutable)) {
        if ((Get-AuthenticodeStatus -Path $file) -ne 'NotSigned') {
            throw "Installed binary must remain unsigned: $([IO.Path]::GetFileName($file))."
        }
    }
    if ((Get-Sha256Hex -Path $bridgeExecutable) -ne
        [string]$bridgeEntry[0].sha256) {
        throw 'Installed bridge SHA-256 does not match the package manifest.'
    }

    $desktopProcess = Start-Process -FilePath $desktopExecutable -PassThru
    if (-not (Wait-Until -TimeoutSeconds 20 -Condition {
        $desktopProcess.Refresh()
        -not $desktopProcess.HasExited -and
        $desktopProcess.MainWindowHandle -ne [IntPtr]::Zero -and
        @(Get-Process -Name 'Thrustline.Bridge' -ErrorAction SilentlyContinue).Count -eq 1
    })) {
        throw 'The installed desktop did not start exactly one bridge process.'
    }
    $desktopProcess.Refresh()
    if ($desktopProcess.MainWindowTitle -ne 'Thrustline') {
        throw 'The installed desktop window title is unexpected.'
    }

    if (-not $desktopProcess.CloseMainWindow()) {
        throw 'The installed desktop did not expose a closeable main window.'
    }
    if (-not $desktopProcess.WaitForExit(10000)) {
        throw 'The installed desktop did not exit after closing its window.'
    }
    if (-not (Wait-Until -TimeoutSeconds 10 -Condition {
        @(Get-Process -Name 'Thrustline.Bridge' -ErrorAction SilentlyContinue).Count -eq 0
    })) {
        throw 'The bridge remained after the desktop exited.'
    }

    $healthOutput = & $bridgeExecutable --health-check
    if ($LASTEXITCODE -ne 0 -or ($healthOutput -join "`n").Trim() -ne 'Healthy') {
        throw 'The installed bridge health check did not return Healthy/0.'
    }

    $uninstall = Start-Process -FilePath $uninstaller `
        -ArgumentList '/S' `
        -Wait `
        -PassThru
    if ($uninstall.ExitCode -ne 0) {
        throw "NSIS uninstallation failed with exit code $($uninstall.ExitCode)."
    }
    if (-not (Wait-Until -TimeoutSeconds 15 -Condition {
        -not (Test-Path -LiteralPath $installRoot)
    })) {
        throw 'The installation directory remained after uninstallation.'
    }
}
finally {
    if ($null -ne $desktopProcess -and -not $desktopProcess.HasExited) {
        Stop-Process -Id $desktopProcess.Id -Force -ErrorAction SilentlyContinue
    }
    Get-Process -Name 'Thrustline.Bridge' -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    if ($null -ne $uninstaller -and
        (Test-Path -LiteralPath $uninstaller -PathType Leaf) -and
        (Test-Path -LiteralPath $installRoot)) {
        $cleanup = Start-Process -FilePath $uninstaller `
            -ArgumentList '/S' `
            -Wait `
            -PassThru
        if ($cleanup.ExitCode -ne 0) {
            Write-Warning "Cleanup uninstaller failed with exit code $($cleanup.ExitCode)."
        }
        [void](Wait-Until -TimeoutSeconds 15 -Condition {
            -not (Test-Path -LiteralPath $installRoot)
        })
    }
}

Write-Host 'Unsigned Windows package installation, launch and removal passed.'
