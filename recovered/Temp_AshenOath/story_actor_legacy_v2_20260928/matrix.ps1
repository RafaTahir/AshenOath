$ErrorActionPreference = 'Stop'
$cases = @(
    @('senn','exile','story_main_choices_20260928\senn-exile',$false),
    @('senn','punished','story_main_choices_20260928\senn-punished',$false),
    @('halvern','released','story_main_choices_20260928\halvern-released',$false),
    @('halvern','destroyed','story_main_choices_20260928\halvern-destroyed',$false),
    @('senn','testimony','senn_fight_v3_fixture',$true),
    @('halvern','witness','halvern_choice_v1_fixture',$true)
)
foreach($case in $cases) {
    $id = "$($case[0])-$($case[1])-legacy"
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"$PSScriptRoot\run.ps1",'-Group',$case[0],'-Choice',$case[1],'-LegacyProfile',$case[2])
    if($case[3]) {$args += '-ExpectPresent'}
    & 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe' @args *> "$PSScriptRoot\$id.wrapper.log"
    if($LASTEXITCODE -ne 0) {Get-Content "$PSScriptRoot\$id.wrapper.log" -Tail 20; throw "$id failed; downstream not run"}
    Write-Output "$id PASS actual legacy Continue/manual save, actor policy and capture"
}
