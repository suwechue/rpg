# Character Dossier Brief: Project Vector

Use this brief to write character dossiers for **Project Vector**, a game I'm building. Reuse the professors and characters from this chat wherever they fit a role below, and keep their names and personalities. Invent characters only for roles with no good match, and mark those as **NEW**. The output goes straight into the game's design files, so stick to the format at the end.

---

## The game in one paragraph

Project Vector is a top-down 2D pixel-art RPG. You play the new kid in a small town who starts at the local high school. By day you pick classes, raise stats, explore the town (Gary's Deli, the blacksmith, the hospital and more) and make friends or enemies. Every weeknight a force called "the spark" pulls you into **the Upside-Down**, a twisted mirror of the town that rebuilds itself every night. There you fight in turn-based tactical grid battles using spell cards. Every Friday night there's a boss. People you befriend can join your party. A sarcastic **narrator** comments on everything, and is also a character you can meet. The tone is a wry small-town high school comedy with real stakes underneath: if you die, the run is over.

## Systems a character plugs into

**Stats (1 to 20, players start at 3 to 8):** STR, DEX, CON, INT, PER (perception), WIL (willpower), CHA (charisma).

**Personality, called "disposition" (each axis −100 to +100):** Courage, Greed, Curiosity, Loyalty, Kindness, Pride. This is how an NPC reacts to what you say. For example, compliments land with high-Pride characters, and jokes land with high-Curiosity ones. Each character has a resting value per axis that they drift back to over time.

**Magic "Vectors" (elements):**
- Tier 1: Heat, Cold, Force, Motion
- Tier 2: Binding, Light
- Tier 3 (rare): Transmutation, Vitality, Corrosion

Each character has 1 to 3 Vectors they lean toward.

**Spell shapes ("Forms"):** Bolt, Burst, Shield, Weapon Infusion, Line, Sphere, Projectile, Touch, Aura, Construct, Glyph.

**Combat classes:**
- Starting: Mage, Fighter, Rogue, Healer, Bard
- Advanced: Elementalist, Kinetic Logician, Spellblade, Guardian, Trickster, Medic, Idol
- Hidden: Deli Knight, Smith-Mage, Upside-Touched

Party members have a class. Mentors unlock or teach advanced classes.

**School classes (one professor each):** PE, Physics, Chemistry, Earth Science, Shop Class, Drama, Debate, Biology, History. A single professor can teach two subjects. Ms. Duval currently teaches both Drama and Debate.

**Bond with the player (−100 to +100):** Enemy, Rival, Stranger, Acquaintance, Friend (41 or more, can be recruited), Close (combo spells unlock), Unbreakable (personal story arc and a unique card).

**Traits:** small modifiers such as +2 CHA, +10% Heat affinity or "misinterprets jokes". Story characters have **fixed** traits. Background characters **roll random** traits every run.

**Dialogue topics:** things the player can bring up with a character. Each topic has a tone, may need a minimum CHA to unlock, and has a chance of being misheard. A misheard line should be a funny but plausible alternate version.

**Time:** a weekday has 8 parts: Before School, Period 1, Period 2, Lunch, Period 3, After School, Evening (the Upside-Down), Night. Weekends have Morning, Midday, Afternoon and Evening. Characters have a schedule of where they are during each part.

## Places

- **Home:** the player's house.
- **High school:** classrooms, cafeteria, gym, field, library.
- **Gary's Deli.**
- **The blacksmith.**
- **The hospital.**
- **Town square.**
- **Library.**
- **Park and woods edge:** the entrance to the Upside-Down, where the narrator first appears.
- **Arcade or hangout spot.**
- **Abandoned lot:** a secret area.

## Story beats each character can hook into

| Week | Beat | Boss |
| --- | --- | --- |
| 1 | You arrive. Kelly and you get pulled into the Upside-Down on night one. | The Hollow Mascot (from the pep rally and cheer squad) |
| 2 | Other students are getting pulled in too, and you start forming a party. | The Cold Cut (from Gary's Deli freezer) |
| 3 | The town starts noticing: disappearances, and the forge goes cold. | The Forge Revenant (from the blacksmith's forge) |
| 4 | The hospital's closed wing hides the Upside-Down's history. | The Night Ward (from the hospital) |
| 5 | The Mirror Town. The narrator's true role, which is still undecided. | The Mirror Town (the whole town) |

## Roles to fill

Reuse a character from this chat wherever one fits.

| Role | Requirements and current placeholder |
| --- | --- |
| **Kelly** (fixed, keep as is) | The popular, rude cheerleader. Pride 70, Kindness −30 at rest, Courage 20, Loyalty 60 once earned. Gets pulled into the Upside-Down with the player on night one. If the player treats her badly that day, she panics and accidentally gets them killed. Recruitable later, but only at a high Bond. |
| **Gary** (fixed) | Owns Gary's Deli. Kind, protective of his recipes. Sells food buffs, offers part-time shifts and spreads town gossip. Mentor for the hidden Deli Knight class. |
| **The blacksmith** (needs a name) | Gruff and loyal. Sells gear and teaches an apprenticeship. Mentor for the hidden Smith-Mage class. |
| **Hospital doctor** | Placeholder Dr. Reyes. Knows more than she says, and is tied to the week 4 story. Mentor for Medic. |
| **Hospital nurse** | Placeholder Nurse Patti. Warm and gossipy. Runs the volunteer shifts. |
| **Professors** (one per school class) | Physics (placeholder Prof. Okafor, Kinetic Logician mentor), Chemistry (Prof. Lindqvist, hints at Tier 3 magic), PE and cheer adviser (Coach Barrett, tied to Kelly), Drama and Debate (Ms. Duval, Idol mentor), History (Mr. Hale, Upside-Down lore), and Earth Science, Shop Class and Biology (all three need someone). |
| **4 recruitable students** (one per class) | Placeholders: Theo (nerdy Force and Motion mage), Mara (artist, Light and Binding healer), Dex (class clown rogue), Priya (debate captain, Bard). |
| **Cheer squad** | 2 to 3 of Kelly's friends who create social pressure. |
| **Optional extras** | The librarian, the mayor, the player's parent or guardian, and 2 to 3 other memorable students or townsfolk. |
| **The narrator** | Sketch their voice and a few possible identities. Don't settle the reveal. |

## Output format

Write one block per character, in exactly this order:

```markdown
## <Name>  (<role>)  [REUSED from <chat source> | NEW]

**Summary:** One or two sentences, including how they fit the town.
**Appearance:** One or two lines a pixel artist could draw from (16x16 sprite plus a portrait).
**Personality:** Two or three sentences.
**Voice:** How they talk, plus two sample lines.

**Stats:** STR x, DEX x, CON x, INT x, PER x, WIL x, CHA x    (only for party members and fighters)
**Combat class:** <starting class> → <likely advanced class>    (party members only)
**Vectors:** <1-3 elements, strongest first>
**Disposition (resting):** Courage x, Greed x, Curiosity x, Loyalty x, Kindness x, Pride x
**Fixed traits:** 2-3 traits, each with its game effect
**Starting Bond with player:** number

**Where to find them:**
| Day part | Location |
| --- | --- |
(list the weekday parts where they appear, plus weekends)

**Teaches / mentors:** school class or advanced class, if any
**Recruitable:** yes or no, and how (Bond threshold, quest, story flag)

**Dialogue topics (3-5):**
- "<topic label>". Tone: <axes>. CHA needed: <n or none>. Good reaction: ... / Misheard as: "..."

**Likes / dislikes (gifts):** ...
**Story hooks:** which week(s) and how they're involved, and their personal arc at Close or Unbreakable Bond
**Upside-Down version:** how this person or their place appears twisted in the dungeon, if at all
```

Then finish with:

1. **A summary table** of every character, with columns: Name, Role, Reused or New, Class, Vectors, Recruitable, Main location.
2. **A list of anything from this chat that didn't fit**, so I can decide what to do with it.
