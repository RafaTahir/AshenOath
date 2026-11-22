$ErrorActionPreference='Stop'
foreach($choice in @('exile','punished')) {
    & 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe' -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\run.ps1" -Group senn -Choice $choice -LegacyProfile "story_actor_aftermath_20260928\senn-$choice" *> "$PSScriptRoot\combined-$choice.wrapper.log"
    if($LASTEXITCODE -ne 0) {Get-Content "$PSScriptRoot\combined-$choice.wrapper.log" -Tail 30; throw "Combined $choice failed; downstream not run"}
    Write-Output "Combined $choice PASS single-process real-input Castle-to-ending path"
}
