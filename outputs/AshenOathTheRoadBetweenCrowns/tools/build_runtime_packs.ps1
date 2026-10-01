param(
    [string]$OutputDirectory = "",
    [string]$GodotPath = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$Project = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent (Split-Path -Parent $Project)

$SourceCommit = ""
try { $SourceCommit = (git -C $RepoRoot rev-parse HEAD).Trim() } catch {}
$BuildId = if ($env:ASHENOATH_RELEASE_ID) { $env:ASHENOATH_RELEASE_ID } elseif ($SourceCommit) { "pack-003-$($SourceCommit.Substring(0,12))" } else { "pack-003-local" }

function Get-Sha256Hex([string]$Path) {
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $digest = $algorithm.ComputeHash($stream)
    } finally {
        $stream.Dispose()
        $algorithm.Dispose()
    }
    return ([System.BitConverter]::ToString($digest)).Replace("-", "").ToLowerInvariant()
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $Project ".release-gate\runtime-packs"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory = Join-Path $Project $OutputDirectory
}
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$CandidateManifestPath = Join-Path $OutputDirectory "runtime_pack_candidates.json"

# HEAD alone does not identify uncommitted runtime edits.
$sourceStatus = @(git -C $RepoRoot status --porcelain --untracked-files=all -- $Project)
if ($LASTEXITCODE -ne 0) { throw "Cannot establish pack source working-tree state." }
$sourceDirty = $sourceStatus.Count -gt 0
$existingManifest = $null
if (-not $Force -and (Test-Path -LiteralPath $CandidateManifestPath)) {
    try {
        $existingManifest = Get-Content -LiteralPath $CandidateManifestPath -Raw | ConvertFrom-Json
    } catch {
        throw "PACK-003 candidate manifest is invalid: $CandidateManifestPath"
    }
    $existingCommit = [string]$existingManifest.generated_from_commit
    if (-not $SourceCommit -or $existingCommit -ne $SourceCommit -or $sourceDirty -or $existingManifest.source_dirty) {
        throw "PACK-003 unsafe reuse: candidate=$existingCommit, current=$SourceCommit, current_dirty=$sourceDirty, candidate_dirty=$($existingManifest.source_dirty). Re-run with -Force."
    }
}

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
    @{ id = "audio"; preset = "Runtime Pack Audio"; file = "audio.pck" },
    @{ id = "quality_materials"; preset = "Runtime Pack Quality Materials"; file = "quality_materials.pck" }
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
        $process = Start-Process -FilePath $GodotPath -ArgumentList $argumentLine -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $log -RedirectStandardError $errorLog
        $exitCode = $process.ExitCode
    } else {
        $previous = @($existingManifest.packs | Where-Object { $_.id -eq $pack.id })
        if ($previous.Count -ne 1 -or
            [int64]$previous[0].bytes -ne (Get-Item -LiteralPath $target).Length -or
            [string]$previous[0].sha256 -ne (Get-Sha256Hex $target)) {
            throw "PACK-003 $($pack.id): reuse has no matching verified artifact identity. Re-run with -Force."
        }
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
    $hash = Get-Sha256Hex $target
    if ($magic -ne "GDPC") {
        $errors.Add(("{0}: output is not a Godot PCK (magic {1})" -f $pack.id, $magic))
        continue
    }
    $records.Add([ordered]@{
        id = $pack.id
        version = $BuildId
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
    schema_version = 2
    ticket = "PACK-003"
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    build_id = $BuildId
    generated_from_commit = $SourceCommit
    source_dirty = $sourceDirty
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
