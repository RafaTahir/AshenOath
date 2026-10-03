# Ashen Oath: story presentation direction

This is the implemented direction for the road-renewal campaign. Existing complete, licensed, connected rigs and atlases remain the anatomical source. New story keepsakes, restrained native facial movement, conversation rhythm and authored score phrases carry the revision. No human visual or listening review was performed in this session at the user's request.

## Material and colour language

Greyfen wears repaired cloth, worn ash timber, dull iron and warmed linen. Vargan uses the same materials arranged with deliberate symmetry: authority is a human institution, not a different fantasy culture. Restored testimony introduces unbleached paper, not magical blue signage. The road's danger is announced by broken material rhythms and quiet, not by increasing decorative saturation. New plot props use three repeated forms: the cut cord, the folded name record and the open ring. Each has a physical use in the story.

Preserve skin, imported facial anatomy, hand proportions, locomotion grounding and existing clothing atlas detail. Cast palette changes apply to semantic material channels where those exist; a combined prebaked atlas is preserved intact. Socketed keepsakes use one rough material, no dynamic shadows and a fourteen-metre visibility limit. They never replace a face or become floating anatomy.

## Cast identities

| Character | Read at a distance | Object that expresses the story | Conversation rhythm |
| --- | --- | --- | --- |
| Kael | Moss cloth, weathered linen, controlled stance | A cut oath ribbon carried openly | Listens before speaking; a single acknowledgment |
| Anwen | Slate blue, pale hair, established staff | Dull bell token | Slow, open offer; concern without theatrical collapse |
| Rook | Narrow reed-green silhouette | A doubled road knot | Quicker explanation, brief sideways attitude |
| Mira | Olive work clothes and practical layers | Tied root ribbon | Careful offer; relief changes posture after disclosure |
| Tor | Broad charcoal and leather work silhouette | Plain iron ring | Few movements; a deliberate acknowledgment |
| Elna | Muted plum and ash grey | A folded name packet | Grief held in a slight downward gaze and long stillness |
| Toma | Ochre and grain-coloured cloth | A flour-coloured packet | Concern expressed practically, not as comic fussing |
| Senn | Worn blue-grey uniform | Cut military oath ribbon | Pauses before recalling an order |
| Edric | Symmetrical cool charcoal and oxblood | A tarnished seal | Economical explanation; guarded after confession |
| Halvern | Weathered iron and desaturated cloth | The same broken oath as Kael | Deliberate acknowledgment; no triumphal hero pose |

## Performance and animation rules

Only the speaking actor's rig and face continue animating while dialogue pauses the game. Schedules, collisions and other actors remain paused. A conversation begins with acknowledgment, then one brief authored gesture roughly every eight seconds, with character-specific pacing. Gestures return to attentive stillness even when the source Interact clip loops. The native head modifier adds restrained gaze, a nod or a held attitude after base animation; it does not translate the root or affect attack reach. No synthetic lip motion is presented as speech synchronisation.

Facing and camera distance remain owned by DialogueRuntimeCoordinator's existing walkable placement contract. Weapons and staff remain on their authored bone sockets. The existing damage/recovery clock remains authoritative for combat; presentation gestures cannot interrupt a hit, death or combat attack. Root motion remains disabled for shared animation clips. Full new performance capture, retargeted bespoke hand contact and detailed lip synchronisation require assets beyond this source revision and are not claimed by these changes.

## Sound identities and score

The road theme is the interrupted D-A-C-E phrase. Greyfen's helped community answers with an open D and A; recovered names use sparse bell partials separated by air; coercive renewal adds an unresolved lowered harmony. Witness supplies a public, brightened answer. Mercy leaves a gentle unresolved space. Duty returns to the opening fifth as work that will continue. Ash removes notes and lets the final phrase die away. Ending themes are selected only after resolution, so selecting an ending does not musically declare the task complete.

These seven original procedural compositions are rendered offline by `tools/build_story_score.py`. They have explicit note starts, rests, acoustic-style envelopes and short room reflections, replacing a uniform drone only in the selected story states. Existing combat scores retain priority. Recorded village, paper, forge, river, cloth and bell effects remain part of each region's sound identity.

Dialogue ducks music by eight decibels and the cue bus by five, with a fast entrance and slower release. Music and quiet ambience continue under dialogue while world one-shots and random accents pause. Current page speech interrupts the prior page cleanly. Voice lookup requires the current narrative revision, exact speaker and exact text; generated performances must be honestly marked in the production manifest. Missing or mismatched audio stays silent while the subtitle remains authoritative. Channel sliders remain authoritative throughout ducking.

The generated soundtrack has not been listened to or approved by a human in this session. Generated voice performances likewise do not imply actor direction, human performance approval or lip synchronisation.
