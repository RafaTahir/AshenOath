param(
    [string[]]$Profiles = @(),
    [string[]]$ChangedViews = @(),
    [string[]]$ChangedFiles = @(),
    [string]$BaseRef = "HEAD",
    [switch]$DryRun,
    [switch]$NoCache,
    [switch]$ForceWeb
)

$ErrorActionPreference = "Stop"
$Project = Split-Path -Parent $PSScriptRoot
$RepoRoot = Resolve-Path (Join-Path $Project "..\..")
$Godot = "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"
$Python = "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
$ProfilesPath = Join-Path $PSScriptRoot "gate_profiles.json"
$Logs = Join-Path $Project ".release-gate\ticket"
$CacheDirectory = Join-Path $Project ".verification-cache"
$CachePath = Join-Path $CacheDirectory "ticket-gates.json"
$Web = Join-Path (Split-Path -Parent $Project) "AshenOath_Web"

if (!(Test-Path -LiteralPath $ProfilesPath)) { throw "Gate profiles missing: $ProfilesPath" }
$Configuration = Get-Content -LiteralPath $ProfilesPath -Raw | ConvertFrom-Json

function Normalize-Path([string]$Path) {
    return $Path.Replace("\", "/").TrimStart("./")
}

function Get-ChangedFiles {
    if ($ChangedFiles.Count -gt 0) {
        return @($ChangedFiles | ForEach-Object { Normalize-Path $_ } | Sort-Object -Unique)
    }
    $tracked = @(git -C $RepoRoot diff --name-only $BaseRef --)
    $untracked = @(git -C $RepoRoot ls-files --others --exclude-standard)
    return @(($tracked + $untracked) | Where-Object { $_ } | ForEach-Object {
        Normalize-Path $_
    } | Sort-Object -Unique)
}

function Matches-Pattern([string]$Path, [string]$Pattern) {
    return (Normalize-Path $Path) -like (Normalize-Path $Pattern)
}

function Add-Unique([System.Collections.Generic.List[string]]$List, [string]$Value) {
    if (-not $List.Contains($Value)) { $List.Add($Value) }
}

function Get-GateHash([string]$Gate, [string[]]$Files) {
    $builder = [Text.StringBuilder]::new()
    [void]$builder.AppendLine($Gate)
    foreach ($relative in ($Files | Sort-Object -Unique)) {
        $absolute = Join-Path $RepoRoot $relative
        [void]$builder.AppendLine($relative)
        if (Test-Path -LiteralPath $absolute -PathType Leaf) {
            [void]$builder.AppendLine((Get-FileHash -LiteralPath $absolute -Algorithm SHA256).Hash)
        } else {
            [void]$builder.AppendLine("missing")
        }
    }
    $gateScript = Join-Path $PSScriptRoot "$Gate.gd"
    if (Test-Path -LiteralPath $gateScript) {
        [void]$builder.AppendLine((Get-FileHash -LiteralPath $gateScript -Algorithm SHA256).Hash)
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes($builder.ToString())
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "") }
    finally { $sha.Dispose() }
}

function Get-GateInputs([string]$Gate, [string[]]$Files) {
    $selected = [System.Collections.Generic.List[string]]::new()
    $scriptNames = @(
        "outputs/AshenOathTheRoadBetweenCrowns/tools/$Gate.gd",
        "outputs/AshenOathTheRoadBetweenCrowns/tools/$Gate.py",
        "outputs/AshenOathTheRoadBetweenCrowns/tools/$Gate.mjs"
    )
    foreach ($file in $Files) {
        $normalized = Normalize-Path $file
        if ($scriptNames -contains $normalized) {
            Add-Unique $selected $normalized
            continue
        }
        if ($Gate -in @("content_integrity", "runtime_smoke", "verify_web_001", "web_export", "verify_web_export", "verify_web_browser", "packed_startup")) {
            if ($normalized -like "outputs/AshenOathTheRoadBetweenCrowns/scripts/*" -or
                $normalized -like "outputs/AshenOathTheRoadBetweenCrowns/data/*" -or
                $normalized -like "outputs/AshenOathTheRoadBetweenCrowns/scenes/*" -or
                $normalized -like "outputs/AshenOathTheRoadBetweenCrowns/assets_external/*" -or
                $normalized -in @(
                    "outputs/AshenOathTheRoadBetweenCrowns/project.godot",
                    "outputs/AshenOathTheRoadBetweenCrowns/export_presets.cfg",
                    "vercel.json"
                )) {
                Add-Unique $selected $normalized
            }
            continue
        }
        foreach ($property in $Configuration.profiles.PSObject.Properties) {
            if ($property.Value.gates -contains $Gate) {
                foreach ($pattern in $property.Value.patterns) {
                    if (Matches-Pattern $normalized $pattern) {
                        Add-Unique $selected $normalized
                        break
                    }
                }
            }
        }
        if ($Gate.StartsWith("capture_")) {
            foreach ($property in $Configuration.profiles.PSObject.Properties) {
                foreach ($pattern in $property.Value.patterns) {
                    if (Matches-Pattern $normalized $pattern) {
                        Add-Unique $selected $normalized
                        break
                    }
                }
            }
        }
    }
    return @($selected)
}

