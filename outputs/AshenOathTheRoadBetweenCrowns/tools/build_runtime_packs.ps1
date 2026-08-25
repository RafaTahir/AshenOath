param(
    [string]$OutputDirectory = "",
    [string]$GodotPath = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$Project = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $Project ".release-gate\runtime-packs"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory = Join-Path $Project $OutputDirectory
}
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $candidates = @(
        $env:GODOT_BIN,
        (Join-Path $Project "tools\godot\Godot_v4.6.3-stable_win64_console.exe"),
        "C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64.exe"
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
    $GodotPath = $candidates | Select-Object -First 1
}
if ([string]::IsNullOrWhiteSpace($GodotPath) -or !(Test-Path -LiteralPath $GodotPath)) {
    throw "Godot 4.6.3 executable not found. Pass -GodotPath or set GODOT_BIN."
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$packs = @(
    @{ id = "base"; preset = "Runtime Pack Base"; file = "base.pck" },
    @{ id = "opening"; preset = "Runtime Pack Opening"; file = "opening.pck" },
    @{ id = "campaign"; preset = "Runtime Pack Campaign"; file = "campaign.pck" },
    @{ id = "characters"; preset = "Runtime Pack Characters"; file = "characters.pck" },
    @{ id = "monsters"; preset = "Runtime Pack Monsters"; file = "monsters.pck" },
    @{ id = "audio"; preset = "Runtime Pack Audio"; file = "audio.pck" }
)

$records = [System.Collections.Generic.List[object]]::new()
$errors = [System.Collections.Generic.List[string]]::new()
foreach ($pack in $packs) {
    $target = Join-Path $OutputDirectory $pack.file
    $log = Join-Path $OutputDirectory ($pack.id + ".log")
    $exitCode = 0
    if ($Force -or !(Test-Path -LiteralPath $target)) {
        Write-Host ("PACK-003 export: {0}" -f $pack.id)
        $errorLog = Join-Path $OutputDirectory ($pack.id + ".error.log")
        $argumentLine = "--headless --path `"$Project`" --export-pack `"$($pack.preset)`" `"$target`""
        $process = Start-Process -FilePath $GodotPath -ArgumentList $argumentLine -Wait -PassThru -RedirectStandardOutput $log -RedirectStandardError $errorLog
        $exitCode = $process.ExitCode
    } else {
        Write-Host ("PACK-003 reuse: {0}" -f $pack.id)
    }
    if (!(Test-Path -LiteralPath $target) -or $exitCode -ne 0) {
        $errors.Add(("{0}: export failed (exit {1})" -f $pack.id, $exitCode))
        continue
    }
    $fileInfo = Get-Item -LiteralPath $target
    $stream = [System.IO.File]::OpenRead($target)
    try {
        $magicBytes = New-Object byte[] 4
        [void]$stream.Read($magicBytes, 0, 4)
    } finally {
        $stream.Dispose()
    }
    $magic = [System.Text.Encoding]::ASCII.GetString($magicBytes)
    $hash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($magic -ne "GDPC") {
        $errors.Add(("{0}: output is not a Godot PCK (magic {1})" -f $pack.id, $magic))
        continue
    }
    $records.Add([ordered]@{
        id = $pack.id
        version = "dev"
        preset = $pack.preset
        artifact = $pack.file
        bytes = [int64]$fileInfo.Length
        sha256 = $hash
        status = "candidate_external"
        log = (Split-Path -Leaf $log)
    })
    Write-Host ("  {0:n2} MB  {1}" -f ($fileInfo.Length / 1MB), $hash)
}

$totalBytes = [int64]0
foreach ($record in $records) {
    $totalBytes += [int64]$record["bytes"]
}
$manifest = [ordered]@{
    schema_version = 1
    ticket = "PACK-003"
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    project = "Ashen Oath"
    artifact_directory = $OutputDirectory
    artifacts_are_external = $true
    max_deployment_bytes = 100MB
    total_bytes = [int64]$totalBytes
    packs = @($records)
    errors = @($errors)
}
$manifestPath = Join-Path $OutputDirectory "runtime_pack_candidates.json"
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding utf8

if ($errors.Count -gt 0 -or $records.Count -ne $packs.Count) {
    Write-Host "PACK-003: FAIL" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host ("- " + $_) -ForegroundColor Red }
    exit 1
}
Write-Host ("PACK-003: PASS ({0} packs, {1:n2} MB total)" -f $records.Count, ($totalBytes / 1MB))
