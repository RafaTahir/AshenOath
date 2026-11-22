# MON-002 Result

## Continuation Checkpoint - 2026-08-21

This continuation promotes the existing connected Ghoul family into the live
Wychwood encounter mapping. It supersedes the earlier generic Skeleton.fbx
mapping for route-visible Ghoulkin, Stalker, Raider, and Brute actors.

## Changes
- Mapped Wychwood `ghoulkin` and `wychwood_raider` to `GhoulGaunt_Real.glb`, `wychwood_stalker` to `GhoulStalker_Real.glb`, and `wychwood_brute` to `GhoulBrute_Real.glb`.
- Kept the three bodies as one connected skinned mesh family with modeled skull/face, hands, feet, six runtime material surfaces, and the shared `Idle`, `Walk`, `Run`, `Attack`, `HeavyAttack`, `RecieveHit`, `Dodge`, and `Death` clips.
- Quarantined `Skeleton.fbx` as a legacy audit source instead of using it for Wychwood route actors.
- Kept the existing enemy IDs, health, attack behavior, staged five-member encounter, role scale, material profiles, and save/quest progression unchanged.
- Preserved the detached-geometry removal. Variant identity now comes from the connected family mesh, role tint, scale, locomotion profile, and attack spacing rather than root-mounted proxy anatomy.
- Updated enemy animation mapping to use the imported family’s actual clip names, including the source’s `RecieveHit` spelling.

## Evidence
- `Development_Gallery/screenshots/MON_002_MONSTER_AUDITION.png` — source audition: Skeleton, Dragon, Wolf, and the former derived family.
- `Development_Gallery/screenshots/Capture_74_ai_001_engagement_roles_2026-08-21_142021.png` — five-member Wychwood formation with the connected family bodies.
- `Development_Gallery/screenshots/Capture_75_ai_001_attack_contact_2026-08-21_142021.png` — attack-contact staging with the connected family source.

The new Wychwood bodies are visibly connected, articulated cursed-human forms with distinct gaunt, hooded, and broad silhouettes. The former generated bodies remain in the repository only as fallback candidates for later roles and are no longer used by the Wychwood pack.

## Verification
- `verify_mon_002.gd`: PASS; all boss/monster IDs, connected Wychwood source mappings, four runtime instances, skeletons, animation drivers, visual-role metadata, and placeholder rejection checks pass.
- `verify_face_003.gd`: PASS; Wychwood source has a native integrated skull surface and no synthetic face geometry.
- `verify_char_001.gd`: PASS; all sampled actors, including the connected Ghoul family, are grounded after the final visual transform.
- `verify_runtime.gd`: PASS; New Game, Greyfen, Wychwood, five-enemy encounter, return, and report route still complete.
- Graphical `capture_slice_screenshots.gd --ai-only`: PASS; fresh 1280x720 nonblank formation and attack-contact frames captured at 2026-08-21 14:20.

## Known Limits
- The Ultimate Monsters Drive download is currently quota-blocked, so the matching Quaternius Ultimate Monsters replacements remain pending; the current connected Ghoul family is the approved interim route source for Wychwood.
- Bell-Eater, Rootbound Colossus, Ashwing, Halvern, and White Hart still use interim mapped sources and have not been promoted to final visual approval.
- Shutdown-only dummy/renderer cleanup diagnostics remain in headless/graphical capture logs; no active gameplay renderer failure was observed in this ticket.

## Running Steps
```powershell
cd C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns
& C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe --path . --script tools\capture_slice_screenshots.gd --rendering-method gl_compatibility --rendering-driver opengl3 -- --ai-only
```

Production Web output was not modified and Vercel was not deployed for this development checkpoint. The development checkpoint is ready to push on `codex/soul-rebuild`.
