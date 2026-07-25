param([switch]$Force)

$ErrorActionPreference = "Stop"
$Project = Split-Path -Parent $PSScriptRoot
$Output = Join-Path $Project "assets_external\audio\voices\scratch"
New-Item -ItemType Directory -Force -Path $Output | Out-Null
Add-Type -AssemblyName System.Speech

$Lines = @(
    @{ Id="voice_sister_anwen_greeting_01"; Voice="Microsoft Hazel Desktop"; Rate=-2; Text="Keep your blade low in Greyfen, hunter. Fear already has hands around every throat here." },
    @{ Id="voice_sister_anwen_road_warning_01"; Voice="Microsoft Hazel Desktop"; Rate=-2; Text="The old road has taken three men and returned none whole. That is not hunger. Hunger is honest." },
    @{ Id="voice_sister_anwen_wychwood_warning_01"; Voice="Microsoft Hazel Desktop"; Rate=-2; Text="Look for the cart, the clawed mud, and the black feathers. If you find them together, come back." },
    @{ Id="voice_sister_anwen_report_01"; Voice="Microsoft Hazel Desktop"; Rate=-2; Text="Then it was called here. Greyfen owes you coin, and more truth than I can bear tonight." },
    @{ Id="voice_player_accept_contract_01"; Voice="Microsoft George"; Rate=-1; Text="I'll take the road." },
    @{ Id="voice_player_clue_observation_01"; Voice="Microsoft George"; Rate=-1; Text="These tracks were dragged through blood." },
    @{ Id="voice_player_ghoulkin_death_01"; Voice="Microsoft George"; Rate=-1; Text="That thing was not hunting alone." },
    @{ Id="voice_player_return_report_01"; Voice="Microsoft George"; Rate=-1; Text="Back to Greyfen. Anwen needs to hear this." },
    @{ Id="voice_senn_confession"; Voice="Microsoft George"; Rate=-2; Text="I barred the road. Halvern refused. They hanged him before dawn." },
    @{ Id="voice_halvern_witness"; Voice="Microsoft George"; Rate=-3; Text="Do not call me loyal. I obeyed until obedience became murder." },
    @{ Id="voice_edric_ledger"; Voice="Microsoft George"; Rate=-2; Text="I inherited the proof, then chose every morning not to open it." },
    @{ Id="voice_anwen_confession"; Voice="Microsoft Hazel Desktop"; Rate=-3; Text="The shrine taught Greyfen how to forget. I kept that teaching alive." },
    @{ Id="voice_kael_names"; Voice="Microsoft George"; Rate=-2; Text="Bram. Sella. Oren. These names are not weapons." },
    @{ Id="voice_hart_choice"; Voice="Microsoft Hazel Desktop"; Rate=-3; Text="Ask which debt you are willing to carry awake." }
)

foreach ($Line in $Lines) {
    $Path = Join-Path $Output "$($Line.Id).wav"
    if ((Test-Path -LiteralPath $Path) -and -not $Force) { continue }
    $Speech = New-Object System.Speech.Synthesis.SpeechSynthesizer
    try {
        $Speech.SelectVoice($Line.Voice)
        $Speech.Rate = $Line.Rate
        $Speech.Volume = 82
        $Speech.SetOutputToWaveFile($Path)
        $Speech.Speak($Line.Text)
    } finally {
        $Speech.Dispose()
    }
}

Write-Host "VOICE-001 generated $($Lines.Count) reviewed scratch lines in $Output"
