# Ashen Oath Product Scope Lock

## Product

Ashen Oath is a grounded-stylized, story-led dark-fantasy action RPG built in Godot 4.6.3. Its defining loop is:

`investigate -> prepare -> confront -> choose -> see the world react -> return to the hub`

The project may take genre and production lessons from premium dark-fantasy RPGs, but it must not copy protected characters, plots, names, dialogue, music, or visual identity from The Witcher or any other franchise.

## Release Order

1. Public Web Act One: a polished 90-minute Greyfen, Wychwood, cemetery, and ruined-chapel slice.
2. Full Web campaign: a coherent 4-6 hour game.
3. Android feasibility build with landscape touch and gamepad support.
4. Google Play release if the feasibility gate passes.
5. iOS release after Apple hardware, signing, and store access are available.

Steam is not part of the current roadmap.

## Content Scope

The campaign is consolidated to six main quests:

1. Road of Crows.
2. Bell Beneath Greyfen.
3. Names in the Rain.
4. Ash and Banner.
5. Blood Under Stone.
6. The Hart Remembers.

Five side quests remain fully authored:

1. A Widow's Bell.
2. Iron Remembers.
3. Bitter Roots.
4. The Black Dog Contract.
5. Oren's Red Thread.

Other existing side-quest ideas become environmental encounters, testimony, or consequence beats. They do not remain journal filler.

## World Scope

Greyfen is the reusable hub. Authored bounded zones are Wychwood, cemetery/chapel, deeper wood/marsh, mill/farmstead, bandit road/Castle approach, Castle/undercroft, and Hart Glade. No additional zone is approved until the Web Act One acceptance gate passes.

## Production Constraints

- Free and legally redistributable assets only. CC0 is preferred; CC-BY requires recorded attribution.
- Grounded stylization takes priority over mismatched attempts at photorealism.
- Web remains the lead platform and must hold 30 FPS on the Dell 7280 class target.
- Mobile targets midrange 2020+ devices at stable 30 FPS.
- Premium one-time purchase is the intended mobile business model.
- Voice coverage is limited to key scenes and combat/world barks. Subtitles remain authoritative.
- No loot-rarity grind. Progression is nine meaningful upgrades across Blade, Oathfire, and Hunter disciplines.
- Minigames are optional village texture, never required campaign progression.

## Release Policy

The current live site is a prototype. Implementation tickets use local or preview verification. Production changes only at approved milestones after the authoritative release report passes, screenshots are reviewed, and the deployed PCK matches the verified local PCK.

## Acceptance Targets

### Web Act One

- 90 minutes of complete, authored play.
- Average 30 FPS; 1% low at least 24 FPS on the Dell 7280 target.
- Web payload below 100 MB and peak browser memory below 450 MB.
- No objective deadlocks, invalid data references, blocked routes, river crossings, missing actors, or browser console errors.
- Clear visual identity for Kael, Anwen, villagers, and the first monster family.

### Full Campaign

- 4-6 hours with six main quests, five side quests, and meaningful ending consequences.
- No zone or quest is represented only by a marker, box shell, or automatic dialogue completion.
- Save migration, keyboard/mouse, gamepad, accessibility, and end-to-end browser acceptance pass.
