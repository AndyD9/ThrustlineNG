[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$tauriRoot = Join-Path $root 'apps\desktop\src-tauri'

function Get-PackagingIssues {
    param(
        [Parameter(Mandatory = $true)][string]$WindowsConfigText,
        [Parameter(Mandatory = $true)][string]$WorkflowText
    )

    $issues = [System.Collections.Generic.List[string]]::new()
    $config = $WindowsConfigText | ConvertFrom-Json
    $targets = @($config.bundle.targets)

    if ($targets.Count -ne 1 -or $targets[0] -ne 'nsis') {
        $issues.Add('Only the NSIS bundle target is allowed.')
    }
    if ($config.bundle.active -ne $true) {
        $issues.Add('The Windows bundle must be active.')
    }
    if ($config.bundle.createUpdaterArtifacts -ne $false) {
        $issues.Add('Updater artifacts are forbidden in T0014.')
    }
    if ($config.bundle.windows.nsis.installMode -ne 'currentUser') {
        $issues.Add('NSIS must use currentUser install mode.')
    }
    if ($config.bundle.windows.webviewInstallMode.type -ne 'downloadBootstrapper') {
        $issues.Add('Only WebView2 downloadBootstrapper mode is allowed.')
    }
    if ($config.bundle.windows.PSObject.Properties.Name -match
        'certificateThumbprint|timestampUrl|signCommand') {
        $issues.Add('Windows signing configuration is forbidden in T0014.')
    }

    $resourceProperties = @($config.bundle.resources.PSObject.Properties)
    if ($resourceProperties.Count -ne 1 -or
        $resourceProperties[0].Name -ne '../../../artifacts/t0014/staging/bridge/' -or
        [string]$resourceProperties[0].Value -ne 'bridge/') {
        $issues.Add('The complete staged bridge directory must map to bridge/.')
    }

    if ($WorkflowText -notmatch '(?m)^\s+pnpm windows:package:check\s*$' -or
        $WorkflowText -notmatch '(?m)^\s+pnpm windows:package\s*$') {
        $issues.Add('The Windows CI job must validate and build the package.')
    }
    if ($WorkflowText -notmatch 't0014-windows-unsigned-\$\{\{ github\.sha \}\}') {
        $issues.Add('The CI artifact name must explicitly identify T0014 as unsigned.')
    }
    if ($WorkflowText -notmatch
        'apps/desktop/src-tauri/target/x86_64-pc-windows-msvc/release/thrustline-desktop\.exe') {
        $issues.Add('The CI artifact must retain the exact desktop build output from the manifest.')
    }
    if ($WorkflowText -notmatch '(?m)^\s+retention-days:\s*30\s*$') {
        $issues.Add('Unsigned evidence must expire after 30 days.')
    }
    if ($WorkflowText -match '(?m)^\s*(release|create-release|tagName):' -or
        $WorkflowText -match '(?m)^\s+contents:\s*write\s*$') {
        $issues.Add('Release, tag creation and write permissions are forbidden.')
    }

    return $issues
}

$windowsConfigPath = Join-Path $tauriRoot 'tauri.package.conf.json'
$workflowPath = Join-Path $root '.github\workflows\ci.yml'
$buildScriptPath = Join-Path $root 'scripts\build-windows-package.ps1'
$testScriptPath = Join-Path $root 'scripts\test-windows-package.ps1'
$bridgeRustPath = Join-Path $tauriRoot 'src\bridge.rs'

$windowsConfigText = Get-Content -Raw -LiteralPath $windowsConfigPath
$workflowText = Get-Content -Raw -LiteralPath $workflowPath
$buildScript = Get-Content -Raw -LiteralPath $buildScriptPath
$testScript = Get-Content -Raw -LiteralPath $testScriptPath
$bridgeRust = Get-Content -Raw -LiteralPath $bridgeRustPath

$issues = @(Get-PackagingIssues -WindowsConfigText $windowsConfigText -WorkflowText $workflowText)
if ($buildScript -notmatch 'Get-AuthenticodeSignature' -or
    $buildScript -notmatch '\[Security\.Cryptography\.SHA256\]::Create\(\)' -or
    $buildScript -notmatch 'Assert-ChildPath') {
    $issues += 'The build script must bound deletion, hash artifacts and reject signatures.'
}
if ($testScript -notmatch 'ArgumentList\s+@\(''/S'',\s*"/D=\$installRoot"\)' -or
    $testScript -notmatch 'CloseMainWindow' -or
    $testScript -notmatch 'bridgeExecutable\s+--health-check') {
    $issues += 'The package test must install explicitly, close the UI and check the bridge.'
}
if ($bridgeRust -notmatch 'resource_directory\s*\.join\("bridge"\)' -or
    $bridgeRust -notmatch 'THRUSTLINE_BRIDGE_PATH') {
    $issues += 'Release must resolve the bridge from resources and keep the debug override.'
}
if ($issues.Count -gt 0) {
    $issues | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    throw "$($issues.Count) Windows packaging invariant(s) failed."
}

$machineWideMutation = $windowsConfigText.Replace('"currentUser"', '"perMachine"')
$machineWideIssues = @(
    Get-PackagingIssues -WindowsConfigText $machineWideMutation -WorkflowText $workflowText
)
if ($machineWideIssues -notcontains 'NSIS must use currentUser install mode.') {
    throw 'The machine-wide mutation was not detected.'
}

$extraTargetMutation = $windowsConfigText.Replace(
    '"targets": ["nsis"]',
    '"targets": ["nsis", "msi"]'
)
$extraTargetIssues = @(
    Get-PackagingIssues -WindowsConfigText $extraTargetMutation -WorkflowText $workflowText
)
if ($extraTargetIssues -notcontains 'Only the NSIS bundle target is allowed.') {
    throw 'The extra bundle target mutation was not detected.'
}

Write-Host 'Windows packaging invariants and two negative mutations passed.'
