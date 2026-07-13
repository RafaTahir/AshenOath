# ART-001 Audition Results

## Outcome

ART-001 is complete. The graphical gate produced identical-camera comparisons at 1280x720 and rejected all three proposed character replacements. No failed candidate has been added to the runtime mapping.

## Decisions

| Subject | Result | Reason |
|---|---|---|
| Kael / Warrior | Rejected | Faceless head, squat proportions and generic armored silhouette reduce identity. |
| Anwen / Cleric | Rejected | Masked face, oversized head and aggressive silhouette do not read as a solemn human shrine keeper. |
| Ghoulkin / OrcSkull | Final use rejected | Cohesive rig, but toy proportions, bright color and skull design do not meet cursed-human horror direction. Rig reference only. |
| Greyfen modular kit | Components selected | OBJ modules load reliably through `AssetSpawnHelper`; the sparse test assembly is not approved as a level composition. |

## Evidence

- `Development_Gallery/screenshots/ART_001_09_Greyfen_Comparison.png`
- `Development_Gallery/screenshots/ART_001_10_Kael_Comparison.png`
- `Development_Gallery/screenshots/ART_001_11_Anwen_Comparison.png`
- `Development_Gallery/screenshots/ART_001_12_Ghoulkin_Comparison.png`

## Asset Policy

- Runtime character mappings remain temporary until a candidate passes facial readability, role silhouette, modeled-body, animation, material and performance gates.
- A model is not promoted because it is rigged or technically loadable.
- Incomplete glTF files are prohibited. OBJ-backed environment sources must instantiate through `AssetSpawnHelper` until a self-contained GLB replacement is produced.
- Modular walls and roofs are components, not complete buildings.
- Primitive anatomy, faceless major actors, toy monsters, cone trees and checkerboard roads are rejected release patterns.

## Verification

- `tools/verify_art_001.gd` validates the visual direction, decisions, character scene structure, materials and actual OBJ instantiation.
- `tools/capture_art_001_audition.gd` fails when an asset or image is missing and writes the comparison set to the development gallery.
- Content integrity, ART-001 and runtime gameplay assertions passed. The graphical capture and headless runtime still emit classified Godot/ANGLE resource-cleanup warnings after their PASS markers; these are recorded and remain release-cleanup work rather than being described as a clean renderer result.
- Production runtime mappings and the Web build were not changed, so this development ticket does not export or deploy.

Commands run:

```powershell
& .\tools\run_release_gate.ps1 -Only verify_art_001 -SkipExport -SkipPerformance -SkipScreenshots
& .\tools\run_release_gate.ps1 -Only verify_runtime -SkipExport -SkipPerformance -SkipScreenshots
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --path . --script res://tools/capture_art_001_audition.gd
```

## Next Ticket

`ASSET-001` should build a curated runtime library: quarantine failed candidates, retain only verified source dependencies, document licenses and define the smallest export-safe set for the later `CHAR-001`, `MON-001`, and `WORLD-001` tickets.
