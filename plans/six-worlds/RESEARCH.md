# Research Appendix - Six Worlds, One Unfinished Oath

Date: 2026-10-19. Sources were consulted during the preceding planning pass.
This appendix reuses that research; it does not claim fresh playthroughs, full
video viewing, paid-access talk review or empirical proof of emotional effects.
Materials comprise developer-authored articles, direct developer interviews,
published slides, official game descriptions and public GDC talk abstracts.
Applications below are our design judgments, not the original developers' claims
about Ashen Oath. Fifteen reference titles are covered at different depths.

| Reference | Material actually reviewed | Principle adopted | What is not imported |
| --- | --- | --- | --- |
| The Witcher 3; Cyberpunk 2077 | CDPR interview and GDC session abstract | Turn emotional intentions into player actions; contrast warmth and loss; delayed acknowledgement | Characters, specific quest plots, Gwent, dialogue and proprietary art |
| God of War (2018) | Lead investment designer's authored exploration article | Separate substantial quests, small discoveries and ambient challenges; reward placement serves motivation | A cinematic production scale or mandatory ghost quest-givers |
| God of War Ragnarok | Studio progression article | Optional exploration has useful rewards; preserve playstyle investment | Gear rarity treadmill, giant gear catalog or new control scheme |
| Baldur's Gate 3 | Larian's official feature description | Local character agendas can intersect the campaign and react to choices | D&D rules, turn-based combat, multiplayer or combinatorial branch explosion |
| Mass Effect 2 | BioWare retrospective with developer accounts | Personal arcs can matter to the finale; manage absent participants explicitly | Recruiting a combat squad or a copy of its final mission |
| Horizon Zero Dawn | Guerrilla's 27-page narrative-system slides | Cause/effect graphs and concrete verbs keep story and implementation aligned | A replacement quest engine or mandatory new editor |
| Ghost of Tsushima | Environment lead's authored world-building article | Regional nature/settlement identity, environmental hints and discoveries | Guiding Wind implementation, landscapes or symbols |
| The Legend of Zelda: Breath of the Wild | Public GDC session description | Question conventions while preserving understandable player agency | Climbing everywhere, simulation sandbox, shrine checklist or copied puzzles |
| Elden Ring | Direct Miyazaki interview | The setting, boss and arena should be designed together | Mandatory opacity, punitive NPC quest obscurity or Souls economy |
| Bloodborne | Direct Miyazaki interview | Interconnected districts and return refuge can coexist | Cosmetic horror borrowing or a new warp/progression system |
| Sekiro | Direct Miyazaki interview | A defined protagonist can carry a legible immediate story within deeper lore | Its plot, resurrection rules or replacement combat system |
| Dishonored 2; Prey | Arkane developers' level-design/world-building articles | Places start with a strong idea; mundane life and alternative approaches reinforce it | A systemic stealth rewrite, time travel or full physics sandbox |
| Red Dead Redemption 2 | Direct Rob Nelson interview within a reported feature | Believable ordinary life supports emotional connection; scope remains bounded | Photorealism, simulation workload, horses or survival chores |

## Primary Links And Limits

