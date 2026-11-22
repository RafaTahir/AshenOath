# WORLD-001 Horror Monster Source - Not Runtime-Ready

The CC0 [3D Horror Game Monster](https://opengameart.org/content/3d-horror-game-monster)
was audited outside the repository under
`D:\Temp\AshenOath\world001_horror_monster_preview_20260929`.
It is a distinct, grounded cursed-humanoid candidate, not a replacement for
the current Ghoulkin yet.

- Raw `Colors.zip`: 146,580,929 bytes, SHA-256
  `f147414a816ec91b08a41cb7fd9dedc9da9e35edde36ffdabefed5d9725da4ef`.
- Raw `Poses.zip`: 86,723,187 bytes, SHA-256
  `10b7f947b64a6e1cf4f845800f8417d91e830f6df56c24a03922065df2cf0af3`.
- Isolated Godot 4.6.3 Compatibility import of `Idle.fbx` produces a complete
  2,310-vertex skinned body, 70-bone primary skeleton, imported albedo and a
  3.167-second Idle clip. `Walk.fbx` has a 1.583-second Walk clip; `Poses.fbx`
  has a 0.250-second poses clip. The source archive also contains Run and Jump
  FBXs, but no separate attack, hit, stagger or death clip.
- The 1280x720 studio capture shows connected anatomy and a readable horror
  silhouette. Its realistic/bloody material needs a deliberate Ashen Oath
  treatment before matching the stylized human family.
- Raw FBX import emits embedded-image parse errors despite the supplied
  external textures. A clean optimized GLB conversion, validated full combat
  animations and final pack/payload checks are required before integration.

Evidence: `D:\Temp\AshenOath\world001_horror_monster_preview_20260929\audition\horror_monster_idle_audition.png`,
`import.log`, `poses_import.log`, and the isolated `inspect.gd` clip report.
The scratch project and raw archives stay on D: outside source. No runtime
mapping, game script, asset manifest or export changed. WORLD-001 remains
visually rejected in its occupied encounter cell.

## Follow-up conversion discriminant

An isolated Godot `GLTFDocument` export of the imported Idle scene produced a
1,803,360-byte GLB (`7b8f8fc074f31c65c9261b94e5486650c59d4115df6d87208f51760c042063f2`).
Godot reimported that GLB without an asset error. A native 1280x720 Compatibility
capture showed one complete textured 2,310-vertex body, one 61-bone exported
skeleton and a 3.167-second Idle clip. The black, blue and green supplied
albedo variants were inspected. Conversion resolves the raw FBX/package-size
problem, but not the missing attack/hit/death clips or the conspicuous
realistic/bloody style difference from Ashen Oath's stylized humans. This
candidate remains rejected for runtime use; no role mapping or export changed.
Scratch GLB, capture and logs remain under
`D:/Temp/AshenOath/world001_horror_monster_preview_20260929/`.
