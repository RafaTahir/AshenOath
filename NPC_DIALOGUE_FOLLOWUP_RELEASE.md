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
