# ASHENOATH — THE GRAND NARRATIVE EXPANSION

## Creative and Technical Master Directive

You have been provided with the complete AshenOath novel, *The Road Between Crowns*, consisting of approximately 79,435 words, a prologue, 36 chapters, and an epilogue, together with its game adaptation companion and supporting narrative materials.

This represents the next major creative milestone for AshenOath.

Our ambition is to transform AshenOath into a deeply engaging, emotionally compelling, cinematic dark fantasy RPG, with the narrative ambition, character development, world-building, and emotional resonance associated with The Witcher 3 and Red Dead Redemption 2.

We are not copying those games. We are establishing our own identity at a comparable level of creative ambition.

## 1. Your objective

Adapt the entirety of the supplied novel into the existing playable AshenOath experience.

Surround, enrich, expand, and where necessary restructure the existing storyline to accommodate the novel's complete narrative.

You are authorized to make substantial changes to the game's narrative flow, quests, dialogue, encounters, character interactions, environmental storytelling, cinematics, and supporting gameplay systems where those changes serve the story.

Do not unnecessarily rebuild functioning systems.

This is a full narrative transformation of the existing game, not a separate game, a disconnected expansion, or a collection of additional dialogue.

## 2. Understand everything before implementation

Read the complete novel and adaptation companion.

Use the supplied Markdown manuscripts and chapter map where available for reliable retrieval and indexing.

Inspect the current local repository, including any changes made since the repository baseline was prepared.

Understand the existing campaign, world geography, quest graph, character identities, combat systems, progression, relationships, save architecture, assets, and technical constraints.

Establish a persistent narrative implementation ledger containing every chapter, significant scene, revelation, character arc, emotional turning point, and consequential decision.

Map each to existing gameplay or required new gameplay.

Identify contradictions between the novel and current implementation. Resolve them deliberately, preserving the strongest narrative and gameplay outcome. Record material departures from the novel and the reasons for them.

Do not silently omit substantial story content because it is inconvenient to implement.

## 3. Adapt the story into experiences

The novel is not simply a source of dialogue.

Translate literary storytelling into interactive experiences.

Use the following wherever appropriate:

- Real-time cinematic sequences.
- Character performances and expressive animation.
- Companion journeys and conversations during travel.
- Environmental storytelling and discoverable evidence.
- Dynamic encounters and interruptions.
- Character-specific activities.
- Investigation and deduction.
- Negotiation, confrontation, and deception.
- Meaningful combat and monster encounters.
- Romantic and platonic relationship development.
- Quiet moments of companionship, humor, and vulnerability.
- Persistent consequences of player decisions.
- Changes to settlements and NPC behavior.

Avoid converting entire chapters into long conversations, collectible documents, or walls of text.

The player should live through the story rather than merely read about it.

## 4. Make the characters feel alive

Kael and the twelve principal supporting characters must become memorable individuals with independent motivations, fears, loyalties, contradictions, ambitions, and emotional histories.

They should remember what has happened.

Their relationships should develop throughout the campaign.

They should sometimes disagree with Kael, surprise him, disappoint him, challenge him, or refuse him.

Implement the novel's emotional development through dialogue, behavior, animation, schedules, shared activities, and consequences.

Give the characters opportunities to laugh, grieve, become angry, fall in love, feel ashamed, experience jealousy, demonstrate courage, and express affection.

Not every interaction needs to advance a quest.

The world should contain moments that exist because these people are alive.

## 5. Preserve the thriller

Maintain the novel's deliberate sequence of revelations.

Track what each character knows, when they learn it, and whether the player has discovered the relevant evidence.

Do not reveal major secrets prematurely through ambient dialogue, quest descriptions, journal entries, or unrelated interactions.

Build suspense through incomplete information, contradictory testimony, escalating danger, and the changing interpretation of earlier events.

Make betrayals emotionally consequential.

Foreshadow major revelations without making them predictable.

Ensure the story's climax feels earned through everything the player has experienced.

## 6. Preserve and expand player agency

The novel establishes one complete literary route through the story.

It does not eliminate alternative player choices.

Preserve the six established ending methods: Witness, Mercy, Duty, Ash, Concord, and Open Road.

Adapt the novel's dramatic developments to support alternative decisions and their consequences.

