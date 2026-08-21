# MON-002 Result

## Changes
- Replaced the Wychwood Ghoulkin, Stalker, Raider, and Brute runtime source mapping with the complete animated `Skeleton.fbx` source from Animated Monsters by Quaternius.
- Kept the existing enemy IDs, health, attack behavior, staged five-member encounter, role scale, material profiles, and save/quest progression unchanged.
- Added an explicit `ghoulkin_skeleton` role contract with imported idle, running, attack, spawn, and death clips.
- Removed the detached Wychwood variant silhouette boxes. Variant identity now comes from the authored skeleton, role tint, scale, locomotion profile, and attack spacing rather than root-mounted proxy anatomy.
- Extended the native-face driver to recognize the integrated skeleton material as a valid skull/face surface. No eyes, face cards, limbs, or costume overlays are generated.
- Added a graphical monster audition capture so future monster replacements can be compared at identical framing before runtime mapping.

## Evidence
- `Development_Gallery/screenshots/MON_002_MONSTER_AUDITION.png` — source audition: Skeleton, Dragon, Wolf, and the former derived family.
- `Development_Gallery/screenshots/Capture_74_ai_001_engagement_roles_2026-08-21_122554.png` — five-member Wychwood formation with the new articulated bodies.
- `Development_Gallery/screenshots/Capture_75_ai_001_attack_contact_2026-08-21_122554.png` — attack-contact staging with the new source.

The new Wychwood bodies are visibly articulated skeletons with skulls, rib cages, hands, feet, and actual imported animation. The former generated bodies remain in the repository only as fallback candidates for later roles and are no longer used by the Wychwood pack.

## Verification
- `verify_mon_002.gd`: PASS; all boss/monster IDs, source mapping, skeleton resource, and runtime presentation checks pass.
- `verify_face_003.gd`: PASS; Wychwood source has a native integrated skull surface and no synthetic face geometry.
- `verify_char_001.gd`: PASS; all sampled actors, including the imported Skeleton family, are grounded after the final visual transform.
- `verify_runtime.gd`: PASS; New Game, Greyfen, Wychwood, five-enemy encounter, return, and report route still complete.
- Graphical `capture_slice_screenshots.gd --ai-only`: PASS; 1280x720 nonblank engagement and attack frames captured.
- Asset audition: PASS; six candidate sources loaded with imported animation lists. Skeleton clips are `Skeleton_Idle`, `Skeleton_Running`, `Skeleton_Attack`, `Skeleton_Spawn`, and `Skeleton_Death`.

## Known Limits
- The Ultimate Monsters Drive download is currently quota-blocked, so the final bespoke Ghoulkin/Bog Wretch/Gravebound family meshes remain pending visual approval.
- Bell-Eater, Rootbound Colossus, Ashwing, Halvern, and White Hart still use interim mapped sources and have not been promoted to final visual approval.
- Shutdown-only dummy/renderer cleanup diagnostics remain in headless/graphical capture logs; no active gameplay renderer failure was observed in this ticket.

## Running Steps
```powershell
cd C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns
& C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe --path . --script tools\capture_slice_screenshots.gd --rendering-method gl_compatibility --rendering-driver opengl3 -- --ai-only
```

Production Web output was not modified and Vercel was not deployed for this development checkpoint.
