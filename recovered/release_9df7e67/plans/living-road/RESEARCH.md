# Research: The Witcher 3 and Ashen Oath

Research completed 2026-10-08 from the sources below, alongside source inspection
of Ashen Oath's existing equipment, combat, inventory, vendors, quests, dialogue,
activities and save systems. No game was launched. GDC session descriptions were
read; the full talks were not watched. Recommendations below are design judgments,
not claims that every player experiences the same emotions.

## Principles And Original Adaptation

| Observed principle | Player effect | Ashen Oath implementation |
| --- | --- | --- |
| A monster hunter prepares and chooses tools for a known threat | Competence comes from attention, not only stats | Steel/Oathblade, discovered weaknesses, preparation and vendor supplies |
| A professional journey is tied to personal bonds | Contracts become worth caring about beyond payment | Named victims, Anwen/Rook/Tor friendship, Mira/Vale and a hound who travels with Kael |
| Choices have delayed, imperfect consequences | Responsibility and uncertainty survive the dialogue menu | Remember promises, refusals and acts; show them in later scenes and endings |
| Inventory supports immediate preparation and tactical decisions | Less friction between discovering danger and acting | Categories, comparison, quick slots and clear costs; no copied clutter or repair treadmill |
| Drawing and carrying two swords is part of the protagonist's physical identity | Equipment feels owned and connected to the body | Two bone-attached back scabbards, exclusive hand visibility and interruptible draw/sheath |
| Ordinary games and warm conversations interrupt danger | Contrast gives grief, wonder and humour space | Archery, field trials, retained tavern games, shared work and optional gathering |
| A landscape contains ecology, labour and the residue of earlier events | The world feels inhabited and causally connected | Readable trails, wildlife, resting places, companion reactions and aftermath |
| A quest's structure combines acting, mechanics and consequences | Emotion occurs through play as well as exposition | Short human exchanges, playable care, testimony choices and visible encounter consequences |

## Source Notes

1. [Official The Witcher 3 overview](https://www.thewitcher.com/us/en/witcher3)
   describes the hunter's tools, two swords, the search for Ciri, choices and
   side activities. Transfer the relationship between profession and personal
   stakes. Do not copy Geralt, Ciri, Triss, Yennefer, Gwent or their plot lines.
2. [Official PC manual](https://cdn-l-thewitcher.cdprojektred.com/media/TW3/Pdf/Manuals/PC/The_Witcher_3_Wild_Hunt_Game_Manual_PC_EN.pdf)
   documents equipment, combat, inventory and controls. It is evidence for
   distinct sword selection and preparation systems, not a reason to overwrite
   Ashen Oath's existing bindings or recreate every economy mechanic.
3. [CD Projekt Red: turning emotions, story and big moments into gameplay](https://www.cdprojektred.com/en/blog/155/turning-emotions-story-and-big-moments-into-gameplay)
   discusses collaborative quest construction and emotional impact through
   gameplay. Use playable acts, reactions, pauses and consequences together.
4. [Pawel Sasko: 10 Key Quest Design Lessons](https://www.gdcvault.com/play/1028897/10-Key-Quest-Design-LessonsStartup)
   session description emphasizes engagement, brevity, emotional impact,
   branching and production efficiency. Apply bounded authored scenes and
   reusable existing systems. No claim to have reviewed the full talk.
5. [Matthew Steinke: The Living World of The Witcher](https://www.gdcvault.com/play/1023867/The-Living-World-of-The)
   session description covers economy, progression and rewards beyond the main
   quest. Reward preparation, relationships and visible change, not coin alone.
6. [Marcin Blacha interview](https://www.pcgamer.com/games/the-witcher/the-witcher-3s-story-director-says-an-ideal-quest-is-constructed-in-such-a-way-that-the-player-puts-the-controller-away-stands-up-and-starts-walking/)
   discusses choices that make players stop and think. Retain moral uncertainty
   without hiding immediate objectives or making dialogue choices misleading.
7. [Quaternius Ultimate Animated Animal Pack](https://quaternius.com/packs/ultimateanimatedanimals.html)
   is the CC0 source family for Bracken. Retained Dog.fbx matches the existing
   raw source (SHA-256 A7250B3C68857120E6DA0FD9EA2CDB4A4493823B6AFED371B7AA9208407AF039).
   Complete runtime animation/provenance preparation in LR-008; no proxy fallback.

## Emotional And Narrative Direction

Kael's intimacy should grow from showing up, listening and acting at personal
cost. Mira has obligations to patients; Vale has obligations to records and the
living people those records endanger. Neither trades romance for medical help,
evidence, testimony or access. Both are adults. Friendship, a declined advance,
disagreement and reconciliation receive authored outcomes. Commitment requires
an explicit mutual choice. Do not reduce affection to repeatable dialogue points.

Bracken offers companionship and attention to the world without solving it for
the player. His rescue does not explain away the Black Dog Contract's dangerous
memory fragment. Everyday feeding/petting is optional warmth, not a maintenance
tax. Ordinary combat does not permanently kill the companion.

Bell-Eater reflects silenced names; Rootbound reflects corrupted guardianship;
Ashwing is drawn to burned testimony; Halvern's testimony remains bounded by
memory; the Hart bears an impossible witnessing burden. Their encounters should
make these causes legible through clues, behaviour, counterplay and aftermath.

## Existing Foundations To Extend

EquipmentLoadout, swept melee traces, bow/projectiles, InventoryManager,
VendorService, StoryState, QuestBeatDirector, authored story/voice data, journal,
activity/directing services, save version 10, Three Marks and Greyfen Draughts
already exist. Implement extensions at those ownership boundaries. Preserve the
ten-chapter campaign and four covenant endings. This roadmap is not an asset
replacement project or another engine/QA reconstruction.
