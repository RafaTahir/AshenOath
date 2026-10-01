# QA-002 Full-Campaign Preflight

Status: implementation repair, not browser or ticket acceptance. Recovery
remains 27/37 accepted; production is unchanged.

The production browser driver previously failed every ordinary
`--full-campaign` invocation before it could execute its player-driven route.
The shared gate helper no longer contains the historical state mutation, so
that unconditional placeholder was removed. A full-route invocation now
requires production read-only observation and refuses diagnostic preparation,
early stop, startup-only timing override, and startup replay. The report names
the result `campaign_main_player_driven` and retains
`complete_qa_002_acceptance: false`; one Witness main-path run cannot certify
all endings, side branches, saves, inputs, browsers or performance.
Every browser report now includes one fingerprint over every exported file,
including runtime packs, so later scope reports can be tied to identical bytes.

The direct Node syntax check and 35 focused production-mode tests passed.
The complete offline QA-002 group passed 96 tests with one live-only test
skipped, including changed-pack invalidation; log:
`D:/Temp/AshenOath/qa002_offline_identity_20260929.log`.
These tests cover routing and preflight only, not Godot or browser execution.

Next: after native PERF-001 and visual prerequisites are accepted, export one
source-aligned production candidate and run the complete main route on Chrome,
then Edge and Firefox using the same bytes. Run genuine-save ending, side,
accessibility and audio matrices on that candidate before accepting QA-002.
No export, commit, push, merge or deployment occurred.
