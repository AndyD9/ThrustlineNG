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

# F0005 J1 — la CSP suit le canal produit. `internal-alpha` est le seul canal
# autorisé à élargir `connect-src`, vers le seul loopback Supabase local ; tout
# autre canal embarque la CSP publique, fermée au réseau.
$loopbackCspChannel = 'internal-alpha'
$loopbackCspOrigin = 'http://127.0.0.1:54321'
$channelConfigPattern = 'tauri.channel.*.conf.json'
$loopbackChannelConfigName = "tauri.channel.$loopbackCspChannel.conf.json"

function Get-JsonLeafPaths {
    param(
        [Parameter(Mandatory = $true)][AllowNull()]$Node,
        [string]$Prefix = ''
    )

    $paths = [System.Collections.Generic.List[string]]::new()
    if ($Node -is [System.Management.Automation.PSCustomObject]) {
        foreach ($property in $Node.PSObject.Properties) {
            $childPrefix = if ($Prefix) { "$Prefix.$($property.Name)" } else { $property.Name }
            foreach ($path in (Get-JsonLeafPaths -Node $property.Value -Prefix $childPrefix)) {
                $paths.Add($path)
            }
        }
    }
    else {
        $paths.Add($Prefix)
    }

    return $paths.ToArray()
}

function Get-ChannelCspIssues {
    param(
        [Parameter(Mandatory = $true)][string]$BaseConfigText,
        [Parameter(Mandatory = $true)][string]$ChannelConfigText,
        [Parameter(Mandatory = $true)][string]$PackageConfigText,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$ChannelConfigNames,
        [Parameter(Mandatory = $true)][string]$BuildScriptText
    )

    $issues = [System.Collections.Generic.List[string]]::new()

    $publicCsp = [string]($BaseConfigText | ConvertFrom-Json).app.security.csp
    if (-not $publicCsp.Contains("connect-src 'none'")) {
        $issues.Add("The public channel must embed connect-src 'none'.")
    }
    if ($publicCsp -match '(?i)(https?:|wss?:|\*|unsafe-inline|unsafe-eval)') {
        $issues.Add('The public channel CSP must name no origin and no unsafe directive.')
    }

    $extraChannelConfigs = @(
        $ChannelConfigNames | Where-Object { $_ -ne $loopbackChannelConfigName }
    )
    if ($extraChannelConfigs.Count -gt 0) {
        $issues.Add(
            "Only $loopbackChannelConfigName may override the channel CSP; found " +
            ($extraChannelConfigs -join ', ') + '.'
        )
    }
    if ($ChannelConfigNames -notcontains $loopbackChannelConfigName) {
        $issues.Add("The $loopbackCspChannel channel configuration is missing.")
    }

    $channelConfig = $ChannelConfigText | ConvertFrom-Json
    $leaves = @(Get-JsonLeafPaths -Node $channelConfig)
    $unexpectedLeaves = @($leaves | Where-Object { $_ -notin @('$schema', 'app.security.csp') })
    if ($unexpectedLeaves.Count -gt 0) {
        $issues.Add(
            "The $loopbackCspChannel configuration may override the CSP and nothing else; " +
            'it also declares ' + (($unexpectedLeaves | Sort-Object) -join ', ') + '.'
        )
    }
    if ($leaves -notcontains 'app.security.csp') {
        $issues.Add("The $loopbackCspChannel configuration must declare app.security.csp.")
    }

    # La CSP alpha est la CSP publique, à `connect-src` près : toute autre
    # différence — directive ajoutée, origine supplémentaire, guillemet perdu —
    # rompt cette égalité exacte.
    $expectedChannelCsp = $publicCsp.Replace("connect-src 'none'", "connect-src $loopbackCspOrigin")
    $channelCsp = [string]$channelConfig.app.security.csp
    if ($channelCsp -ne $expectedChannelCsp) {
        $issues.Add(
            "The $loopbackCspChannel CSP must be the public CSP with connect-src " +
            "$loopbackCspOrigin and no other change."
        )
    }

    if ($PackageConfigText -match '(?i)"(security|csp|devCsp)"') {
        $issues.Add('The packaging configuration must not carry any CSP of its own.')
    }

    if ($BuildScriptText -notmatch
        "\`$loopbackCspChannel = '$([regex]::Escape($loopbackCspChannel))'") {
        $issues.Add('The build script must name the single CSP-widening channel.')
    }
    if ($BuildScriptText -notmatch
        "\`$tauriConfigArguments = @\('--config', 'src-tauri/tauri\.package\.conf\.json'\)") {
        $issues.Add('The build script must start from the packaging configuration alone.')
    }
    $appendCount = @(
        [regex]::Matches($BuildScriptText, '\$tauriConfigArguments \+=')
    ).Count
    if ($appendCount -ne 1) {
        $issues.Add("The build script must append exactly one channel configuration, not $appendCount.")
    }
    # Le corps du garde s'arrête à son accolade fermante en début de ligne :
    # l'ajout du `--config` du canal doit tomber à l'intérieur de ce bloc.
    if ($BuildScriptText -notmatch
        ('(?sm)if \(\$productChannel -eq \$loopbackCspChannel\) \{(?:(?!^\}).)*?' +
            '\$tauriConfigArguments \+= @\(''--config'', "src-tauri/\$channelConfigName"\)')) {
        $issues.Add('The build script must apply the channel configuration only for that channel.')
    }
    if ($BuildScriptText -notmatch '\$resolvedCsp -ne \$expectedCsp') {
        $issues.Add('The build script must refuse to build an unexpected embedded CSP.')
    }
    # Le contrôle sur l'artefact ne doit pas pouvoir disparaître en silence :
    # la configuration prouve l'intention, le binaire prouve le résultat.
    if ($BuildScriptText -notmatch 'Compare-Object -ReferenceObject \$expectedConnectSrc') {
        $issues.Add('The build script must compare the connect-src embedded in the built desktop.')
    }

    return $issues
}

