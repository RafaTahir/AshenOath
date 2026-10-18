# XP Progression: Implementation and Delivery

## Scope

Implements XP-001 through XP-005 as one cumulative change. Implementation is not
runtime or user acceptance. Testing remains user-owned; no game, browser, test
suite or benchmark is authorized by this task. A production package, development
push and deployment are requested separately by the user.

## Implemented

- One permanent level, 1 through 20, across all fifteen released sectors.
- Six regional journal records: Greyfen, Wychwood, Deep Woods/Mill, Long Road,
  Castle Vargan and Hartlands. Each first playable sector arrival grants 100 XP.
- XP from all ten main and eleven side quests, recorded evidence, first creature/
  character accounts, authored enemy defeats and five boss resolutions.
- Seven finite return milestones, including evidence reports, changed Wychwood,
  Castle testimony and the return-home workbench. Unchanged revisits grant no XP.
- An increasing XP curve: next-level cost starts at 200 and rises by 50 each
  level; reaching level 20 requires 12,350 total XP. These are initial tuning
  values, not playtested balance claims.
- Twelve Oath Marks, earned at even levels and levels 5 and 15. Each skill costs
  one Mark. Retains all nine original practices and adds three Hunter practices.
- Steady Hands: 20% lower bow-aim look sensitivity; existing sensitivity,
  inversion, free yaw, first-person and aim-assist preferences remain in effect.
- Quick Nock: shot recovery changes from 0.24 to 0.18 seconds.
- Fletcher's Care: the finishing Standard/Bodkin arrow returns to the quiver
  after a bow kill. No Ashfire refund or training ammunition farming.
- Compact XP ribbon/level display and a journal Growth section with regional
  records, branch-grouped skill purchases, and free redistribution beside
  Greyfen's shrine bench outside combat.

## Save and Reward Ownership

Save schema advances additively from 11 to 12. Progression stores XP, issued and
unspent Marks, learned skills, claimed reward IDs and visited sectors in the same
existing atomic journey save. There are no replacement save files or currencies.

Legacy learned skills and usable unspent Marks form an entitlement floor. Known
completed quests, recorded evidence, boss outcomes and actually recorded sector
discoveries receive one-time historical credit quietly. Previously issued Marks
are not added again when the corresponding new level milestones are reached.
Unlocated historical accounts are not assigned to whichever sector is loaded.
No kills, quest choices or unrecorded visits are invented during migration.

Opening wave slots have stable reward identities across unfinished-wave restores.
Other enemy identities use their authored sector, type and spawn position. Bell-
Eater summons grant no separate XP. Boss combat and peaceful outcomes share one
reward ID. Restoring or prewarming a scene cannot repeatedly award its XP.

Progression is event-driven and uses the existing quest/story signals, playable
arrival boundary and save path. Level changes do not heal Kael or resurrect him;
refunding/relearning health practice cannot generate healing. No enemy scaling,
travel gates, content removal, new media downloads or quality downgrade is added.

## Files

- New `data/progression.json` holds XP amounts, regions, milestones and returns.
- `data/upgrades.json` extends the retained practices with Hunter.
- `scripts/progression_manager.gd` owns levels, rewards, Mark accounting and saves.
- `scripts/game.gd`, `runtime_service_registry.gd` and
  `zone_runtime_coordinator.gd` connect existing gameplay boundaries.
- `scripts/player_controller.gd` and `camera_controller.gd` apply Hunter practices.
- `scripts/hud.gd` presents XP, Growth and redistribution.
- `scripts/save_manager.gd` recognizes the additive schema.
- Existing startup/camera work remains retained, not reverted.

## Unverified: Requires User Testing

Runtime startup, XP pacing, browser save durability, legacy-save migration, all
reward/respec paths, Hunter feel, mobile layout and performance. No runtime
acceptance is claimed. Export/build results and publication identity are recorded
below after packaging.

## Manual Checklist

1. Start a new journey; see level 1 and 100 XP on first playable Greyfen arrival.
2. Enter Wychwood, inspect evidence and resolve an encounter; see XP and Marks.
3. Revisit the same crossing and reload/Continue; confirm no duplicate payout.
4. Complete a report/return milestone; check the regional Growth record.
5. Learn Hunter practices; compare aiming/recovery and finish a foe with an arrow.
6. Beside Greyfen's shrine bench, refund/relearn practices; health must not refill.
7. Continue an old save; confirm learned practices, supplies and choices remain.
8. Check Growth controls and the XP display on your phone/short screen.

## Delivery

Production compilation and packaging completed using `build_story_release.ps1`,
without tests, game launches or browser QA. The generated package is
`xp-progression-20261018-10371b9`, under
`D:\Projects\AshenOath\.release-gate\xp-progression-20261018\export` and synchronized
into the tracked `web/` directory. Fifteen manifested artifacts total 94,232,208
bytes; the complete Web directory is 94,239,048 bytes, strictly below 104,857,600.
The transported root PCK SHA-256 is
`80a34fa18a465953d5eae083da016b4210db11764545a12d1ed459ce4573f6b5`.

Source identity records the pre-publication parent revision and dirty snapshot;
it does not claim that uncommitted implementation was already present at that
parent commit. The requested publication uses `publish_living_road.ps1 -Ticket
XP-001` with explicit source and artifact paths. Its generated publication
receipt records the resulting commit and deployment outcome. User runtime
acceptance remains pending regardless of build or publication success.