Respect character availability, refusal, consent, death, exile, relationship boundaries, and previously established choices.

Do not force the player into the novel's specific romantic relationship or ending.

Where the novel introduces a fixed event that conflicts with meaningful existing player agency, develop appropriate conditional alternatives.

Each ending must receive a satisfying dramatic resolution and a meaningful aftermath.

## 7. Improve cinematic presentation

Use the available Blender and Godot capabilities to support the narrative.

Develop reusable cinematic tools and scene-specific performances where appropriate.

Consider:

- Camera composition and movement.
- Character blocking.
- Facial expressions and body language.
- Environmental lighting.
- Weather and atmosphere.
- Music and silence.
- Spatial sound.
- Meaningful pauses.
- Character-specific gestures.
- Transitions between gameplay and cinematics.

Do not rely on camera effects to disguise inadequate character animation or asset quality.

Use cinematics purposefully. Preserve player control during scenes where interaction creates a stronger experience.

## 8. Implement the complete journey

Organize the work around the novel's four major movements:

**Act I — The Road of Crows**

Establish the world, Kael, the missing travelers, the mystery, and the first emotional connections.

**Act II — The Names They Burned**

Deepen the investigation, expose the buried history, and develop the competing motivations of the principal cast.

**Act III — The Price of Bread**

Escalate the political, material, personal, and emotional consequences. Bring earlier decisions and relationships into conflict.

**Act IV — The Road Between Crowns**

Deliver the revelations, confrontations, climax, branching resolutions, and meaningful aftermath.

Include the prologue and epilogue in the adaptation strategy.

Do not treat these acts as independent prototypes. They must form one coherent, continuous playable campaign.

## 9. Protect existing progress and architecture

Preserve the functioning gameplay systems, assets, world, and existing player progress wherever possible.

Respect the existing ownership boundaries between quest state, story state, dialogue, presentation, world lifecycle, and save systems.

Use campaign revisioning and appropriate save migration for substantial changes to the quest graph.

Do not manufacture completed quests, evidence, relationships, consent, or rewards during migration.

Protect uncommitted work and existing production assets.

Maintain an isolated, reviewable implementation branch until the expanded campaign is ready for integration.

Preserve the browser deployment target and monitor loading times, memory, runtime performance, and package size.

Resolve existing continuity and architecture problems when they directly affect the narrative implementation.

Do not run obsolete authoring generators that would overwrite newer campaign content.

## 10. Execute continuously and systematically

Do not stop after producing a proposal, roadmap, or implementation plan.

Begin implementation immediately after establishing the necessary narrative and technical baseline.

Work through the campaign in coherent, playable sections.

Maintain persistent records of:

- Implemented chapters and scenes.
- Outstanding narrative content.
- New and modified quests.
- Character and relationship states.
- Required and completed assets.
- Cinematic sequences.
- Branching decisions.
- Continuity dependencies.
- Technical blockers.
- Deviations from the novel.

Use these records to preserve context across long-running sessions and context compaction.

Continue through the complete narrative without requiring routine approval for every individual scene.

Escalate only genuinely consequential decisions that cannot reasonably be resolved from the supplied material.

## 11. Definition of completion

A chapter is not complete simply because its dialogue has been added.

A chapter is complete when its essential narrative events, emotional development, player interactions, consequences, and transitions are represented in the playable game.

A technically successful implementation is not automatically an artistically successful implementation.

Provide actual gameplay evidence of major narrative milestones.

Keep verification proportionate during production. Conduct a comprehensive integrated campaign verification before final release, including branching outcomes, save continuity, and representative playthroughs.

Do not claim the entire novel has been adapted while substantial portions remain as placeholders, documentation, inaccessible scenes, or unimplemented dialogue.

## Final directive

You are responsible for translating a complete dark fantasy novel into a living, interactive world.

Treat the supplied story with the seriousness of a major studio's narrative production.

Be ambitious. Be creative. Make intelligent adaptations. Preserve what already works and transform what does not.

Make players care about these people.

Make them laugh with them, distrust them, love them, fear for them, and remember them after the game has ended.

The objective is not simply to make AshenOath longer.

The objective is to make AshenOath unforgettable.

Begin.