$windowsConfigPath = Join-Path $tauriRoot 'tauri.package.conf.json'
$workflowPath = Join-Path $root '.github\workflows\ci.yml'
$buildScriptPath = Join-Path $root 'scripts\build-windows-package.ps1'
$testScriptPath = Join-Path $root 'scripts\test-windows-package.ps1'
$bridgeRustPath = Join-Path $tauriRoot 'src\bridge.rs'

$baseConfigPath = Join-Path $tauriRoot 'tauri.conf.json'
$channelConfigPath = Join-Path $tauriRoot $loopbackChannelConfigName

$windowsConfigText = Get-Content -Raw -LiteralPath $windowsConfigPath
$workflowText = Get-Content -Raw -LiteralPath $workflowPath
$buildScript = Get-Content -Raw -LiteralPath $buildScriptPath
$testScript = Get-Content -Raw -LiteralPath $testScriptPath
$bridgeRust = Get-Content -Raw -LiteralPath $bridgeRustPath
$baseConfigText = Get-Content -Raw -LiteralPath $baseConfigPath
$channelConfigText = Get-Content -Raw -LiteralPath $channelConfigPath
$channelConfigNames = @(
    Get-ChildItem -LiteralPath $tauriRoot -Filter $channelConfigPattern -File |
        Select-Object -ExpandProperty Name
)

