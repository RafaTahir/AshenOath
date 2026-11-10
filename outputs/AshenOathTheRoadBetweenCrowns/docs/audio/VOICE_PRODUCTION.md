# Natural cast production

Kokoro-82M v1.0 full-precision synthesis replaces the previous Piper performances. These are generated voices, not a human cast or cloned actor performances. This compiler does not perform listening or gameplay acceptance. Written notices and narration stay text-led. Dialogue, optional conversation topics and supporting characters are included; pending village remarks remain caption-led.

Cast recipes in `data/voice_cast.json` preserve identity using fixed model voice blends. Cadence is adjusted conservatively for intimate scenes. Character direction notes guide casting and cadence; Kokoro does not interpret free-form emotional acting prompts. Outer-silence trimming, bounded mastering gain and short click ramps preserve internal pauses and dynamics. No pitch-shifting or artificial ghost effects are used. The speech envelopes are baked from each final Ogg file.

The model and inference dependencies stay under ignored work directories. Only compressed audio, recipes and provenance ship. Kokoro's Apache-2.0 model card, license and voice table are retained here. The old VCTK attribution remains for historical provenance.

Manifest contains 570 exact-text performances. This run synthesized 0 files and reused 518 scheduled performances. 311 collected recordings remain unproduced and use subtitles until completed.

| Cast role | Clips |
|---|---:|
| player | 180 |
| sister_anwen | 81 |
| rook | 63 |
| mira | 52 |
| tor | 43 |
| elna | 17 |
| toma | 18 |
| edric | 28 |
| halvern | 6 |
| senn | 13 |
| white_hart | 9 |
| len | 3 |
| merrow | 9 |
| vale | 13 |
| guard | 4 |
| patrol_guard | 2 |
| servant | 2 |
| soldier | 2 |
| walker_well | 0 |
| walker_board | 0 |
| shrine_pilgrim | 0 |
| forge_helper | 0 |
| herb_helper | 0 |
| worried_villager | 0 |
| young_villager | 0 |
| water_carrier | 0 |
| quality_sweeper | 0 |
| quality_mourner | 2 |
| nessa | 8 |
| nera | 15 |
