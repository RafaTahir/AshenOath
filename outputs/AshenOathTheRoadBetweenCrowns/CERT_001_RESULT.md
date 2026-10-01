# CERT-001 — Accepted Functional Candidate

Date: 2026-10-02. Profile: `functional_candidate`. Browser scope: `lean_functional_smoke`.

Authoritative report: `release_reports/functional_candidate_v10.json`; retained raw evidence: `release_reports/recovery004_v10_evidence/`.

V10 remains unchanged: PCK `5ddd1873ae33a55354f046201a3c379b88466eb40f0bd1a9a0389280f3857067`, 15 files / 96,042,769 bytes. Browser inventory uses its existing JSON fingerprint; release inventory uses its existing NUL-separated fingerprint. Both independently validate the same per-file bytes; these algorithms are not interchangeable.

Five owned aggregation gates pass: preserved scoped native/visual evidence, the Chrome/Edge/Firefox browser matrix, production security, export/pack completeness, and the canonical 37-ticket registry. The strict report completeness validator then verifies exact runtime content, harness, artifact, registry, image hashes and Codex semantic approvals. Preservation binding explicitly identifies the existing V10 export log and captured runtime inputs, not an invented export-time snapshot. No accepted scene, campaign or browser run was replayed.

Controlled fixtures reject missing gates, failed processes, stale dirty-source inputs, changed files/logs, changed/missing/duplicate acceptance rows, diagnostic mutations and use of the functional preservation binding as strict-performance certification.

Disclosures: numerical performance targets are not certified; peak native private memory 683.62 MB; slow startup/transition/hydration samples remain reported. Mix listening review is false. Unavailable physical controllers are untested. Exhaustive autonomous browser campaign, boss and ending coverage was intentionally removed and did not pass; preserved native story/branch evidence retains its original scope.

Running steps:

```powershell
cd D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns
.\tools\run_release_gate.ps1 -AcceptanceProfile functional_candidate -FunctionalEvidence .\release_reports\recovery004_v10_evidence\bundle.json -SkipExport -SkipScreenshots -SkipPerformance -Strict
```

Progress: 36/37. RELEASE-001 remains pending exact-byte promotion and live verification.