function Read-Cache {
    if ($NoCache -or !(Test-Path -LiteralPath $CachePath)) { return @{} }
    $object = Get-Content -LiteralPath $CachePath -Raw | ConvertFrom-Json
    $result = @{}
    foreach ($property in $object.PSObject.Properties) { $result[$property.Name] = $property.Value }
    return $result
}

function Write-Cache([hashtable]$Cache) {
    New-Item -ItemType Directory -Force -Path $CacheDirectory | Out-Null
    $Cache | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $CachePath -Encoding utf8
}

function Invoke-Compact(
    [string]$Name,
    [string]$Executable,
    [string[]]$Arguments,
    [string[]]$Inputs,
    [hashtable]$Cache
) {
    $hash = Get-GateHash $Name $Inputs
    if (-not $NoCache -and $Cache.ContainsKey($Name) -and $Cache[$Name].hash -eq $hash -and $Cache[$Name].status -eq "pass") {
        Write-Host ("TICKET GATE {0}: CACHED PASS" -f $Name)
        return
    }
    New-Item -ItemType Directory -Force -Path $Logs | Out-Null
    $log = Join-Path $Logs "$Name.log"
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $Executable @Arguments *> $log
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    $timer.Stop()
    $lines = @(Get-Content -LiteralPath $log -ErrorAction SilentlyContinue)
    $parseFailure = $lines | Where-Object { $_ -match "SCRIPT ERROR|Parse Error|Compile Error|Cannot open resource pack|Failed to load" } | Select-Object -First 1
    $verifierFailure = $lines | Where-Object { $_ -match "VERIFIER:\s*FAIL|ASSERTION FAILED|Assertion failed" } | Select-Object -First 1
    if ($exitCode -ne 0 -or $parseFailure -or $verifierFailure) {
        Write-Host ("TICKET GATE {0}: FAIL" -f $Name) -ForegroundColor Red
        Get-Content -LiteralPath $log -Tail 40
        throw "$Name failed. Full log: $log"
    }
    $Cache[$Name] = @{
        hash = $hash
        status = "pass"
        finished_at = (Get-Date).ToUniversalTime().ToString("o")
        seconds = [math]::Round($timer.Elapsed.TotalSeconds, 2)
    }
    Write-Cache $Cache
    Write-Host ("TICKET GATE {0}: PASS ({1:n1}s)" -f $Name, $timer.Elapsed.TotalSeconds)
}

$files = @(Get-ChangedFiles)
$selectedProfiles = [System.Collections.Generic.List[string]]::new()
foreach ($profile in $Profiles) {
    if (-not $Configuration.profiles.PSObject.Properties.Name.Contains($profile)) {
        throw "Unknown gate profile: $profile"
    }
    Add-Unique $selectedProfiles $profile
}
if ($selectedProfiles.Count -eq 0) {
    foreach ($property in $Configuration.profiles.PSObject.Properties) {
        $profileName = $property.Name
        foreach ($pattern in $property.Value.patterns) {
            if ($files | Where-Object { Matches-Pattern $_ $pattern }) {
                Add-Unique $selectedProfiles $profileName
                break
            }
        }
    }
}
if ($ForceWeb) { Add-Unique $selectedProfiles "web" }

