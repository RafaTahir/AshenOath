# MON-001: White Hart Source Checkpoint

Status: source acquired and rendered; runtime integration and acceptance pending.

## Runtime Variant Checkpoint

`assets_external/enemies/WhiteHart_Stag.glb` is now generated and available for
integration. Its size is 2,044,528 bytes; SHA-256:
`6da8ff2a2a1c8cb467c3e2b8838b2a9128ad90ade3dc3d5ee81b3dea5e764de5`.
Two builds yielded identical bytes. `tools/build_white_hart.py` verifies the
source hash, preserves the original buffer/rig/clips, recolors the five native
materials, and packages a standard GLB without external textures.

Native Compatibility import/render of this GLB passed, exit 0. Inspected
`WhiteHart_Stag_source.png` and `WhiteHart_Stag_inspection.json` in the cache:
same complete antlered body, 3670 triangles, six surfaces, 38 bones, 13 clips.
Pale coat and dark eyes/hooves remain readable; no transparent body or external
costume geometry is added. This preview does not prove grounding in Hart Glade.

License record: `assets_external/licenses/Quaternius_Ultimate_Animals_CC0.txt`.
No role mapping or visual approval changed yet. Next is actual runtime
integration, removal of wolf-specific offset/antlers/material overwrite,
native animation mapping, and encounter/peaceful-state evidence.

## Provenance

- Creator: Quaternius.
- Pack: https://quaternius.com/packs/ultimateanimatedanimals.html
- Official page links the public Drive folder
  `1uJ3N5HfB7jKTseJUNQr3N4YaN0UuEtHk`.
- glTF folder: `1yJXdB1iSrI8Db7hG77zxZ66vKsqIt0ry`.
- Stag source file: `1URNoFeIFblJXPFOV6qwPrxZr5dLZ3YGx`.
- Pack license file: `1F2uy8T2fRpdc6gZ4mnS02_C2E63WvKtn`.
- License: CC0 1.0, verified on official pack page and downloaded License.txt.
- Source SHA-256:
  `170b964909d16d1ab4d428b1d714f25016913d32481acd9c3d62923192583be6`.
- Source bytes: 3,224,724; embedded buffer bytes: 1,697,332; no external images.
- Raw files remain outside the repository/export under
  `D:\Temp\AshenOath\asset-source\quaternius-ultimate-animals`.

## Inspection

Native Godot 4.6.3 Compatibility/Intel HD620 ANGLE import and render exited 0.
Two meshes, six surfaces, 3,670 triangles, one 38-bone skeleton. Thirteen clips:
Attack_Headbutt, Attack_Kick, Death, Eating, Gallop, Gallop_Jump, Idle, Idle_2,
Idle_Headlow, Idle_HitReact1, Idle_HitReact2, Jump_toIdle, Walk.

Source rest bounds: position (-1.273292, 0.009703, -1.801618),
size (2.536085, 5.378245, 4.837487). These are source units, not approved
gameplay scale. No role height or animation-motion acceptance is implied.

Inspected 1280x720 source preview: connected quadruped, native antlers, eyes,
muzzle, hooves and complete legs. It remains a brown source stag, not the
finished supernatural White Hart. No production role approval flag changed.

Evidence: `inspection.json`, `Stag_source.png` in the source cache;
`D:\Temp\AshenOath\hart_source.log`. Initial inspector type-inference parse
error was corrected before the successful run. No runtime game change.

## Next Action

Runtime integration now uses WhiteHart_Stag.glb for both Hart roles. Native
materials, 38-bone animation, normalized grounding and calibrated facing pass
the focused fixture. The peaceful display no longer adds a second body,
procedural antlers, chest sphere or intersecting pole. Its idle is explicitly
scheduled. Pending Duty/Ash rebuilds restore the boss checkpoint instead of
incorrectly switching to completed aftermath.

Evidence: D:\Temp\AshenOath\hart_glade_grounding.log and
Hart_glade_diagnostic.png (controlled scene, not real-input acceptance),
hart_checkpoint_after.log, hart_footstep_schedule.log, motion_after_mixer.log.
The glade environment remains visually rejected. Complete rendered attack,
outcome, real-route, Web payload and performance proof before approving the role.
Historical source-only statements above describe the acquisition checkpoint.

## Running Steps

```powershell
Set-Location D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns
& 'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --path . --rendering-method gl_compatibility --audio-driver Dummy --script tools/inspect_hart_source.gd
```

The source cache is required. No export, commit, push or deployment performed.
