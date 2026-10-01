# QA-002 release matrix wiring (2026-09-29)

Status: tooling implemented and statically verified; QA-002 remains pending.
Formal Recovery-004 acceptance remains 27/37.

The release runner now uses the verified production Web export for all browser
routes. It no longer builds a second QA Web preset or copies packs into a
different candidate. After the uninterrupted Chrome, Edge and Firefox main
route, it requires the 17 earned-save Chrome branch scopes and runs the
same-artifact QA-002 candidate assessor. All route gates, including the
candidate result, are mandatory in the release report.

Each branch report is stored in its unique release run directory. A resumed
release reads previously passing branch reports from their original run
directory, after the runner validates source, harness, execution, artifact and
owned-process identities. A changed pack or failed prior gate cannot be
silently reused. The browser driver now fails immediately if `--browser all`
cannot find all three required browsers.

Direct verification: PowerShell parser passed; nine focused candidate/wiring
tests passed; the PowerShell resume fixture reused two passing route reports
and ran only the missing branch plus assessor; Node syntax passed;
`git diff --check` found no whitespace errors. No Godot build, Web export,
browser route or production operation ran
for this change. Current native PERF-001 and visual gates remain red. The
release wiring does not approve QA-002, audio, accessibility, story, CERT-001
or RELEASE-001.

Next action: finish native performance and world/presentation prerequisites,
freeze one source-aligned production artifact, then execute the real-input
browser matrix. Retain passing evidence only while its inputs and artifact
remain identical.