$gates = [System.Collections.Generic.List[string]]::new()
Add-Unique $gates "content_integrity"
Add-Unique $gates "runtime_smoke"
foreach ($profile in $selectedProfiles) {
    foreach ($gate in $Configuration.profiles.$profile.gates) { Add-Unique $gates $gate }
}

$captureGates = [System.Collections.Generic.List[string]]::new()
foreach ($view in $ChangedViews) {
    if (-not $Configuration.views.PSObject.Properties.Name.Contains($view)) {
        throw "Unknown changed view: $view"
    }
    Add-Unique $captureGates $Configuration.views.$view
}

Write-Host "TICKET GATE FILES: $($files.Count)"
Write-Host "TICKET GATE PROFILES: $(if ($selectedProfiles.Count) { $selectedProfiles -join ', ' } else { 'core' })"
Write-Host "TICKET GATES: $($gates -join ', ')"
Write-Host "TICKET CAPTURES: $(if ($captureGates.Count) { $captureGates -join ', ' } else { 'none' })"
if ($DryRun) { exit 0 }

if (!(Test-Path -LiteralPath $Godot)) { throw "Godot 4.6.3 not found: $Godot" }
if (!(Test-Path -LiteralPath $Python)) { throw "Bundled Python not found: $Python" }
$cache = Read-Cache

foreach ($gate in $gates) {
    $gateInputs = @(Get-GateInputs $gate $files)
    if ($gate -eq "content_integrity") {
        Invoke-Compact $gate $Python @(
            (Join-Path $PSScriptRoot "verify_content_integrity.py"),
            $Project,
            "--json-report",
            (Join-Path $Logs "content_integrity.json")
        ) $gateInputs $cache
    } elseif ($gate -eq "runtime_smoke") {
        Invoke-Compact $gate $Godot @("--headless", "--path", $Project, "--quit-after", "3") $gateInputs $cache
    } elseif ($gate -eq "verify_perf_001") {
        $script = Join-Path $PSScriptRoot "$gate.gd"
        Invoke-Compact $gate $Godot @(
            "--path", $Project,
            "--rendering-method", "gl_compatibility",
            "--script", $script
        ) $gateInputs $cache
    } elseif ($gate -eq "verify_web_001") {
        Invoke-Compact $gate $Python @(
            (Join-Path $PSScriptRoot "verify_web_001.py"), $Project, $RepoRoot
        ) $gateInputs $cache
    } elseif ($gate -eq "web_export") {
        Invoke-Compact "web_export" (Join-Path $Project "Export_Web_Build.bat") @() $gateInputs $cache
        Invoke-Compact "verify_web_export" $Python @(
            (Join-Path $PSScriptRoot "verify_web_export.py"), $Web,
            "--json-report", (Join-Path $Logs "web_export.json")
        ) $gateInputs $cache
        Invoke-Compact "packed_startup" $Godot @(
            "--headless", "--path", $Web,
            "--main-pack", (Join-Path $Web "index.pck"),
            "--quit-after", "5"
        ) $gateInputs $cache
    } elseif ($gate -eq "verify_web_browser") {
        Invoke-Compact $gate "node.exe" @(
            (Join-Path $PSScriptRoot "verify_web_browser.mjs"),
            "--export", $Web,
            "--report", (Join-Path $Logs "web_browser.json")
        ) $gateInputs $cache
    } else {
        $script = Join-Path $PSScriptRoot "$gate.gd"
        if (!(Test-Path -LiteralPath $script)) { throw "Verifier missing: $script" }
        Invoke-Compact $gate $Godot @("--headless", "--path", $Project, "--script", $script) $gateInputs $cache
    }
}

foreach ($capture in $captureGates) {
    $script = Join-Path $PSScriptRoot "$capture.gd"
    if (!(Test-Path -LiteralPath $script)) { throw "Capture helper missing: $script" }
    $captureInputs = @(Get-GateInputs $capture $files)
    Invoke-Compact $capture $Godot @(
        "--path", $Project, "--rendering-method", "gl_compatibility", "--script", $script
    ) $captureInputs $cache
}

Write-Host "TICKET GATE: PASS"
