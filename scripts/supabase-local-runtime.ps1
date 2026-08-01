Set-StrictMode -Version Latest

$script:SupabaseCliImage = "thrustline/supabase-cli:2.109.1-t0021.2"
$script:SupabaseDindImage = "docker:29.6.2-dind@sha256:bfec1f5159c63a81ca6fdedbd81404d2c0e16378ed0feec3bb3fbf3998847659"
$script:SupabaseEngineContainer = "thrustline-local-engine"
$script:SupabaseControlNetwork = "thrustline-local-control"
$script:SupabaseProjectVolume = "thrustline-local-project"
$script:SupabaseEngineCacheVolume = "thrustline-local-engine-cache"
$script:SupabaseProjectId = "thrustline-ng"

function Test-DockerResourceExists {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("container", "image", "network", "volume")]
        [string]$ResourceType,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$DockerPath
    )

    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & $DockerPath $ResourceType inspect $Name *> $null
        return $LASTEXITCODE -eq 0
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
}

function Initialize-SupabaseCliImage {
    param(
        [Parameter(Mandatory)]
        [string]$DockerPath,

        [Parameter(Mandatory)]
        [string]$RepositoryRoot
    )

    if (Test-DockerResourceExists -ResourceType image -Name $script:SupabaseCliImage -DockerPath $DockerPath) {
        return
    }

    $containerfile = Join-Path $RepositoryRoot "scripts\supabase-local-cli.Containerfile"
    $emptyContext = Join-Path ([System.IO.Path]::GetTempPath()) (
        "thrustline-supabase-cli-build-" + [Guid]::NewGuid().ToString("N")
    )
    try {
        New-Item -ItemType Directory -Path $emptyContext | Out-Null
        & $DockerPath build `
            --file $containerfile `
            --tag $script:SupabaseCliImage `
            $emptyContext
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to build the integrity-pinned Supabase CLI image."
        }
    }
    finally {
        if (Test-Path -LiteralPath $emptyContext) {
            Remove-Item -LiteralPath $emptyContext -Recurse -Force
        }
    }
}

function Copy-SupabaseProjectToEngine {
    param(
        [Parameter(Mandatory)]
        [string]$DockerPath,

        [Parameter(Mandatory)]
        [string]$RepositoryRoot
    )

    $source = Join-Path $RepositoryRoot "supabase"
    $stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
        "thrustline-supabase-project-" + [Guid]::NewGuid().ToString("N")
    )
    try {
        New-Item -ItemType Directory -Path $stagingRoot | Out-Null
        Copy-Item -LiteralPath $source -Destination $stagingRoot -Recurse
        $stagedProject = Join-Path $stagingRoot "supabase"
        $ephemeralState = Join-Path $stagedProject ".temp"
        if (Test-Path -LiteralPath $ephemeralState) {
            Remove-Item -LiteralPath $ephemeralState -Recurse -Force
        }

        $forbiddenFiles = @(
            Get-ChildItem -LiteralPath $stagedProject -Recurse -Force -File |
                Where-Object {
                    $_.Name -eq ".env" -or
                    $_.Name -like ".env.*" -or
                    $_.Extension -in @(".pem", ".pfx", ".key")
                }
        )
        if ($forbiddenFiles.Count -gt 0) {
            throw "Refusing to copy secret-capable files into the isolated Supabase runtime."
        }

        & $DockerPath cp $stagedProject "${script:SupabaseEngineContainer}:/workspace/"
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to copy the bounded Supabase project into the isolated runtime."
        }
    }
    finally {
        if (Test-Path -LiteralPath $stagingRoot) {
            Remove-Item -LiteralPath $stagingRoot -Recurse -Force
        }
    }
}

function Wait-SupabaseEngine {
    param(
        [Parameter(Mandatory)]
        [string]$DockerPath
    )

    foreach ($attempt in 1..60) {
        $previousPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = "Continue"
            & $DockerPath exec $script:SupabaseEngineContainer docker info *> $null
            $engineReady = $LASTEXITCODE -eq 0
        }
        finally {
            $ErrorActionPreference = $previousPreference
        }
        if ($engineReady) {
            return
        }
        Start-Sleep -Seconds 1
    }

    throw "The isolated Docker engine did not become ready."
}

function Invoke-IsolatedSupabaseCli {
    param(
        [Parameter(Mandatory)]
        [string]$DockerPath,

        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [switch]$SuppressOutput
    )

    $dockerArguments = @(
        "run",
        "--rm",
        "--network", $script:SupabaseControlNetwork,
        "--env", "DOCKER_HOST=tcp://$($script:SupabaseEngineContainer):2375",
        "--env", "DO_NOT_TRACK=1",
        "--env", "SUPABASE_TELEMETRY_DISABLED=1",
        "--env", "COMPANY_OPENING_BALANCE_MINOR=43000000",
        "--env", "COMPANY_OPENING_CURRENCY=EUR",
        "--volume", "${script:SupabaseProjectVolume}:/workspace",
        "--workdir", "/workspace",
        $script:SupabaseCliImage
    ) + $Arguments

    $commandOutput = @()
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        if ($SuppressOutput) {
            $commandOutput = @(& $DockerPath @dockerArguments 2>&1)
        }
        else {
            & $DockerPath @dockerArguments
        }
        $commandExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    if ($commandExitCode -ne 0) {
        $safeTail = @(
            $commandOutput |
                ForEach-Object {
                    ([string]$_) -replace
                        '(?i)(anon key|service_role key|secret key|access token|password|jwt)(\s*[:=]).*',
                        '$1$2 <redacted>'
                } |
                Select-Object -Last 20
        )
        $detail = if ($safeTail.Count -gt 0) { " $($safeTail -join ' | ')" } else { "" }
        throw "Supabase CLI command failed inside the isolated runtime.$detail"
    }
}

function Assert-SupabaseOuterBindings {
    param(
        [Parameter(Mandatory)]
        [string]$DockerPath
    )

    $inspectionText = & $DockerPath container inspect $script:SupabaseEngineContainer
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to inspect the isolated Supabase engine."
    }
    $inspection = @($inspectionText | ConvertFrom-Json)[0]
    $portBindings = $inspection.HostConfig.PortBindings
    foreach ($containerPort in @("54321/tcp", "54322/tcp", "54323/tcp")) {
        $bindings = @($portBindings.$containerPort)
        if ($bindings.Count -ne 1 -or
            $bindings[0].HostIp -ne "127.0.0.1" -or
            $bindings[0].HostPort -ne $containerPort.Replace("/tcp", "")) {
            throw "Supabase port $containerPort is not bound exclusively to IPv4 loopback."
        }
    }

    $publishedPorts = @(& $DockerPath port $script:SupabaseEngineContainer)
    if ($LASTEXITCODE -ne 0 -or
        $publishedPorts.Count -ne 3 -or
        @($publishedPorts | Where-Object { $_ -match "0\.0\.0\.0:|\[::\]:" }).Count -gt 0) {
        throw "The isolated Supabase engine exposes an unsafe or unexpected host binding."
    }
}

function Remove-SupabaseLocalRuntime {
    param(
        [Parameter(Mandatory)]
        [string]$DockerPath,

        [switch]$PreserveImageCache
    )

    if (Test-DockerResourceExists -ResourceType container -Name $script:SupabaseEngineContainer -DockerPath $DockerPath) {
        & $DockerPath rm --force $script:SupabaseEngineContainer *> $null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to remove the isolated Supabase engine."
        }
    }
    if (Test-DockerResourceExists -ResourceType network -Name $script:SupabaseControlNetwork -DockerPath $DockerPath) {
        & $DockerPath network rm $script:SupabaseControlNetwork *> $null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to remove the isolated Supabase control network."
        }
    }
    if (Test-DockerResourceExists -ResourceType volume -Name $script:SupabaseProjectVolume -DockerPath $DockerPath) {
        & $DockerPath volume rm $script:SupabaseProjectVolume *> $null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to remove the isolated Supabase project volume."
        }
    }
    if (-not $PreserveImageCache -and
        (Test-DockerResourceExists -ResourceType volume -Name $script:SupabaseEngineCacheVolume -DockerPath $DockerPath)) {
        & $DockerPath volume rm $script:SupabaseEngineCacheVolume *> $null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to remove the isolated Supabase image cache."
        }
    }
}
