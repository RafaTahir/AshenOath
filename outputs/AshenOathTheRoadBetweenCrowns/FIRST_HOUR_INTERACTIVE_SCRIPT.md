# First Hour Interactive Script

## Emotional Shape

`work -> victims -> contradiction -> threat -> recognition -> compromised trust -> testimony`

The player begins with a familiar contract and ends with a sealed chapel ringing from within. The hour contains movement, optional conversations, investigation, preparation, combat, aftermath, a major report choice, NPC relocation, and a new mystery.

## 00:00-05:00 — Greyfen At Dusk

### Player Experience

Kael spawns on the south road. Ordinary sounds establish a functioning village: hammer blows, a cart wheel, cloth, a short exchange between villagers. After twenty seconds, the cemetery bell rings once. Nobody reacts openly; nearby work pauses for half a beat.

The notice board is visible but not mandatory. Speaking to Anwen directly can start the contract. The board offers the official version; villagers offer contradictions.

### Notice Board Text

> Three missing on the north road. Cart recovered. Payment for proof of beast or bandit. Names held at the shrine.

Pinned underneath in different handwriting:

> Do not let them call Bram drunk. He did not leave a cart behind in his life.

### Kael Observation

**Kael, quiet and practical:** “The contract asks for proof. The second note asks for a witness.”

### Optional Interactions

- Inspect black feathers pressed beneath the board nail.
- Ask Tor why the bell rang.
- Ask Rook who wrote the second note.
- Walk directly to Anwen.

## 05:00-12:00 — Sister Anwen

Anwen stands shrine-facing until Kael approaches. She turns after he speaks, not before.

### First Conversation

**Anwen:** “You took the road notice.”

**Kael:** “I read it.”

**Anwen:** “That careful, are you?”

**Kael:** “When a priest keeps the victims' names off the board.”

Anwen pauses. She looks toward the village, not the shrine.

**Anwen:** “Bram Kett drove the cart. Sella Vey was walking to the hill shrine. The boy was Oren. Twelve.”

**Kael:** “Three names. What aren't you telling me?”

**Anwen:** “Something on that road collects what belongs to the dead. If you find black feathers tied with red thread, don't burn them. Bring them back.”

**Kael:** “Why?”

**Anwen:** “Because I asked you not to.”

She hears herself and corrects course.

**Anwen:** “No. That's not enough. Because the thread is ours, and it should not be there.”

### Player Responses

- **“I'll bring back evidence.”** Anwen trust +1.
- **“You can explain when I return.”** Neutral; Kael establishes terms.
- **“If the shrine is involved, I report it.”** Fear unchanged now; public-report option highlighted later.

### Performance Direction

Anwen is tired, not mystical. Her first evasion is habit; her correction costs her. Kael never growls or performs toughness. He asks short questions and allows silence to become pressure.

## 08:00-12:00 — Optional Contradictions

### Rook

**Rook:** “Anwen gave you the names? That's new.”

**Kael:** “You know them?”

**Rook:** “I know Bram owed me two crowns. Dead men become respectable quickly.”

If asked about feathers, the humor stops.

**Rook:** “Red thread means burial. The shrine ties it around a name token. Not a wrist. Not cargo.”

### Mira

**Mira:** “If the bodies smell sweet, don't touch the mouths.”

**Kael:** “That specific warning usually has a story.”

**Mira:** “It has two fingers missing. The story can wait.”

She offers ingredients for one Moon Oil only if Kael inspected the board feathers.

### Tor

**Tor:** “Bell rope was cut last winter.”

**Kael:** “Then what rang?”

**Tor:** “If I knew, I'd have lied better.”

## 12:00-17:00 — The Gate And Broken Cart

Warm village light ends at the Wychwood gate. A torn red thread is caught on a splinter. The road ambience thins.

At the broken cart:

- Axle pin carries fresh tool marks: Bram tried to repair rather than flee.
- Cargo includes shrine candles not listed on the contract.
- Drag marks avoid the food sacks and lead toward personal belongings.

**Kael:** “Whatever took them left the meal and gathered the names.”

Finding the drag marks sets `brute_delayed = true`. Missing them does not block progress.

## 17:00-22:00 — Three Victims

Clues may be inspected in any order. Three of five advance the route.

### Bram

A worn wrench is clenched under the cart, stamped `B.K.` The corpse's boots face back toward Greyfen.

