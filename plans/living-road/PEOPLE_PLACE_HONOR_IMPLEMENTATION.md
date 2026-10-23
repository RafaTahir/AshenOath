# People, Place And Honor

Date: 2026-10-24. Owners: WORLD-SAGA-000, CAST-004/006/009/010, existing Living Road.
Implementation is separate from compilation, publication and user acceptance.
Runtime acceptance: **UNVERIFIED - REQUIRES USER TESTING**. No gameplay, browser
QA, screenshots, benchmarks or new test fixtures are authorized for this change.

## Retained Contract

All six worlds, 51 quest IDs, choices, rewards, relationships, equipment,
prepared characters, four endings and playable homecoming remain. No new quest,
currency, camp, horse, crime system or autonomous quest progression is added.
The pending Greyfen facial-sample review remains pending; no extra rig rollout.

## Implementation

- `people_place_scenes.json` contains 20 anchor scenes and 12 short exchanges.
  Existing Greyfen/regional life controllers play them; StoryActivityDirector's
  regional staging remains the installation owner. No second quest controller.
- Existing registered actors claim social presentation, yield to protected
  dialogue/work and danger, and return to their routines afterward. Missing or
  departed bodies are not replaced with invisible voices. Edric resolves to
  the actual current record-hall actor; Senn's return exchange requires his
  surviving testimony outcome. Other Senn fates retain Tavin's account.
- Six short walks use existing spatial routes, body locomotion, collision and
  achieved movement. Separation, route obstruction, pause, menus and danger
  release presentation safely. The player is never moved, tethered or failed.
  Route retries are bounded/staggered, not whole-world per-frame scans.
- One ambient subtitle channel inherits subtitle scale, background and speaker
  settings. It cannot consume Use, replace an objective or claim the camera.
  Approved voice assets alone can drive speech; new text uses subtitle acting.
  Existing music ducking supplies quiet without changing saved volume.
- A turn becomes remembered only after its reading/playback duration completes.
  Interrupted turns repeat, completed turns do not. Save data stores the scene
  signature so changed outcome variants cannot resume into the wrong sentence.
- The existing gathering invitation/window now gives applicable people real
  walkable positions around the table. Ordinary services and actor interactions
  remain usable. Expiry/danger releases work; no new calendar or required chore.
- Seven journal reflections unlock from heard scenes, not regional discovery
  flags alone. Homecoming additionally requires its existing final road walk.
  Friendship, Mira/Vale, Bracken and the gathering retain their existing owners.
- Anwen's refusal now remembers Kael declining to demand her oath. No threat,
  consent, affection or moral penalty is invented from the refusal flag.

## Scene Map

| Region | Anchors / retained activity owner | Two exchanges |
| --- | --- | --- |
| Greyfen | `gre_arrival` kitchen/care; `gre_warning` repaired Jory mechanism/Tor; `gre_company` common table; `gre_renewal` Anwen/supplies (walk); `gre_home` practical homecoming | `gre_exchange_before`, `gre_exchange_after`: Nessa/Rook, borrowed kettle |
| Wychwood | `wyc_work` Iven's grove; `wyc_water_walk` Edda's work/trail (walk); `wyc_return` actual watercourse | `wyc_exchange_before`, `wyc_exchange_after`: Iven/Edda, stack/water |
| Deep Woods | `dep_work` Ressa's plot (walk); `dep_freight` Dain's present account; `dep_rebuild` recorded mill/shelter | `dep_exchange_before`, `dep_exchange_after`: Dain/retained second worker |
| Long Road | `roa_crossing` Nera (walk); `roa_safety` Tavin/Senn; `roa_return` actual restored passage | `roa_exchange_before`, `roa_exchange_after`: Tavin/Senn, the latter testimony-only |
| Castle | `var_work` Lysa/Vale; `var_authority` present Edric (walk); `var_after` institutional and bounded Halvern account | `var_exchange_before`, `var_exchange_after`: source/copy comparison |
| Hartlands | `har_work` Maelin/Oris; `har_care_walk` bounded promise (walk); `har_after` actual covenant at the grove | `har_exchange_before`, `har_exchange_after`: tools, stopping, supper |

