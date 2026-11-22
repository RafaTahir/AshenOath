# Ashen Oath: The Living Road

Agreed 2026-10-08. Implement on `D:\Projects\AshenOath`, branch
`codex/masterpiece-rebuild`. This program adds 28 sequential tickets to the
retained game; it does not reopen or recertify Recovery-004.

## Creative Contract

The existing story remains about staying with the living when their safety
depends on a lie about the dead. Build attachment through useful work, shared
time, humour, disagreement and remembered decisions. Monsters should express
human causes and leave consequences in the landscape.

Study The Witcher 3's design principles, not its characters, dialogue, quests,
music, symbols or proprietary assets. Ashen Oath keeps its original setting,
stylized asset family, ten main chapters, existing side quests and four endings.
See [research](RESEARCH.md) for primary sources and limits of that research.

Locked choices:

- Steel and Oathblade are two distinct physical swords. Bow remains available.
- Optional adult romance with Mira and Vale; friendship and refusal remain full paths.
- Bracken, a living black hound, is an optional companion with a separate rescue.
  The Black Dog Contract remains the dangerous memory-fragment investigation.
- Archery and outdoor field games join the retained Three Marks and Greyfen Draughts.
- Preserve A-set character identities, Senn's Ranger, camera rotation/first-person
  zoom, all saved choices, existing controls, worlds and authored content.
- No mandatory weight grind, repair tax, hunger chores, junk inflation, card-game
  replacement, horse system, coerced romance or permanent ordinary-combat pet death.

## Shared Implementation Contracts

- Extend `EquipmentLoadout`: retain `active_weapon` values `sword` and `bow`;
  add `selected_blade_id` (`steel`, `oathblade`). Legacy saves select Steel.
  Both scabbards use validated back bones; only the drawn blade occupies the hand.
- Inputs: `1` Steel, `2` Bow, `3` Oathblade, `H` draw/sheath. Controller weapon
  cycle covers all three; hold cycles no weapon and toggles sheathing. Preserve
  saved remaps; expose new actions through the existing settings UI.
- Extend InventoryManager, item data and VendorService. Keep transactions atomic.
- StoryState owns relationships, promises, companion recruitment and consequential
  activity outcomes. Preserve existing trust values, including `anwen_trust`.
- CompanionController owns movement/commands and uses the existing spatial and
  streaming services. Save durable identity/state, never live node references.
- Extend existing activity, dialogue, quest and save coordinators. Do not introduce
  parallel authorities for objectives, money, consent, rewards or endings.
- Subtitles remain authoritative. Use the existing offline voice pipeline only;
  unapproved performances fall back to subtitles. The user reviews listening quality.

## Delivery Contract

Read this file, the active ticket, `PROJECT_STATE.md` and directly affected code.
Implement one ticket completely, inspect its source diff, run only the minimum
required compilation/export, then perform static package/hash/size checks.
The user is the sole runtime, gameplay, browser, visual, audio and performance
tester. Do not launch the game, browsers, automated routes, tests or screenshots.

Delivery amendment, 2026-10-08: LR-001 through LR-008 are already published.
Keep LR-009 through LR-028 local on D: with individual result documents and manual
checklists. Do not push, integrate to main or deploy after individual tickets.
Publish the combined source and aligned Web artifact once, after LR-028, unless
the user explicitly changes this instruction. This amendment overrides per-ticket
publication wording in ticket templates. Do not update `codex/story-centered-overhaul`.
Use `implemented_local_awaiting_user` for finished local implementation and
`published_awaiting_user` only after publication. User acceptance remains separate;
repair reported defects before proceeding. Continue sequential implementation
without waiting between tickets; no self-issued runtime acceptance.

The complete `web/`, including manifests, must be strictly less than 104,857,600
bytes. The retained baseline is 91,966,392 bytes; reserve about 4 MiB of headroom.
Use reuse/deduplication/lossless transport before adding payload. Never delete
content or silently lower quality to fit. Raw downloads, screenshots and builds
stay outside the Web payload. All project files and scratch stay on D:.

The final combined runtime changes require a fresh production export. Intermediate
ticket exports are not required. Finish the LR-009 build already in flight locally;
do not publish it. Documentation must retain each existing artifact's provenance.
No candidate's source identity may be relabelled to a later commit without export.
See [delivery](DELIVERY.md) for commands and staged-publication boundaries.

## Sequential Tickets

| Milestone | Tickets | Outcome |
| --- | --- | --- |
| A: Equipment and preparation | LR-001 through LR-007 | Baseline, two blades, inventory, preparation and shops |
| B: Bracken and landscape | LR-008 through LR-012 | Rescue, travel, bond, tracking and rest |
| C: People, friendship and love | LR-013 through LR-020 | Human conversations, friends, Mira and Vale |
| D: Games and ordinary joy | LR-021 through LR-024 | Archery, field trials and Greyfen gathering |
| E: Monsters and lasting consequences | LR-025 through LR-028 | Personal encounters, living regions and endings |

Each ticket is in `tickets/`. Current delivery state is in [STATUS](STATUS.md).
The common delivery/ownership rules above apply to all 28 files.