**Kael:** “Bram stayed with the wheel. Something moved him after.”

### Sella

Black feathers are tied with shrine-red thread around a pilgrim bead.

**Kael:** “Burial thread. Tied before she was buried.”

### Oren

Small footprints stop abruptly. A fragment of painted wood shows a crow with its name panel scratched away.

**Kael:** “Someone removed the name before the creature found it.”

### Optional Preparation

- Iron Trap creates a visible choke point and delays the Stalker.
- Moon Oil adds spirit feedback but is not required.
- Finding all five clues reveals the safe edge of the clearing.

## 22:00-30:00 — First Ghoulkin Pack

### Staging

Wave one: Raider and one Ghoulkin emerge near the gathered possessions. Wave two: Stalker enters from brush. The second Ghoulkin and Brute arrive after a delay. If drag marks were found, the Brute begins farther away. If a trap was placed, the Stalker enters through it.

### Readability

Enemies do not speak. During windups, fragments of bells, axle knocks, and whispered syllables mix into their audio. This suggests memory without turning them into talking zombies.

### Victory

The final creature falls without immediately disappearing. Its hand opens around Oren's complete token, wrapped in Vargan binding wire.

Music falls away before the objective updates.

## 30:00-36:00 — Aftermath

The player inspects:

- Complete token with name scratched away.
- Vargan wire used historically for sealing official records.
- Boot tracks belonging to a living person who visited after the attack.

**Kael:** “The dead gathered evidence. Someone living came to erase it.”

The return objective explicitly reads: `Return to Greyfen. Decide who receives the token.`

## 36:00-45:00 — Reporting

Three existing report points represent one major choice.

### Private: Sister Anwen

Kael places the token in her hand. She turns it over before reading anything.

**Kael:** “You know it.”

**Anwen:** “I know the carving.”

**Kael:** “That's not what I said.”

**Anwen:** “No.”

After a pause:

**Anwen:** “Oren was not the first child given that token.”

Sets `evidence_report = private`, trust +1.

### Public: Notice Board

Kael pins token and wire beneath the contract. Villagers gather but do not form a crowd scene. Doors close; ambient talk changes.

**Kael:** “The road was not hunted at random. Someone used shrine burial thread and Vargan wire. If either means something to you, stop waiting for permission to speak.”

Sets `evidence_report = public`, fear +1, trust -1.

### Retain Evidence

Kael reports only that the pack is dead. Anwen notices his closed hand.

**Anwen:** “You found something.”

**Kael:** “I found reasons to keep looking.”

**Anwen:** “Then keep them close. Greyfen has practiced taking things from the dead.”

Sets `evidence_report = retained`; unlocks leverage dialogue but weakens immediate trust.

## 45:00-52:00 — The Bell Answers

After reporting, the cemetery bell rings three uneven strokes. The shrine candles gutter. Anwen relocates to the cemetery gate. Rook stops joking. Tor extinguishes the forge if fear is high.

At the gate:

**Anwen:** “The bell rings once for burial. Twice when a name is restored.”

**Kael:** “That was three.”

**Anwen:** “Yes.”

**Kael:** “And?”

**Anwen:** “I don't know. That is the first honest answer I've given you.”

## 52:00-60:00 — Disturbed Graves

Three grave clues work in any order:

1. Harl's empty grave contains road mud.
2. An unnamed grave contains a Vargan buckle.
3. A child's grave has shrine thread tied from the inside.

Any two reveal that the cut bell rope runs beneath the chapel threshold. A brief Ghoulkin emergence occurs outside the camera's immediate rear and remains bounded by the cemetery wall.

After the encounter, the chapel bell rings from within. Dust falls from the sealed door. Anwen does not explain it.

**Anwen:** “Go back to the shrine. I need the old key.”

**Kael:** “You said you didn't know.”

**Anwen:** “I said I didn't know what three meant. I know what we locked in there.”

Cut no cinematic. Control remains with the player as the next objective appears: `Meet Anwen at the Ruined Crow Chapel.`

## First-Hour Acceptance

- The player identifies people, not generic corpses.
- Optional testimony changes understanding and preparation.
- Clue order cannot deadlock.
- Investigation visibly changes the encounter.
- The return report contains a meaningful choice.
- Anwen sounds guarded and human rather than oracular.
- The hour ends on an actionable location and conflict.