1. [CDPR: Turning Emotions, Story, and Big Moments Into Gameplay](https://www.cdprojektred.com/en/blog/155/turning-emotions-story-and-big-moments-into-gameplay).
   Sarah Grummer discusses playable emotion, consequences and contrasting feelings.
2. [GDC: 10 Key Quest Design Lessons from The Witcher 3 and Cyberpunk 2077](https://www.gdcvault.com/play/1028897/10-Key-Quest-Design-Lessons).
   Public abstract reviewed; do not represent it as a transcript of all ten lessons.
3. [Santa Monica: How We Nailed Exploration in God of War](https://blog.playstation.com/2018/12/05/how-santa-monica-studios-nailed-exploration-in-god-of-war/).
   Anthony DiMento describes content categories, quest purpose and player motivation.
4. [Santa Monica: Ragnarok Progression Tips](https://blog.playstation.com/2022/11/08/10-gameplay-tips-for-god-of-war-ragnarok-power-levels-skill-labors-armor-set-bonuses-and-more/).
   Studio account of equipment investment and optional exploration rewards.
5. [Larian: Baldur's Gate 3](https://baldursgate3.game/about).
   Official product description, not a production postmortem; used for stated narrative capabilities only.
6. [BioWare: The Effect on Us](https://blog.bioware.com/2013/11/07/the-effect-on-us/).
   Developer retrospective addressing choices, loyalty and variable participant availability.
7. [Guerrilla: Building Non-linear Narratives in Horizon Zero Dawn](https://media.gdcvault.com/gdc2017/Presentations/Szczepanski_Leszek_Building%20Non-linear.pdf).
   Published slides by Leszek Szczepanski; steps, verbs and cause/effect graphs inform our cards.
8. [Sucker Punch: Crafting the World of Tsushima](https://blog.playstation.com/2020/07/09/crafting-the-world-of-tsushima/).
   Joanna Wang describes regional identity, nature, discoverability and production constraints.
9. [Nintendo: Change and Constant - Breaking Conventions with Breath of the Wild](https://www.gdcvault.com/play/1024562/Change-and-Constant-Breaking-Conventions).
   Session abstract, not a full-talk analysis. It does not establish specific quest-writing rules.
10. [Miyazaki: Elden Ring Development](https://news.xbox.com/en-us/2022/05/27/from-softwares-hidetaka-miyazaki-on-the-secrets-of-elden-rings-development/).
    Direct interview on adventure, freedom and the reciprocal design of area and boss.
11. [Miyazaki: Bloodborne](https://blog.playstation.com/archive/2015/03/20/conversation-bloodborne-creator-hidetaka-miyazaki/).
    Direct interview on connected areas and refuge/return structure.
12. [Miyazaki: Sekiro Story and Lore](https://blog.playstation.com/2018/07/13/interview-miyazaki-on-the-limbs-and-lore-of-sekiro-shadows-die-twice/).
    Direct interview; it is inspiration, not authorization to revise Ashen Oath's protagonist.
13. [Arkane: Designing an Arkane Game Level](https://bethesda.net/en-US/news/designing-an-arkane-game-level).
    Direct accounts from designers on space, everyday plausibility and intentional content.
14. [Arkane: Dishonored 2, Prey and the Arkane Way](https://bethesda.net/en-US/news/dishonored-2-prey-and-the-arkane-way).
    Direct developer accounts concerning grounded settings and layered history.
15. [Arkane: Creating Karnaca](https://bethesda.net/en-US/news/dishonored-2-creating-karnaca).
    Documents collaboration around history, architecture, industry and district identity.
16. [Rob Nelson interview: Behind the Scenes of Red Dead Redemption 2](https://www.theguardian.com/games/2018/oct/24/get-real-behind-the-scenes-of-red-dead-redemption-2-the-most-realistic-video-game-ever-made).
    Direct interview embedded in a journalist's feature. Our limited adaptation is believable daily life, not its simulation scale.

## Application To The Six Worlds

Each region gets a different practical conflict, emotional register and signature
encounter. Two new quests connect closely to regional pressure, two offer personal
or exploratory contrast, and Q05 makes aftermath playable. These are production
guidelines, not a requirement for identical quest structure or five mandatory stages.
Every optional story needs a person who wants something beyond delivering lore.
Each discovery needs an observable clue and a result; a hidden chest is not a
full quest merely because it has a named item. Warmth and humor are allowed to
matter without secretly proving another massacre.

Use authored branches that reconverge on facts plus a small set of persistent
outcomes. Do not create exponential new endings. Main evidence remains available,
records never become consent, and higher combat rewards do not moralize the choices.
The actual acceptance of writing, appearance, pacing and gameplay belongs to the
user's later review. None of the external games certifies our implementation.
