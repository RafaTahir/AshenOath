# Native cast observations

`run_living_cast_capture.py` records staged behavior and rendered sequences in
actual levels. It does not certify real-input gameplay, visual approval or
physical-phone coverage. Those are separate release records.

Freeze both the retained Web export and the completed candidate before comparing
them. `cast-observation` supports a historical release without expansion content;
it preserves all release identity, hash, dependency and ownership checks. The
default `campaign` freeze additionally requires the complete expansion resources.

```powershell
python tools/freeze_community_candidate.py --export D:/Temp/AshenOath/retained-web --output D:/Temp/AshenOath/cast-baseline --scope cast-observation
python tools/freeze_community_candidate.py --export D:/Temp/AshenOath/final-web --output D:/Temp/AshenOath/cast-candidate --scope cast-observation
python tools/run_living_cast_capture.py --root-pack D:/Temp/AshenOath/cast-candidate/index.pck --packs D:/Temp/AshenOath/cast-candidate/packs --release-manifest D:/Temp/AshenOath/cast-candidate/release_manifest.json --class-cache D:/Temp/AshenOath/cast-candidate/global_script_class_cache.cfg --actors anwen,tor,mira,rook --zone greyfen --viewport desktop --full --output D:/Temp/AshenOath/cast-opening-desktop --prepare-only
```

Remove `--prepare-only` and use a new empty output directory to execute. Repeat
the appropriate regional actors at `--viewport touch` for 960×540 observations;
desktop is 1280×720. The touch viewport here still does not mean touch input.
`--acceptance-mode baseline-observation` records missing historical performances
as limitations rather than accepting them as new behavior.

The final root's manifest determines the exact supplemental packs and mount
order. Unlisted packs, including a stale intermediate `base.pck`, are ignored.
The class cache must be extracted from that same final root. Every mounted pack
and the observed build identity are checked again by the native entry and runner.
APPDATA and LOCALAPPDATA both point into the disposable capture output before
the engine starts; the native window uses its own non-input Windows desktop.

Candidate contact checks use the native 6 mm calibrated-palm limit. The existing
cloth/hammer limits remain separate. Performance comparisons require matching
viewports, effective renderer/GPU identity, uncapped pacing and three repeated
windows at each of three identical reference anchors. A prepared receipt or
synthetic fixture is not an executed in-level observation.
