# A cup and a coat: playable opening

## Implementation plan

Build a brief, optional human encounter before Anwen's account. New journeys receive three physical interactions beside the existing shrine approach: pick up the waiting cup, leave it on the sheltered tray for the injured traveler, and move Oren's coat out of the weather. First speaking to Anwen introduces this work without completing the investigation briefing; speaking again opens her existing account. Players may immediately continue to the account without completing either activity.

Use a dedicated opening presentation controller installed through the existing story activity director. Keep interaction dispatch, dialogue, input, History and persistence on existing services. Store only additive opening flags in StoryState; preserve every quest/objective ID, existing evidence requirements, resources and older-save progression. Model the cup, tray, bench and coat locally so this beat adds no asset-pack download to first control. Keep completed props visible and include short exact-text Anwen/Kael voice assets in production generation.

The cup delivery is care, not a bargain for testimony. The coat establishes Oren as someone expected home and receives a callback when his road token is found. Neither activity supplies evidence, consent, a morality score or currency. Anwen's main mystery account remains intact.

## Build and release constraints

No tests, gameplay sessions, screenshots, QA, verification or post-deployment probes. Production voice generation, source catalog, Godot import/compiler diagnostics, runtime packs and Web export are required artifact production. Commit source, build with the existing release script, push both authorized branches and deploy to the existing Vercel production project. Report build and CLI publication outcomes without claiming tested gameplay.

## Status

Source implemented: physical cup pickup/delivery and coat sheltering, an optional invitation with direct access to Anwen's existing account, response-aware greetings, persistent care records and an Oren-token callback. Existing saves do not opt into the new introduction. Cup carrying is reconstructed from saved flags when returning to Greyfen. No investigation objective, evidence threshold or resource reward was added.

The first production attempt generated 420 exact-text voice clips, then Godot exited with a native access-violation status after asset import/editor-layout completion. No script compiler diagnostic was reported by that invocation. Its artifacts/logs are retained in `.release-gate/playable-opening-01`; publication was not reached. The final package will include the delivery-aware Anwen greeting as well.

Remaining requested improvements after this release: convincing character performances; deeper everyday village consequences; precise, weighty, readable combat; smoother navigation and journey flow.