Every scene declares its human purpose and physical action; the catalog's shared
direction contract supplies interruption, knowledge limits, performance and
consequence rules. Explicit conditions/variants narrow those rules. Existing
first-report, Bell-Eater, renewal, Assembly and covenant consequence projections
remain authoritative; ambient completion creates no substitute milestone.

## Honor

`StoryState.record_honor_event(id)` validates an authored deed against recorded
state. `honor_view(actor_id)` returns shared journal/presentation information.
The saved ledger is additive under existing flags, not a new save schema.

- Range -100..100. Distrusted <=-10; Unproven -9..9; Respected >=10.
- Practical flour/drain/water/mechanism/delivery and shared-friend work: +2.
  Bracken's explicit rescue, escorted unconditional shelter and a proven
  fulfilled Rook privacy promise: +5.
- GRE-Q01 `coerced`: -10 for threatening household address exposure.
- DEP-Q01 `falsified`: -10 only after physically retagging/placing the knowingly
  false present dispatch. Old command/wage proof is untouched.
- VAR-Q02 `conditional_pass`: -10 after physically withholding the optional
  complaint and delivering the real family pass. Guaranteed campaign proof is
  never removed. Other normal routes and all rewards remain.
- Deed groups prevent generic help plus harmful-method double awards. Harm
  overrides generic help and cannot be washed away by a refresh or later chore.
- Canonical observers limit who knows each event. Personal grievances remain
  higher priority than a favorable overall score. Optional regional dialogue
  can ask how things stand without blocking essential conversation.
- Legacy migration requires exact flags/finished physical parts, or an explicit
  relationship memory proving a promise preceded the deed. Generic refusal,
  missing stages, erased evidence, purchases, games, exploration, ordinary
  combat, romance and endings are never assigned inferred moral credit.

## Build And Publication

Candidate: `people-place-honor-20261024`. Compilation: passed (editor import,
enemy runtime, regional life controller, StoryState and HUD check-only builds).
Package: **104,808,755 bytes**, 17 files, **48,845 bytes below** the cap.
Root transport PCK SHA-256:
`b1a85adb63345dd5f60d218a246d0a1c6db1a28cee3364b086a83edf0ee1de6e`.
The immutable engine URL is unchanged. All pack ownership and hashes passed
static packaging inspection. Candidate bytes are synchronized to `web/`.
Publication owner: CAST-010; its current `.release-gate/living-road/` receipt
records actual commit, push and Vercel completion separately from acceptance.
User observations/acceptance: none for this change.
No performance gain or reference-PC compliance is claimed.

Lossless standard-gzip optimization uses optional Zopfli 0.4.0 during packaging
(build module directory on D:); decoded PCK/JS identity is preserved and checked.
The version is recorded in `tools/requirements-web-packaging.txt`. This build
uses `PYTHONPATH=D:\Temp\AshenOath\build_dependencies`; without the optional
module, packaging retains standard gzip and still fails closed if over budget.
The unchanged prior root PCK yielded 55,768 bytes of compression savings. The
engine script remains on its existing encoding/URL to retain browser caching.
This is packaging evidence, not runtime proof.
The final package passes the strict below-104,857,600-byte requirement.

## User Checklist

1. Visit each region before/after its work. Approach the named people; interrupt
   exchanges with Use, pause, walking away and safe combat. Resume/Continue: no
   skipped choices, forced movement, doubled voices or abandoned ownership.
2. Join the common table, speak with its people, leave and return. Required
   services/conversations still work; invitations never require game victory.
3. Read journal Honor and reflections. Repeat work/reload: no duplicate deeds.
   Check the three harmful methods and honest alternatives from genuine saves.
4. Check private knowledge and persistent personal grievances. Respectful oath
   and romantic refusals remain neutral; all four endings remain available.
5. Check long/short screens, subtitle scale/background, saved settings, approved
   speech/subtitle fallback and music recovery. Actual phone behavior and the
   audible mix require your review.
6. Keep the full homecoming (Anwen, bench, road). Check actual Hart presence or
   its legitimate absence; no dead/departed Senn or Halvern appears as a speaker.
