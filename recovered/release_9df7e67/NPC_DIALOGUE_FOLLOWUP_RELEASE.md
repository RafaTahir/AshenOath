# NPC grounding and optional conversation direction

Requested follow-up: complete NPC physicality and optional-dialogue direction, then push and deploy. The existing instruction excludes tests and verification.

Implemented:

- Extend the bounded two-bone foot adjustment to named NPCs and Greyfen workers with compatible Universal humanoid skeletons, including the existing deferred character loading path.
- Sample nearby NPC feet at up to 20 Hz, stop corrections for hidden, distant, dead, airborne or action-driven actors, exclude owning collision bodies from ground rays, and preserve animated swing-foot lift. Kael retains the existing 30 Hz path.
- Leave seated board opponents and incompatible/animal skeletons in their authored poses. No actor-root translation, collision, route or saved-state changes.
- Add explicit performance profiles for all ten optional conversation topics. Apply resolved outcome variants for Mira, Rook and Edric; use restrained final-answer gestures and corresponding listener reactions.
- Open optional exchanges with a two-person composition, follow the speaker, and use closer final answers where appropriate. Existing Reduced Motion behavior remains authoritative.
- Preserve dialogue text, history identifiers, availability, evidence and consent rules. This change does not generate additional voiced text.

Production packaging and deployment are authorized. No tests, gameplay launches, visual review, verification or post-deployment probes are included. Visual quality and runtime behavior remain unconfirmed.

## Publication — 4 October 2026

- Source: `d6a44938d3a0c6f297407f688be1be74ee3a41a0`; packaged release: `028caa6`.
- Build: `story-20261004T134714Z-d6a44938d3a0`, candidate `.release-gate/npc-dialogue-followup-02`.
- All runtime packs and Web export completed. Both `main` and `codex/story-centered-overhaul` were pushed.
- The first import stopped on an inferred-type compiler error; an explicit modifier type corrected it before packaging.
- The initial deployment returned Not authorized. Retrying the same authorized production deployment through the saved CLI login succeeded.
- Vercel returned `READY`: `dpl_9tnDzGVPfVsPrmS3nuKWz7P7uS7q`, aliased to `https://ashenoath.vercel.app`.
- Deployment URL: `https://ashenoath-4fs7pknba-rafaeitahir-5792s-projects.vercel.app`.
- No tests or verification were run.
