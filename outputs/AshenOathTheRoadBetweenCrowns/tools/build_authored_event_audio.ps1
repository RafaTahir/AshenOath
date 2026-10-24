param(
    [string]$RawRoot = 'D:\Temp\AshenOath\audio001',
    [string]$Ffmpeg = 'D:\Temp\AshenOath\audio001\python\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe',
    [string[]]$Only = @()
)
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$output = Join-Path $project 'assets_external\audio\authored'
$archives = @{
    'monster_sfx_pack.zip' = 'f39c5ae356b1fc01284057ee48e35ec1a52fcc84bfa959b77d0a696adc8459e4'
    'tinysized.zip' = '7f00e2b1dae15e68db0e1d6096767f03755e9e7c247128afc3e935e63774d7db'
}
foreach ($archive in $archives.Keys) {
    if ((Get-FileHash -LiteralPath (Join-Path $RawRoot $archive) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $archives[$archive]) {
        throw "Unverified source archive: $archive"
    }
}
$monster = 'monster_sfx\monster_sfx_pack'
$sfx = 'sfx-cc0'
$recipes = @(
    @{file='flesh_cut'; source="$sfx\quiver-leather-squeeze-01.wav"; layer="$sfx\water-drop-03.wav"; seconds=0.26; gain=-6; events=@('flesh_contact')},
    @{file='arrow_pierce'; source="$sfx\cover-paper-tear-02.wav"; layer="$sfx\quiver-leather-squeeze-02.wav"; seconds=0.20; gain=-7; events=@('arrow_contact')},
    @{file='ghoul_breath'; source="$monster\monster-1.wav"; seconds=0.65; gain=-6; events=@('ghoulkin_idle','enemy_windup')},
    @{file='ghoul_attack'; source="$monster\monster-2.wav"; seconds=0.38; gain=-6; events=@('ghoulkin_lunge')},
    @{file='ghoul_hit'; source="$monster\monster-3.wav"; seconds=0.35; gain=-6; events=@('stagger')},
    @{file='ghoul_death'; source="$monster\monster-6.wav"; seconds=1.01; gain=-6; events=@('death')},
    @{file='oathfire_charge'; source="$sfx\compressed-air-spray-01.wav"; seconds=0.75; gain=-8; events=@('oathfire_charge')},
    @{file='oathfire_release'; source="$sfx\paralyzer-discharge-01.wav"; seconds=0.48; gain=-8; events=@('oathfire_release')},
    @{file='candle_light'; source="$sfx\match-light-01.wav"; seconds=0.7; gain=-6; events=@('shrine_candle')},
    @{file='potion_uncork'; source="$sfx\bottle-glass-uncork-01.wav"; seconds=0.75; gain=-6; events=@('potion')},
    @{file='forest_twigs'; source="$sfx\wood-twigs-break-01.wav"; seconds=0.85; gain=-6; events=@('wychwood_drop')}
)
$entries = @()
foreach ($recipe in $recipes) {
    if ($Only.Count -and $recipe.file -notin $Only) { continue }
    $source = Join-Path $RawRoot $recipe.source
    $destination = Join-Path $output ($recipe.file + '.ogg')
    $duration = ([double]$recipe.seconds).ToString('0.000', [Globalization.CultureInfo]::InvariantCulture)
    $fade = ([double]$recipe.seconds - 0.025).ToString('0.000', [Globalization.CultureInfo]::InvariantCulture)
    if ($recipe.layer) {
        $layer = Join-Path $RawRoot $recipe.layer
        $filter = "[0:a]atrim=duration=$duration,asetpts=PTS-STARTPTS,highpass=f=100,lowpass=f=5000[a];[1:a]atrim=duration=$duration,asetpts=PTS-STARTPTS,volume=0.45[b];[a][b]amix=inputs=2:normalize=0,apad=whole_dur=$duration,atrim=duration=$duration,afade=t=in:d=0.003,afade=t=out:st=$fade`:d=0.025,volume=$($recipe.gain)dB[out]"
        & $Ffmpeg -hide_banner -loglevel error -y -i $source -i $layer -filter_complex $filter -map '[out]' -map_metadata -1 -fflags +bitexact -flags:a +bitexact -ac 1 -ar 48000 -c:a libvorbis -q:a 3 $destination
    } else {
        & $Ffmpeg -hide_banner -loglevel error -y -i $source -vn -map_metadata -1 -fflags +bitexact -flags:a +bitexact -ac 1 -ar 48000 -af "apad=whole_dur=$duration,atrim=duration=$duration,afade=t=in:d=0.005,afade=t=out:st=$fade`:d=0.025,volume=$($recipe.gain)dB" -c:a libvorbis -q:a 3 $destination
    }
    if ($LASTEXITCODE -ne 0) { throw "Event conversion failed: $($recipe.file)" }
    $isMonster = $recipe.source.StartsWith($monster)
    $entry = [ordered]@{
        id=$recipe.file; events=$recipe.events; path=('res://assets_external/audio/authored/' + $recipe.file + '.ogg')
        bytes=(Get-Item -LiteralPath $destination).Length
        sha256=(Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
        source=$recipe.source; source_sha256=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
        author=$(if ($isMonster) {'Ogrebane'} else {'Vehicle (Jan Schupke)'})
        source_url=$(if ($isMonster) {'https://opengameart.org/content/monster-sound-effects-pack'} else {'https://opengameart.org/content/fantasy-sound-effects-tinysized-sfx'})
        license='CC0-1.0'; seconds=$recipe.seconds; gain_db=$recipe.gain; sample_rate=48000; channels=1
        pack_owner='audio'; status='native_recording_candidate_not_listening_approved'
    }
    if ($recipe.layer) {
        $entry.layers = @([ordered]@{source=$recipe.layer; sha256=(Get-FileHash -LiteralPath (Join-Path $RawRoot $recipe.layer) -Algorithm SHA256).Hash.ToLowerInvariant(); license='CC0-1.0'})
        $entry.production_mode = 'original_layered_foley_from_retained_licensed_recordings'
    }
    $entries += $entry
}
if ($Only.Count -and (Test-Path -LiteralPath (Join-Path $output 'event_manifest.json'))) {
    $previous = Get-Content -LiteralPath (Join-Path $output 'event_manifest.json') -Raw | ConvertFrom-Json
    $entries = @($previous.entries | Where-Object { $_.id -notin $Only }) + $entries
}
$manifest = [ordered]@{schema_version=1; build_tool='tools/build_authored_event_audio.ps1'; source_archives=$archives; entries=$entries}
[IO.File]::WriteAllText((Join-Path $output 'event_manifest.json'), ($manifest | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
$totalBytes = ($entries | ForEach-Object { [long]$_.bytes } | Measure-Object -Sum).Sum
Write-Output "Authored events: $($entries.Count) OGG clips, $totalBytes bytes. Not listening approval."
