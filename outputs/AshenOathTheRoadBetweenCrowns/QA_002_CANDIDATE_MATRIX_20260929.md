# QA-002 Candidate Matrix

Status: aggregation implementation passes offline tests; QA-002 remains pending.
Formal Recovery-004 acceptance stays at 27/37.

`tools/verify_qa_002_candidate.mjs` binds every supplied browser route report
to one freshly hashed production-preset export. It requires the uninterrupted
player-driven campaign in Chrome, Edge and Firefox, plus the earned-save
opening Save/Continue, four-ending, main-choice and side-quest matrices in
Chrome. It rejects missing scopes, changed pack bytes, diagnostic observation,
direct state-mutation checkpoints, browser console/network errors, unmeasured
or excessive JS heap, missing route captures, absent Chrome/Edge Web Audio
unlock, and incomplete Hart outcomes. It preserves Firefox audio state as an
explicit BiDi limitation. Performance and semantic screenshot approval remain
separate mandatory gates.

Focused verifier tests: 7 pass, zero fail, including deliberate missing-branch,
stale-artifact, mutation, ending, audio, screenshot, error and payload cases.
No browser route, Web export or new game verification was run for this change.

After native performance and visual prerequisites pass, invoke the browser
driver for each required scope on one immutable candidate, then assess the
report set with:

```powershell
node tools/verify_qa_002_candidate.mjs --export <candidate-directory> `
  --output <candidate-report.json> --report <route-report-1.json> `
  --report <route-report-2.json>
```

Repeat `--report` for the entire scope list. The resulting report may state
`complete_qa_002_acceptance: true` only when all required real-input evidence
on those same bytes passes. It is not a substitute for CERT-001.
