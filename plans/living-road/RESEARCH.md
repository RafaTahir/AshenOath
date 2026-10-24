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

## People, Place And Honor: RDR2 Adaptation (2026-10-24)

This is a sourced design adaptation, not a claim to have played or reproduced
RDR2, watched inaccessible conference talks, or achieved Rockstar's production
scale. Developer and performer accounts inform the following original choices.

- [Rob Nelson, GamesBeat, part one](https://gamesbeat.com/red-dead-redemption-a-deep-dive-into-rockstars-game-design/)
  and [part two](https://gamesbeat.com/red-dead-redemption-a-deep-dive-into-rockstars-game-design/2/)
  discuss character specificity, optional shared experiences and emotional
  contrast. Ashen Oath uses a finite collection of authored work, company and
  return scenes. It does not generate interchangeable companion missions.
- [Houser and Nelson, GQ](https://www.gq-magazine.co.uk/article/red-dead-redemption-2-interview)
  describe a protagonist with convictions and a detailed, responsive world.
  Kael remains competent; material protection and accountability challenge his
  assumptions. Useful bread, dry tools and safe passage must exist alongside
  the covenant argument, rather than becoming more speeches about it.
- [Benjamin Byron Davis, GQ](https://www.gq-magazine.co.uk/article/red-dead-redemption-dutch-interview-benjamin-byron-davis)
  discusses embodied performance and escalation. Use gaze, restrained gesture,
  work points and listeners. Subtitle-only writing is not fabricated lip-sync.
- [Woody Jackson interview, Nerdist](https://nerdist.com/article/red-dead-redemption-2-soundtrack-music-red-bull-concert-woody-jackson/)
  informs deliberate quiet and player-paced transitions. Reuse existing buses,
  music and ducking, leaving room for environmental and gameplay cues. No new
  soundtrack or voice service is necessary.
- [PlayStation's firsthand account](https://blog.playstation.com/2018/10/01/22-things-you-need-to-know-about-red-dead-redemption-2/)
  provides supplementary observation of everyday interaction. This is not a
  primary technical specification for Ashen Oath's runtime.

Honor is an explicit Ashen Oath design decision: one StoryState deed ledger,
bounded individual knowledge, no prices, ending gates or new currency. Refusing
romance, refusing an oath, omitting optional work and morally complex covenant
outcomes are neutral. A favorable score never buys consent or forgiveness.
Twenty anchor scenes and twelve short exchanges reuse WORLD-SAGA activities,
CAST routines/performance, existing navigation and the journal. Six optional
walks stop safely on separation. No camp, horse, survival tax, crime simulation,
new quest count or copied plot is introduced.

## A Campaign Worth Remembering: Witcher Case Notes (2026-10-24)

This additive amendment covers the base game, Hearts of Stone and Blood and
Wine, including spoilers. It draws on the linked written sources, not a claim
to have replayed every quest, checked every NPC line or watched inaccessible
conference recordings. Applications and their implementation owners are recorded
in [CAMPAIGN_WORTH_REMEMBERING.md](CAMPAIGN_WORTH_REMEMBERING.md).

| Specific example and source | Original adaptation and execution |
| --- | --- |
| [Lilac and Gooseberries](https://www.gamebanshee.com/thewitcher3/walkthrough/lilacandgooseberries.php): family, mentorship, the road and a practical search precede the large conflict. | Greyfen retains its playable opening. Maren's relief arrival uses Anwen's care and Tor's repair work before her recognition of Kael; no compulsory dream or cinematic. |
| [The Beast of White Orchard](https://www.gamebanshee.com/thewitcher3/walkthrough/thebeastofwhiteorchard.php): victims, local expertise, the dead mate and bait contextualize the griffin. | Existing encounter approaches gain inspectable physical signs and useful existing counterplay. Journal text distinguishes reading a sign from actually observing its creature. |
| [Family Matters](https://www.gamebanshee.com/thewitcher3/walkthrough/familymatters.php): material evidence revises an established account; sympathy does not erase harm. | Kael's retreat report and Maren's limited account can be read in either order. Public/protected correction changes custody, not the facts or her consent. No copied family plot or absolution reward. |
| [Ladies of the Wood](https://www.gamebanshee.com/thewitcher3/walkthrough/ladiesofthewood.php): belief, traces, intermediaries and direct presence create different stages of anticipation. | Bell scars, water-edge tracks, guarded roots, ash plumes, disciplined blade marks and Hart tracks use different retained props. Creature introductions are remembered only with visible presence and line of sight. |
| [Pyres of Novigrad](https://www.gamebanshee.com/thewitcher3/walkthrough/pyresofnovigrad.php) and [the royal wake](https://www.gamebanshee.com/thewitcher3/walkthrough/thekingisdead-longlivetheking.php): independent work and shared customs introduce people and institutions. | Existing regional anchors emphasize wet timber, seeds, loading, crossing supplies, copying and shelter. Keep recognizable work and limited knowledge rather than another line of quest dispensers. |
| [Quest-designer interview](https://www.gamepressure.com/editorials/interview-with-cd-projekt-reds-lead-quest-designer-pawel-sasko/zd661): personal branches can converge into consequential campaign scenes. | Existing Assembly and epilogue owners acknowledge only completed relief work and publicly disclosed correction. Private evidence never becomes general gossip. |
| [Hearts of Stone interview](https://gamingbolt.com/the-witcher-3-hearts-of-stone-interview-the-dawn-of-new-adventures) and [Dead Man's Party](https://www.gamebanshee.com/thewitcher3/walkthrough/deadmansparty.php): a personal arc benefits from contrasting kinds of play and relief. | Six escort chapters alternate care/repair, tracking and physical route choice, a supported lift, a resumable crossing, correction and ordinary company. They are not six document inspections. |
| [Blood and Wine interview](https://www.pushsquare.com/news/2016/05/interview_partaking_in_blood_and_wine_with_the_witcher_3_developer_cd_projekt_red) and [Blood Run](https://www.gamebanshee.com/thewitcher3/walkthrough/bloodrun.php): an attractive region can conceal violence; a relationship complicates an apparent threat. | Relief work and an optional supper coexist with guarded disagreement. The existing playable homecoming remains the destination; no new estate, companion authority or automatic forgiveness. |
| [The Last Wish](https://www.gamebanshee.com/thewitcher3/walkthrough/thelastwish.php) and [personal epilogues](https://www.gamebanshee.com/thewitcher3/walkthrough/somethingendssomethingbegins.php): freely chosen relationships and remembered behavior carry personal consequences. | Company and distance are legitimate final outcomes. Maren chooses her next route. All four explicit covenant endings remain available without this arc, and no hidden correct-answer ending score is introduced. |
| [Official PC manual](https://cdn-l-thewitcher.cdprojektred.com/media/TW3/Pdf/Manuals/PC/The_Witcher_3_Wild_Hunt_Game_Manual_PC_EN.pdf): threat knowledge and preparation support an integrated combat toolkit. | Teach existing openings, ground, channels and plume recovery. Do not change damage balance, copy Signs/toxicity, or require preparation. Keep level 30, 17 Marks and 20 practices. |
| [CDPR character transcript](https://www.cdprojektred.com/en/blog/173/beyond-the-concept-giving-life-to-characters-and-monsters-transcript-included) and [audio-team interview](https://www.asoundeffect.com/the-witcher-3-sound/): silhouette, performance and environmental sound communicate place. | Reuse retained human bodies, work assemblies, expressions, regional audio and protected dialogue. The facial sample still requires user approval before broader rig work; no new voice production or soundtrack. |

The approved scope adds six optional quests to the retained 51, for 57 total.
Each new quest awards 300 completion XP once through the existing reward claim.
Honor remains Ashen Oath's own system, not a Witcher mechanic. Runtime quality,
phone controls, listening and acceptance remain user-owned and unverified by
this build-only implementation.
