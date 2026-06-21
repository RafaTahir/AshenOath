param(
  [switch]$Commit,
  [string]$Message = "Update Ashen Oath web build"
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
  Invoke-Checked $Godot "--headless --path `"$ProjectDir`" --script `"res://tools/verify_runtime.gd`"" $RepoRoot

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

  if ($Commit) {
    git add .gitignore vercel.json DEPLOYMENT_WORKFLOW.md CODEX_WORKFLOW.md DEPLOY_001_GITHUB_VERCEL_WORKFLOW.md Deploy_Web_Update.bat scripts/deploy_web_update.ps1 web
    git commit -m $Message
    git push
  } else {
    Write-Host "Commit skipped. Re-run with -Commit -Message `"Your message`" to commit and push."
  }
}
finally {
  Pop-Location
}
