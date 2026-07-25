param(
  [string]$TicketId = "TASK",
  [string]$Summary = "update Ashen Oath web build",
  [string]$Message = "",
  [string[]]$Profiles = @(),
  [string[]]$ChangedViews = @(),
  [switch]$ForceWeb,
  [switch]$Production,
  [Alias("ApprovedMilestone")]
  [switch]$RoadmapMilestone,
  [switch]$SkipScreenshots,
  [string]$ProductionUrl = "https://ashenoath.vercel.app/"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$ProjectDir = Join-Path $RepoRoot "outputs\AshenOathTheRoadBetweenCrowns"
$ExportDir = Join-Path $RepoRoot "outputs\AshenOath_Web"
$WebDir = Join-Path $RepoRoot "web"
$Gate = Join-Path $ProjectDir "tools\run_release_gate.ps1"
$TicketGate = Join-Path $ProjectDir "tools\run_ticket_gate.ps1"

if ($Production -and -not $RoadmapMilestone) {
  throw "Production deployment requires both -Production and -RoadmapMilestone."
}
if (!(Test-Path -LiteralPath $Gate)) { throw "Release gate not found: $Gate" }
if (!(Test-Path -LiteralPath $TicketGate)) { throw "Ticket gate not found: $TicketGate" }

Push-Location $RepoRoot
try {
  if (-not $Production) {
    $branch = (git branch --show-current).Trim()
    if ($branch -eq "main") {
      throw "Ordinary tickets must run on a codex/roadmap-* development branch, not main."
    }
    $ticketArguments = @{
      Profiles = $Profiles
      ChangedViews = $ChangedViews
    }
    if ($ForceWeb) { $ticketArguments["ForceWeb"] = $true }
    & $TicketGate @ticketArguments
    if ($LASTEXITCODE -ne 0) { throw "Targeted ticket gate failed." }
    if ([string]::IsNullOrWhiteSpace($Message)) {
      $Message = "$TicketId`: $Summary"
    }
    git add -A
    if (git status --short) {
      git commit -m $Message
      if ($LASTEXITCODE -ne 0) { throw "Checkpoint commit failed." }
    }
    git push -u origin $branch
    if ($LASTEXITCODE -ne 0) { throw "Checkpoint push failed." }
    Write-Host "Ticket checkpoint complete on $branch. Production and web/ were not changed."
    exit 0
  }

  $branch = (git branch --show-current).Trim()
  if ($branch -ne "main") {
    throw "Roadmap milestone production must run from main after the approved development branch is merged."
  }
  $gateArguments = @("-ExecutionPolicy", "Bypass", "-File", $Gate)
  if ($SkipScreenshots) { $gateArguments += "-SkipScreenshots" }
  & powershell @gateArguments
  if ($LASTEXITCODE -ne 0) { throw "Authoritative release gate failed." }

  if (Test-Path -LiteralPath $WebDir) {
    Get-ChildItem -LiteralPath $WebDir -Force | Remove-Item -Recurse -Force
  } else {
    New-Item -ItemType Directory -Path $WebDir | Out-Null
  }
  Copy-Item (Join-Path $ExportDir "*") $WebDir -Recurse -Force
  $webBytes = (Get-ChildItem $WebDir -File -Recurse | Measure-Object Length -Sum).Sum
  $webMb = [math]::Round($webBytes / 1MB, 1)
  Write-Host "Verified milestone Web folder synchronized: $webMb MB"

  if ([string]::IsNullOrWhiteSpace($Message)) {
    $Message = "$TicketId`: $Summary"
  }
  git add -A
  if (git status --short) {
    git commit -m $Message
    if ($LASTEXITCODE -ne 0) { throw "Commit failed." }
  }
  git push origin main
  if ($LASTEXITCODE -ne 0) { throw "Push to origin/main failed." }

  $commitHash = (git rev-parse HEAD).Trim()
  $localPckHash = (Get-FileHash -Algorithm SHA256 (Join-Path $WebDir "index.pck")).Hash
  $livePck = Join-Path $env:TEMP "ashenoath-live-index.pck"
  $deadline = (Get-Date).AddMinutes(8)
  $liveHash = ""
  while ((Get-Date) -lt $deadline) {
    try {
      Invoke-WebRequest -Uri "$ProductionUrl/index.pck?v=$commitHash" -OutFile $livePck -UseBasicParsing
      $liveHash = (Get-FileHash -Algorithm SHA256 $livePck).Hash
      if ($liveHash -eq $localPckHash) { break }
    } catch {}
    Start-Sleep -Seconds 15
  }
  if ($liveHash -ne $localPckHash) {
    throw "Vercel did not publish the verified index.pck before timeout."
  }
  Write-Host "Roadmap milestone push and Vercel PCK verification succeeded."
  Write-Host "Commit hash: $commitHash"
  Write-Host "Production URL: $ProductionUrl?v=$TicketId"
}
finally {
  Pop-Location
}
