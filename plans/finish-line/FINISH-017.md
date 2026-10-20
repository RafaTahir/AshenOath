# FINISH-017 - Oil-System Decision

Parent: [FINISH-000](FINISH-000.md).
Disposition: Design approved; implementation present; final verification pending.
Mandatory finishing count: original 16 retained; this additional approved mechanic
must also be checked before the requested full release. No acceptance is inferred.
Compilation: production candidate finish-line-20261019-oils succeeded.
Publication: held for the full finish-line release; baseline production unchanged.

## Approved Decision - 2026-10-19

The earlier explicit deferral is historical. The user now approved the proposed
finite-oil rules and requested implementation, followed by one final verification
run. Publication is held for the complete finish-line release, not this mechanic alone.

## Player Outcome

The player can see the coating's remaining active-play duration. The earned
Ash-Tempered fitting extends it by 20%, without losing legacy oil selection,
inventory or checkpoint consistency.

## Locked Rules And Implementation

- Moon Oil and Rot Oil each last 300 seconds of active gameplay; the fitting makes
  a newly applied coating last 360 seconds. Existing blade tags/damage are unchanged;
  neither arrows nor Oathfire receives an oil bonus.
- Applying or refreshing consumes one bottle atomically. Refresh replaces remaining
  duration with the full current duration; it never stacks. A different oil replaces
  the previous coating. Earning the fitting does not retroactively refill an oil.
- InventoryManager owns coating/time. Game advances it only in active gameplay
  with living, controllable Kael, outside load/transition/pack waits. Menus, dialogue,
  pause, death and offline time do not spend duration. Checkpoint restoration uses
  the checkpoint's recorded supplies/coating/time; there is no extra automatic refill.
- HUD and preparation show remaining time; application confirms one bottle used,
  refresh remains available, and expiry clears the effect with a visible notice.
  Once-per-second time notifications do not fire inventory transactions or resource
  attention every frame.
- Save version 13 adds inventory oil-version/remaining-seconds fields. Normal
  Continue preserves finite positive remaining time even after the last bottle
  was used. Invalid/expired new timers clear the coating, never refill it.
- Legacy selected oils with no timer fields get one full duration without consuming
  a bottle. Restore that journey's progression before inventory so fitting ownership
  comes from the loaded save, not the outgoing session. Subsequent saves record time.
- Optional Moon Oil preparation still recognizes carried or applied oil. It does
  not become a mandatory purchase, and expiry does not undo an earned objective.

Existing inventory, progression, save, HUD and preparation owners are extended;
no new consumable manager, QA framework or replacement equipment system is added.

## Final Verification / User Checklist

The single final agent verification is authorized for the full candidate. No
intermediate game/test runs or independent oil-only deployment are authorized.

1. Apply/reapply/replace each oil; check exactly one bottle per action, 5:00 base,
   6:00 with the earned fitting, countdown, refresh without stacking and expiry.
2. Pause, enter dialogue, load regions, close/restart, die and Continue; confirm
   exactly the approved remaining time and no accidental extra use or expiry.
3. Compare the same oil with/without the fitting using legitimate earned state;
   confirm duration, displayed remaining time, blade-only effects and stacking.
4. Continue an actual old indefinite-oil save and check the approved migration.

## Delivery Record

2026-10-20 renewed allocation: joint FINISH-006/017 verification 1/1 PASS at
isolated service scope, owned process exit 0. Checked no-stock rejection, one
bottle per apply/refresh/replace, 300/360-second duration, countdown, expiry,
last-bottle coating serialization, malformed/expired timer clearing, legacy
migration with the loaded fitting, no retroactive refill and fitting retention
after respec. Log: D:/Temp/AshenOath/finish-006-017-20261020/stdout.log.
Game pause/dialogue/loading/death ownership and earned browser durability remain
unobserved; service assertions do not approve those remaining runtime conditions.

Decision approved 2026-10-19. Implementation/static review and production
compilation/package generation are complete. Candidate:
D:/Projects/AshenOath/.release-gate/finish-line-20261019-oils/export.
Complete Web size: 104,677,679 bytes, strictly below 104,857,600.
Root transport PCK SHA-256:
a6133aa0ebbf3f7405dd13540dae6e6185bebba18e790e86b3dc493c3edad29b.
The first authorized attempt failed before engine startup (HARNESS): the local
server omitted Content-Encoding: gzip for the compressed engine script. Its
report is D:/Temp/AshenOath/finish-line-20261019-one-run/browser.json. This is not
a demonstrated game or production artifact failure. The server now respects the
manifest's encoding declarations; no candidate bytes changed or were re-exported.
The user explicitly authorized one replacement attempt on those same bytes.
That hardware Chrome verification completed with a FAIL after 270,663 ms. Its existing driver
was aligned to Bell-before-shrine, Wychwood Bog ownership and full homecoming;
earned Moon Oil application/countdown/pause/durable Continue are in that same route.
It uses read-only observation and normal input, not manufactured state. Expected
report: D:/Temp/AshenOath/finish-line-20261019-replacement-run/browser.json.
It reached mouse New Game, initial Anwen dialogue, the Wychwood clues/five-enemy
fight and return, without recorded game-console/network errors. It stopped at
Anwen's enabled return-report choices (HARNESS-classified activation failure).
The later earned-oil check was NOT reached; no timer, expiry, fitting, migration
or oil-persistence result is inferred. The source-backed driver correction waits
for stable button geometry, handles Commit prefixes and confirms page outcomes;
it is syntax-checked only, not rerun. Both reports identify the same artifact
fingerprint 74df2982e7471397321e8b60d3b80b9cfa4ec8294f577b2ee8b27f0d564d46cd.
The failed profile/earned saves are retained on D:. Owned browser/server processes
were closed by the runner. The approved replacement allocation is consumed.
Next required check is normal Anwen report activation, followed by earned oil
application/pause/countdown/durable Continue, after renewed testing authorization
or through the user's checks. No further agent runtime test was launched.
Oil runtime observations and user acceptance remain pending, not inferred from build.
All other finishing requirements, including strict performance and actual-phone
functionality, remain mandatory. No publication occurred for this work.

Latest targeted authorization evidence (a31, 2026-10-20): the genuinely earned
last Moon Oil bottle was applied through Preparation/Supplies. One bottle became
zero; the coating started at 300 seconds, stayed unchanged in preparation, then
counted down in active play. Real Quick Save/durable browser storage/reload/normal
Continue restored the last-bottle coating with 298.7773 seconds remaining, without
offline refill or consuming another bottle. These browser cells now pass and are
frozen; a later unrelated Rootbound failure does not invalidate them. Existing
300/360-second service, refresh/replace/expiry/migration checks remain valid.
Death/dialogue runtime permutations and explicit user acceptance remain pending;
no unobserved permutation is inferred from the service or browser results.
Report: D:/Temp/AshenOath/finish-targeted-20261020-a31-deepwood/browser.json.

