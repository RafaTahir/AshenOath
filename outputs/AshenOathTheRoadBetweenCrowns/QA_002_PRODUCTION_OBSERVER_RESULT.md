# QA-002 Production Observer: Native Contract

## Result

The query-gated production observer now exposes a schema-2, read-only snapshot
for browser route certification. It reports readiness, player and camera,
focus and interactions, gate catalog, enemies and bosses, quests and story,
inventory, saves, audio, input, runtime packs, dialogue, and rolling FPS.
It has no command channel. This is an implementation and native contract pass,
not a production-browser or full-campaign pass.

The browser harness now has a separate `--production-observer` mode. It reads
the production snapshot, consumes a read-only catalog-ID route query, and
rejects every legacy QA mutation command. Its report explicitly labels the
opening or gate-circuit scope and never marks complete QA-002 acceptance.
The adapted driver passes directly affected offline Node tests; no exported
browser run is claimed.

The route-query native rerun at
`D:/Temp/AshenOath/qa002_production_observer_route_20260929.log` exited 0 and
cleanly shut down. It returned a nonempty physical route to Anwen, rejected
an unknown catalog ID, and preserved story flags and inventory. Browser
binding delivery, input convergence, and campaign breadth remain untested.

The catalog now refreshes after its bounded one-second interval even when a
deferred nested Area3D leaves root-level child and interaction-cache counts
unchanged. `D:/Temp/AshenOath/qa002_catalog_refresh_20260929.log` is a passing
real-scene native regression: it adds a nested test interaction after the first
catalog read, observes that interaction after the interval, then exits cleanly
without parser, renderer, resource, or ObjectDB errors. This is observer
correctness only, not player-route or browser acceptance.

The observer now includes dialogue speaker, text, action labels and focused
action, plus the player, camera, enemy, quest, audio, settings and UI fields
needed to observe later real-input campaign states. Its real-scene contract
passes at `D:/Temp/AshenOath/qa002_observer_batch_20260929.log` with clean
shutdown. The browser driver can select a named dialogue action using real
arrow-key focus movement and Enter. `node --check` and 11 directly affected
Node tests passed on 2026-09-29, including rejection of absent/ambiguous
choices and production mutation commands. No campaign choice has yet been
accepted in a browser.

A separate `--through-cemetery` scope now follows the existing player-driven
opening route with physical Anwen, grave, ambush, chapel and shrine actions.
It asserts the corresponding objective IDs and cleansed shrine flag. The
driver parses and its directly affected dialogue/production tests pass, but
this new scope is **not** a route pass: it has not run against source-aligned
Web bytes, and `complete_qa_002_acceptance` remains false. The legacy full
campaign mode still refuses certification because it stages prerequisites.

The directly affected Node tests in
`D:/Temp/AshenOath/qa002_static_tests_20260929_v2.log` pass 13/13. This
includes read-only route-query matching and a hard failure for all legacy QA
mutation commands in production-observer mode. No exported-browser claim
follows from these offline tests.

The complete QA-002 JavaScript test group also passes 29/29 in
`D:/Temp/AshenOath/qa002_all_static_20260929.log`. This preserves existing
movement, deadline, dialogue, startup, and transport behavior at the static
driver level only.

The ticket and release runners now route every full-campaign desktop/mobile
browser gate to the production `Web Browser` artifact with
`--production-observer true`, instead of certifying the materially different
QA export. A direct Node guard checks all six release invocations and both
ticket-runner branches; its three focused tests pass. The legacy full-campaign
driver still blocks certification until it is replaced with real input, so
this wiring does not turn a partial route into a pass. No Web export or browser
run was started for this runner-only change.

## Direct Evidence

- `tools/verify_qa_002_production_observer.gd` instantiated the real main
  scene, started New Game, and checked the Greyfen snapshot and a second read.
- Story flags and inventory were unchanged after both reads.
- `D:/Temp/AshenOath/qa002_production_observer_20260929.log` exited 0 with
  `QA-002 PRODUCTION OBSERVER: PASS` and no script, resource, ObjectDB, or
  renderer errors through shutdown.

## Remaining

The existing browser driver still uses QA mutation commands in full-campaign
mode. Port it to this observer and real input, prove Chrome and Edge on the
same source-aligned production artifact, and implement/test Firefox BiDi.
Do not certify browser gameplay from this headless native test. No Web export
is scheduled while `PERF-001` is native-red.