$issues = @(Get-PackagingIssues -WindowsConfigText $windowsConfigText -WorkflowText $workflowText)
$issues += @(
    Get-ChannelCspIssues `
        -BaseConfigText $baseConfigText `
        -ChannelConfigText $channelConfigText `
        -PackageConfigText $windowsConfigText `
        -ChannelConfigNames $channelConfigNames `
        -BuildScriptText $buildScript
)
if ($testScript -notmatch '\[string\]\$manifest\.csp -ne \$expectedCsp') {
    $issues += 'The package test must compare the manifest CSP against the channel it declares.'
}
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

# F0005 J1 — six mutations négatives sur la CSP par canal. Chacune est un
# chemin réel par lequel la CSP publique s'ouvrirait ou par lequel le canal
# alpha dépasserait le loopback exact.
$exactChannelIssue = "The $loopbackCspChannel CSP must be the public CSP with connect-src " +
    "$loopbackCspOrigin and no other change."
$cspMutations = @(
    @{
        Label = 'public channel opened to a remote origin'
        Expected = "The public channel must embed connect-src 'none'."
        Base = $baseConfigText.Replace(
            "connect-src 'none'; object-src",
            'connect-src https://api.example.com; object-src'
        )
    },
    @{
        Label = 'alpha channel widened beyond the loopback'
        Expected = $exactChannelIssue
        Channel = $channelConfigText.Replace(
            'connect-src http://127.0.0.1:54321',
            'connect-src http://127.0.0.1:54321 https://api.example.com'
        )
    },
    @{
        Label = 'alpha channel loosening another directive'
        Expected = $exactChannelIssue
        Channel = $channelConfigText.Replace(
            "script-src 'self'",
            "script-src 'self' 'unsafe-inline'"
        )
    },
    @{
        Label = 'alpha channel overriding more than the CSP'
        Expected = 'The internal-alpha configuration may override the CSP and nothing else; ' +
            'it also declares app.security.freezePrototype.'
        Channel = $channelConfigText.Replace(
            '"csp": "default-src',
            '"freezePrototype": false,' + [Environment]::NewLine + '      "csp": "default-src'
        )
    },
    @{
        Label = 'a second channel configuration'
        Expected = "Only $loopbackChannelConfigName may override the channel CSP; " +
            'found tauri.channel.public.conf.json.'
        Names = @($loopbackChannelConfigName, 'tauri.channel.public.conf.json')
    },
    @{
        Label = 'the channel configuration applied unconditionally'
        Expected = 'The build script must start from the packaging configuration alone.'
        Script = $buildScript.Replace(
            "@('--config', 'src-tauri/tauri.package.conf.json')",
            "@('--config', 'src-tauri/tauri.package.conf.json', " +
                "'--config', 'src-tauri/tauri.channel.internal-alpha.conf.json')"
        )
    },
    @{
        Label = 'the embedded connect-src check removed from the build script'
        Expected = 'The build script must compare the connect-src embedded in the built desktop.'
        Script = $buildScript.Replace(
            'Compare-Object -ReferenceObject $expectedConnectSrc',
            'Compare-Object -ReferenceObject @()'
        )
    },
    @{
        Label = 'the channel guard removed from the build script'
        Expected = 'The build script must apply the channel configuration only for that channel.'
        Script = $buildScript.Replace(
            'if ($productChannel -eq $loopbackCspChannel) {',
            'if ($true) {'
        )
    }
)

foreach ($mutation in $cspMutations) {
    $mutatedBase = if ($mutation.ContainsKey('Base')) { $mutation.Base } else { $baseConfigText }
    $mutatedChannel = if ($mutation.ContainsKey('Channel')) { $mutation.Channel } else { $channelConfigText }
    $mutatedNames = if ($mutation.ContainsKey('Names')) { $mutation.Names } else { $channelConfigNames }
    $mutatedScript = if ($mutation.ContainsKey('Script')) { $mutation.Script } else { $buildScript }

    $mutationIssues = @(
        Get-ChannelCspIssues `
            -BaseConfigText $mutatedBase `
            -ChannelConfigText $mutatedChannel `
            -PackageConfigText $windowsConfigText `
            -ChannelConfigNames $mutatedNames `
            -BuildScriptText $mutatedScript
    )
    if ($mutationIssues -notcontains $mutation.Expected) {
        throw "The CSP mutation was not detected: $($mutation.Label)."
    }
}

Write-Host (
    'Windows packaging invariants, the per-channel CSP and ' +
    "$($cspMutations.Count + 2) negative mutations passed."
)
