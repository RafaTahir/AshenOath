# PLAYFIX-012 - Delivery Candidate

## Scope

The user approved the three monster references, continuation in in-app Chromium,
and final push/deployment. On 2026-10-11 the user explicitly selected: deploy now,
mark the full Witness/homecoming playthrough unverified. No full-campaign or
formal user-ticket acceptance is claimed.

## Delivered Implementation

The cumulative PLAYFIX source repairs cover save/encounter restoration, Bell-Eater
gating and retirement, route joins, camera/speaker clearance, objectives and
homecoming, displayed-target input, responsive actions, character continuity,
combat feedback, approved monster assemblies, texture-pack ownership and
presentation consistency. Preferred A-set humans, Ranger Senn, actual White Hart,
equipment, quests, saves and quality presets remain.

## Exact Package

- Build: playfix-012-20261010-repair-b74a523.
- Source: baseline b74a523 plus the committed PLAYFIX changes; the export retains
  its truthful original dirty-build metadata rather than inventing a clean build.
- 15 manifest artifacts; 96457121 artifact bytes.
- Complete Web directory: 96463965 bytes including release_manifest.json,
  strictly below 104857600 bytes.
- Root PCK SHA-256:
  854636b8e5b70a79d9690663c7ec2046869c3e9ea8294d54933eb99b42a7b134.
- Compilation succeeded. Static manifest sizes/hashes and package budget passed.
- web/ is byte-aligned to the unchanged V2 candidate. Old Web bytes are retained
  under .release-gate/playfix-012-publication-20261011/previous-web.
- Actual publication commit, Vercel outcome and every live artifact hash are
  recorded in .release-gate/playfix-012-publication-20261011/publication.json.

## Observed And Unverified

See PLAYFIX_012_PLAYTHROUGH.md for scoped observations and V1 owner repairs.
V2 startup/Continue, Pause/Resume, displayed Use and settings cycling were observed.
The available earned save is earlier than the chapel observation; no unsupported
lost-progress diagnosis is asserted. Sustained in-app browser input was inconsistent.
Temporary read-only observation helpers stayed under D:/Temp/AshenOath and do not
enter the Web package or Git. No game-state mutation or route bypass was used.

The full Witness/homecoming route, other endings, remaining later encounter/route
checks, remapping round trips, physical controllers, real Chrome/Edge/Firefox,
iPhone/WebKit, audible listening approval and numerical performance certification
remain explicitly unverified. Test-profile settings did not change release defaults.

## Manual Checks

1. Start New Game, walk to Anwen, use dialogue and cross the Wychwood bridge.
2. Save during the unfinished encounter, reload, Continue and check supplies,
   completed clues, remaining enemies and settings.
3. Defeat Bell-Eater before the shrine, return after leaving and confirm retirement.
4. Check bow aim/fire, Oathfire, shops, pause, short-screen actions and focus recovery.
5. Finish Witness, return to Anwen, complete the workbench and road reflection.

## Running

Production: https://ashenoath.vercel.app/?v=playfix-012-20261010-repair-b74a523.
Canonical source: D:/Projects/AshenOath, codex/masterpiece-rebuild.
Godot project: D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns.
This record is authored before publication; the receipt and live checks establish
actual deployment, not the presence of this URL or result file.
