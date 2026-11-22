# QA-002 Gate Mutation Removal

Verdict: retained harness correction, not QA-002 acceptance. Formal recovery
remains 27/37 accepted.

`driveToGate` still contained a `fullCampaign`-only `stage_gate` QA command,
although normal full-campaign mode was deliberately fail-closed before that
path could run. The command teleported the approach and contradicted the
real-input contract. It is removed. The shared helper now obtains a read-only
route and uses camera rotation, movement, focus and interaction input in both
partial and eventual full-campaign scopes. The production observer continues
to reject all mutation commands. The full-campaign certification gate remains
fail-closed until the complete route and branches actually pass in exported
browsers.

The offline production-mode test now inspects the shared gate helper as well
as the full-campaign wrapper, so the old gap cannot hide behind a clean
wrapper. `node --check tools/verify_qa_002_browser.mjs` passed; the affected
Node group passed 34/34; the complete offline QA-002 JavaScript group passed
94, skipped one live-only test, failed zero.

No Web export or browser route was run. Chrome/Edge/Firefox campaign traversal,
save branches, input convergence and production artifact identity remain
unaccepted. Next: retain the fail-closed gate and exercise the mutation-free
route on one source-aligned production candidate after native performance and
visual prerequisites pass.
