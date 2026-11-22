# QA-002 Candidate Outcome Contract

Status: offline verifier improvement only; **27/37 accepted**. No game export,
browser certification, commit, push, or deployment followed from this change.

The final QA-002 candidate assessor previously required all scope names and a
matching artifact, but most branch scopes passed with any nonempty checkpoint
list. It now requires the browser driver's existing, scope-specific result
events: an ordered uninterrupted main chapter route; every choice in the
shrine, report, ledger, Edric, mill, Senn and side-quest matrices; Save/Continue
restoration; and the three distinct named-dead candles. The four Hart endings
remain required. These are report-level guards, not a substitute for observing
the exported game through real input.

Verification: `node --test tools/verify_qa_002_candidate.test.mjs` passed
13/13, including deliberately incomplete campaign, missing branch outcome,
missing earned-save, and missing candle cases. The current artifact is not
release-certified. Next: retain the final same-artifact Chrome/Edge/Firefox
browser matrix as the QA-002 acceptance gate after native visual and
performance prerequisites pass.

# Hardware-render identity

The candidate assessor now requires each accepted browser scope to report
`renderer_mode: hardware` and a non-software unmasked WebGL renderer. A
software diagnostic report cannot satisfy the campaign matrix even if its
route events and artifact hashes match. The deliberate software/missing
hardware test passes in the 13-case offline assessor suite. This is a QA
contract improvement, not browser acceptance; QA-002 remains pending.

The release runner had relied on the browser driver's software-renderer
default. Its desktop campaign, resumed campaign and Chrome branch invocations
now explicitly request hardware, as do the corresponding mobile-emulation
invocations. The combined assessor/release-wiring offline suite passes 15/15.
