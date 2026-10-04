# NPC movement and conversation delivery

Implemented for the NPC improvement request, retaining the user's instruction to skip tests and verification.

- Village walkers translate along their body heading, ease into bends, and rebuild interrupted routes from their current position. Nearby walkers slow down and yield with short spatially constrained passing routes.
- Passing the player no longer always interrupts a routine. Ambient greetings have per-person cooldowns, approach gating, and speaker attribution.
- Conversation entry preserves positions and eases both actors toward one another. Page changes no longer repeatedly snap their orientation.
- Speaker/listener animation follows actual voice playback, including interruption, completion and history pauses. Production voice assets now include sampled amplitude envelopes for restrained head delivery and native jaw motion where the imported rig provides a jaw bone. This is amplitude-driven motion, not phoneme lip synchronization.
- Faces briefly break eye contact and stop tracking someone behind them. Conversation face updates run at 30 Hz. Focus and expression are restored afterward, and workers resume their prior work pose.
- Deferred character presentation is picked up by ambient controllers. Nearby actors retain animation farther from the player, and distant village bodies remain visible when their animation is suspended. Inactive cached villages do not continue their life simulation.

Existing synthetic voice recordings remain synthetic and have not received a listening review. No gameplay testing, visual verification, or post-deployment probing was performed. The production pipeline compiles and packages the application for deployment.
