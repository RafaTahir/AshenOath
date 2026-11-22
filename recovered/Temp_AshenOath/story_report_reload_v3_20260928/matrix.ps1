$ErrorActionPreference = 'Stop'
foreach ($choice in @('public','retained')) {
    & 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe' -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\run.ps1" -Choice $choice -Reload -DecisionEvidenceRoot 'D:\Temp\AshenOath\story_report_choices_v2_20260928'
    if ($LASTEXITCODE -ne 0) {throw "$choice reload failed; downstream not run"}
}
