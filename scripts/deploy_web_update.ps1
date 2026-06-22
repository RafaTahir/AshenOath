param(
  [string]$TicketId = "TASK",
  [string]$Summary = "update Ashen Oath web build",
  [string]$Message = "",
  [switch]$Commit,
  [switch]$NoDeploy,
  [string]$ProductionUrl = "https://ashenoath.vercel.app/"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$ProjectDir = Join-Path $RepoRoot "outputs\AshenOathTheRoadBetweenCrowns"
$ExportDir = Join-Path $RepoRoot "outputs\AshenOath_Web_Slim"
$WebDir = Join-Path $RepoRoot "web"
$Godot = "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"
$Python = "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"

function Invoke-Checked($Command, $Arguments, $WorkingDirectory) {
  Write-Host "> $Command $Arguments"
  if ([string]::IsNullOrWhiteSpace($Arguments)) {
    $process = Start-Process -FilePath $Command -WorkingDirectory $WorkingDirectory -NoNewWindow -Wait -PassThru
  } else {
    $process = Start-Process -FilePath $Command -ArgumentList $Arguments -WorkingDirectory $WorkingDirectory -NoNewWindow -Wait -PassThru
  }
  if ($process.ExitCode -ne 0) {
    throw "Command failed with exit code $($process.ExitCode): $Command $Arguments"
  }
}

if (!(Test-Path $ProjectDir)) { throw "Project folder not found: $ProjectDir" }
if (!(Test-Path $Godot)) { throw "Godot 4.6.3 console executable not found: $Godot" }
if (!(Test-Path $Python)) { throw "Bundled Python runtime not found: $Python" }

Push-Location $RepoRoot
try {
  if ($NoDeploy) {
    Write-Host "DO NOT DEPLOY mode: running verification/export/sync only. No commit or push will be performed."
  }

  Invoke-Checked $Godot "--headless --path `"$ProjectDir`" --script `"res://tools/verify_runtime.gd`"" $RepoRoot

  $AudioVerifier = Join-Path $ProjectDir "tools\verify_audio_runtime.gd"
  if (Test-Path $AudioVerifier) {
    Invoke-Checked $Godot "--headless --path `"$ProjectDir`" --script `"res://tools/verify_audio_runtime.gd`"" $RepoRoot
  }

  $VisibleVerifier = Join-Path $ProjectDir "tools\verify_visible_quality.gd"
  if (Test-Path $VisibleVerifier) {
    Invoke-Checked $Godot "--headless --path `"$ProjectDir`" --script `"res://tools/verify_visible_quality.gd`"" $RepoRoot
  }

  Invoke-Checked (Join-Path $ProjectDir "Export_Web_Build.bat") "" $ProjectDir

  Invoke-Checked $Python "`"$ProjectDir\tools\verify_web_export.py`" `"$ExportDir`"" $RepoRoot

  if (Test-Path $WebDir) {
    Get-ChildItem $WebDir -Force | Remove-Item -Recurse -Force
  } else {
    New-Item -ItemType Directory $WebDir | Out-Null
  }
  Copy-Item (Join-Path $ExportDir "*") $WebDir -Recurse -Force

  $WebBytes = (Get-ChildItem $WebDir -File -Recurse | Measure-Object Length -Sum).Sum
  $WebMb = [math]::Round($WebBytes / 1MB, 1)
  Write-Host "Web folder ready: $WebDir"
  Write-Host "Web folder size: $WebBytes bytes ($WebMb MB)"

  git status --short

  if (!$NoDeploy) {
    if ([string]::IsNullOrWhiteSpace($Message)) {
      $Message = "$TicketId`: $Summary"
    }

    git add -A
    $PendingChanges = git status --short
    if ($PendingChanges) {
      git commit -m $Message
    } else {
      Write-Host "No file changes to commit after verification/export/sync."
    }

    git push origin main
    $CommitHash = (git rev-parse --short HEAD).Trim()
    Write-Host "Production push succeeded."
    Write-Host "Commit hash: $CommitHash"
    Write-Host "Vercel auto-deploy: enabled after the GitHub repo is connected to a Vercel project that deploys origin/main from web/."
    if (![string]::IsNullOrWhiteSpace($ProductionUrl)) {
      Write-Host "Production URL: $ProductionUrl"
    } else {
      Write-Host "Production URL: not configured locally. Add it to the ticket report after Vercel is linked."
    }
  } else {
    Write-Host "Deploy skipped by explicit DO NOT DEPLOY / -NoDeploy instruction."
  }
}
finally {
  Pop-Location
}
