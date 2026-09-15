> Historical design reference. Current kits, items, map sizing and Oddity behavior are superseded by REWORK_2026-09-15.md.

# hero//vault — Development Handoff

## 1. Core Game Identity

**hero//vault is a hero-statistics MOBA autobattler / spectator simulation.**

The player is not mechanically controlling heroes. Heroes autonomously:

- farm and gain XP
- level and scale
- fight and duel
- gank and get ganked
- rotate
- pursue or retreat
- protect allies
- clear waves
- pressure structures
- use abilities and items

The closest design touchstones are **Weapon Balls / OC Ball Lab**, filtered through the vocabulary of a MOBA.

The primary fantasy is not “master a character mechanically.” It is:

**build a roster, give them traits/items, then watch the little freaks develop histories.**

A good match should naturally produce stories such as:

> Hazmat got the Blood Crown, killed three heroes, finally died to Irene, and now Irene has it.

Individual interactions should therefore be **legible, consequential, statistically interesting, or simply funny to watch.**

---

# 2. Major Design Philosophy Change

## Heroes should generally become simpler, not more complicated.

Do **not** give every hero a bespoke minigame, resource meter, stance system, special targeting system, or elaborate combo tree.

A hero is successful when their identity emerges from:

**stats + behavior + 2–3 strong actions + an ultimate or defining move**

rather than six interconnected mechanics.

Abilities with very similar purposes should be merged or deleted.

An ability that can produce several naturally related outcomes is preferable to several tiny specialized abilities.

Each ability should normally have:

**one primary job + at most one meaningful supporting effect.**

Complexity is justified only when a particular mechanic is itself the reason the hero exists.

---

# 3. The Weaponball Rule

Because nobody is manually aiming abilities, **uncertainty is desirable.**

Projectiles should not simply become guaranteed damage because an AI decided to cast them.

Projectile success can depend on:

| Factor | Effect |
|---|---|
| Projectile speed | Faster projectiles are harder to dodge |
| Range | Long-distance shots are less reliable |
| Target movement | Fast/mobile heroes evade more |
| Attacker tendencies | Some heroes fire recklessly, patiently, etc. |
| Target behavior | Retreating, pursuing, stationary, fighting |
| Area size | Large AoEs naturally have higher reliability |
| Crowd control | Disabled targets become easier to hit |

Thus a hero firing a giant missile becomes a little spectator event:

**Will it actually hit?**

Randomness should be **seed-reproducible** where possible so simulations remain statistically analyzable.

Do not add arbitrary random failure to everything. Randomness should correspond to something spectators can understand.

---

# 4. Hero Data Model

Core combat statistics currently include:

| Statistic | Purpose |
|---|---|
| HP | Survivability |
| Power | Offensive scaling |
| Armor | Physical/general durability as defined |
| Resolve | Secondary defensive/resistance stat |
| Attack Speed | Basic attack frequency |
| Ability Speed | Ability cadence |
| Range | Preferred/basic combat distance |
| Move Speed | Movement |
| Stability | Resistance to disruption / combat stability |
| Size | Physical footprint |
| Ultimate Timer | Base cooldown before the ultimate can be used again |

Heroes also have **1–5 behavioral/macro ratings**:

| Rating | Meaning |
|---|---|
| Natural Retreat | Likelihood/quality of disengaging |
| Pursuit | Willingness/ability to chase |
| Roaming | Tendency to leave lane and rotate |
| Dueling | Strength/behavior in isolated combat |
| Waveclear | Ability to remove creeps |
| Siege | Structure pressure |
| Protection | Ability/tendency to save or defend allies |

These are primarily **AI heuristics**, not hidden direct damage bonuses.

Behavior should matter as much as raw combat stats. Two heroes with similar numbers can produce very different match histories because one chases everything while another retreats intelligently.

---

# 5. Leveling and Scaling

Heroes have:

# **13 total levels**

The intended range is:

**Level 1 → Level 13**

Heroes gain XP primarily through the evolving battlefield, especially creep deaths and other relevant combat participation.

Thirteen levels should be enough to create distinct early, middle, and late-game phases without requiring a very long match.

A rough conceptual pacing could look like:

| Levels | Match identity |
|---|---|
| 1–4 | Early game |
| 5–8 | Mid game |
| 9–12 | Late game |
| 13 | Maximum development |

These brackets are descriptive rather than hard mechanical phases unless later formalized.

Scaling has two layers:

### Normal stat scaling

Regular level-based changes to HP, Power, Armor, etc.

A basic data representation might include values such as:

- `hp_base`
- `hp_per_level`
- `power_base`
- `power_per_level`
- `armor_base`
- `armor_per_level`

Maximum-level values should therefore be predictable from the same hero data.

### Character-specific breakpoints

Certain heroes or items can visibly change at particular levels.

Examples:

- Level 5: ability improvement
- Level 9: major scaling breakpoint
- Level 13: final form / maximum scaling state

These exact levels are illustrative rather than universal.

Prefer readable discrete changes over dozens of tiny invisible bonuses where possible.

This principle also applies to item evolution.

---

# 6. Ultimate System

Ultimates **do not use a charge meter or ultimate-point resource.**

Instead:

# **Ultimates operate on long cooldown timers.**

When an ultimate is used, it becomes unavailable for a substantial period.

Example:

**Ultimate used → 90-second timer begins → ultimate becomes available again**

The exact timer varies by hero.

This produces several desirable effects:

- ultimates remain rare enough to feel important
- spectators can anticipate when a major ability might return
- heroes cannot rapidly chain ultimates through arbitrary charge generation
- balance becomes easier to interpret statistically
- an ultimate's frequency can be tuned directly through its cooldown

The timer should generally be **much longer than ordinary ability cooldowns.**

Hero data should therefore contain something like:

`ultimate_cooldown`

rather than:

`ultimate_cost`

or:

`ultimate_charge`

Possible ultimate cooldowns might range approximately from **45–150+ seconds**, depending on impact, although exact values remain a balance question.

### Ultimate AI

An available ultimate should not necessarily be fired immediately.

AI may consider:

- number of nearby enemies
- target HP
- ally danger
- duel importance
- structure pressure
- likelihood of hitting
- hero personality
- whether the fight is already effectively won or lost

Thus two heroes with the same ultimate timer may actually use their ultimates at very different frequencies.

### Cooldown tracking

Event logs should record:

- ultimate cast time
- cooldown duration
- next availability time
- whether the hero died during the cooldown
- time spent holding an available ultimate before use

That last statistic is especially interesting for evaluating hero behavior.

---

# 7. New / Revised Heroes

## Hazmat

**Identity:** chemical-warfare specialist, elite chemist, physically imposing megalomaniac.

Hazmat should not feel like a fragile scientist standing behind gadgets.

He is a **goated chemist who is also extremely physical.**

His fighting should combine chemical weapons with direct aggression and durability.

Existing Hazmat concepts worth preserving include gas/chemical area pressure, self-sustain or injection effects, and willingness to physically force himself into fights.

For hero//vault, simplify rather than importing an entire player-controlled action-game kit.

### Design direction

| Keep | Avoid |
|---|---|
| Chemical AoE pressure | Five different chemical resources |
| Physical brutality | Complicated potion menus |
| Durability/sustain | Excessive bespoke meters |
| Megalomaniacal aggression | Micromanagement mechanics |
| Strong visual battlefield presence | Making him merely a ranged caster |

Hazmat should produce very recognizable match events.

---

## Irene

Irene should be **simple.**

Her appeal is specifically her unusual forms of **lifesteal / stealing health**.

Do not bury that underneath an additional bespoke mechanic.

Her simulation identity should be immediately understandable:

**Irene hurts people and somehow turns that violence into staying alive.**

Different forms or triggers of lifesteal can provide enough texture by themselves.

She does not need a complicated resource engine.

---

## Oddity

Oddity is a circus-associated character whose psychology is important to his AI identity.

He has essentially **no intuitive moral framework**, but he genuinely cares about the circus.

Because Irene also likes/cares about the circus, Oddity consequently likes Irene.

That relationship logic is more interesting than simply labeling him “evil.”

His previously proposed ultimate direction was strong and should remain a centerpiece rather than padding the kit with extra abilities.

Two additional ideas discussed as promising directions:

### Teleportation

Fits his strange, slippery identity and gives the simulation dramatic repositioning events.

### Ultimate copying

A possible defining Oddity mechanic.

If used, copying should interact with the **timer-based ultimate system**, not create an ultimate-charge resource.

Possible implementations include:

- copy the last enemy ultimate witnessed
- copy an enemy ultimate but inherit a long cooldown
- temporarily replace Oddity's own ultimate until cast
- copy with altered power but a standardized cooldown

If used, this mechanic should replace other complexity rather than being piled on top of it.

Oddity is one of the heroes who can justify a strange signature mechanic, but the rest of the kit should become simpler around it.

---

## Mexai

The **theft mechanic** is the key idea worth retaining.

Mexai is also extremely, almost catastrophically, **impulsive**.

Her AI should communicate that directly.

She should produce situations where spectators can recognize:

> Of course Mexai tried that.

Her theft should generate visible swings and stories rather than requiring a complicated player-facing subsystem.

Impulsiveness should meaningfully affect target selection, pursuit, risk assessment, or the timing of theft attempts.

Do not “fix” her into optimal rational play. Her personality is part of her statistical profile.

---

## Eleanor

Eleanor should also be **simplified substantially**.

She does not need a large collection of special mechanics merely because other heroes have them.

Focus on a very small number of actions that establish her battlefield role and personality.

Exact final kit remains open.

---

## Yellow Colony

Yellow Colony has one deliberately unusual scaling rule:

# **Size increases with level.**

Because heroes have exactly **13 levels**, Yellow Colony's growth can be mapped cleanly to level progression.

This is funny, visually obvious, and statistically interesting, which makes it extremely appropriate for hero//vault.

Instead of only watching numbers rise, spectators physically see the colony become increasingly enormous.

Possible implementation:

- gradual scaling across Levels 1–13
- distinct visual jumps at selected levels
- or a combination of both

Potential gameplay consequences of Size include:

| Consequence | Status |
|---|---|
| Larger collision footprint | Candidate |
| More body-blocking | Candidate |
| Larger area coverage | Candidate |
| Easier targetability | Candidate |
| Larger effective threat presence | Candidate |

The exact mechanical consequences are not settled.

The important canonical point is:

**Yellow Colony uniquely scales physical Size with level.**

---

## Tank Carry Superhero

A new archetype discussed was a **superhero tank who eventually becomes a carry/win condition.**

The character should be capable of surviving frontline pressure while eventually providing major damage and/or siege pressure.

The important balancing rule:

**The hero cannot simply begin the match as both an excellent tank and an excellent carry.**

The 13-level structure provides a natural solution.

For example:

- Levels 1–4: primarily durable
- Levels 5–8: begins threatening damage
- Levels 9–12: legitimate carry
- Level 13: maximum power state

They must pay for the combination through scaling, team investment, expensive items, or another meaningful limitation.

Exact name and finalized kit remain TBD.

---

# 8. Roster Philosophy

The overall roster should cover a broad moral spectrum.

Do not divide characters into clean “heroes” and “villains.”

Include:

**genuinely valiant people → flawed but decent characters → morally strange characters → selfish opportunists → dangerous villains → outright monsters**

Characters like Oddity demonstrate why personality should sometimes be represented through specific attachments and behaviors rather than a single morality number.

---

# 9. Item System

Teams have a shared:

# **18-point total item budget**

This makes item cost a strategic composition resource rather than merely an individual inventory limitation.

An expensive item should prevent the team from taking several other useful tools.

Useful item categories currently include:

| Category | Purpose |
|---|---|
| Static | Always provides its effect |
| Evolving | Changes into a stronger item |
| Triggered | Activates under defined circumstances |
| Team Utility | Alters team behavior or capabilities |
| Gank | Enables rotations/ambushes |
| Anti-Gank | Protects against sudden aggression |

---

# 10. Item Evolution Rework

The original concept of items gradually accumulating tiny stat bonuses was rejected.

Items should instead evolve in **bursts**.

Example structure:

**Item A → threshold reached → Item B**

The item remains recognizable and stable, then suddenly becomes a stronger named version.

Potential evolution conditions include:

| Trigger | Example question |
|---|---|
| Creep deaths | Has enough farming occurred? |
| Hero level | Did the carrier reach a breakpoint? |
| Takedowns | Did aggression accelerate the item? |
| Damage blocked | Did defensive play earn evolution? |
| Value enabled | Did utility usage matter? |
| Match phase | Does it awaken naturally later? |

Because heroes cap at **Level 13**, level-triggered evolutions should reference that finite scale.

Examples:

- evolves at Level 5
- evolves at Level 9
- evolves at Level 13

Evolution should be visible and announced.

This produces a discrete spectator event rather than hidden spreadsheet sludge.

---

# 11. Gank Items

## Invisible Cloak

**Purpose:** enable a gank.

Allows a ganking ally to become invisible to enemies for several seconds.

Important simulation rule:

The hero does **not disappear from the simulator itself.**

Instead, enemy AI temporarily loses perception of them.

Reveal logic should be explicitly defined for events such as:

- attacking
- proximity
- taking/dealing damage
- entering structure detection
- detection effects

The interesting statistical question is whether improving approach reliability produces enough successful ganks to justify the item cost.

---

# 12. Anti-Gank Items

## Ambush Shield

When a hero is ganked or takes sudden burst damage, they receive a brief overshield.

“Sudden burst” must be deterministic enough for simulation.

For example:

**X% of max HP lost within Y seconds → shield triggers**

Both X and Y should be tunable data values.

This gives the item an obvious statistical question:

**How many deaths does burst protection actually prevent?**

---

# 13. Provisional 1-Cost Items

These were proposed as deliberately modest tools because one point out of eighteen should not rewrite the game.

| Item | Effect | Status |
|---|---|---|
| **Lane Rations** | Small recovery after avoiding hero damage for a short period | Provisional |
| **Scout Pin** | Periodically improves confidence about nearby unseen threats | Provisional |
| **Tempered Sole** | Brief movement-speed boost when beginning a natural retreat | Provisional |

These names/effects are not as locked as Invisible Cloak or Ambush Shield.

---

# 14. New Item Design Rule

New items should generally satisfy at least one of two criteria:

### A. Ask an interesting statistical question

Examples:

“Does this actually prevent deaths?”

“Who benefits most from this?”

“Does this increase successful ganks enough to justify its cost?”

“Does this change win rate only because one specific archetype abuses it?”

### B. Be fun to watch

An item can also justify itself because its presence produces memorable match events.

Prefer **self-explanatory names** wherever possible.

The viewer should not need a paragraph of lore to understand what just happened.

---

# 15. Blood Crown / Jungle Super-Item

A major spectator-object concept:

## Blood Crown

A powerful pickup appears in the jungle.

**Carrier deals approximately 2× damage.**

The carrier should be visibly marked.

When the carrier dies:

**the Blood Crown drops onto the battlefield.**

Any appropriate hero, including an enemy, can then take it.

The object persists until claimed rather than vanishing immediately.

This creates a match-long mini-narrative:

**spawn → claimant → killing spree → carrier death → scramble → new claimant**

It is deliberately somewhat outrageous.

The important value is not perfectly smooth balance. It is that spectators instantly understand why everyone suddenly cares about one death.

---

# 16. Spectator Objects and Match Toys

A larger pool of simple match objects/events can make hero//vault feel more like Weapon Balls / OC Ball Lab.

Candidate concepts include:

**Golden Creeps, Loose Health Pack, Bomb, Loaded Dice, Cursed Coin, Boots on the Ground, Shrine of Violence, Mystery Crate, Death Gift, Orb, Hot Potato, Rally Flag, Hero Bounty Bag, Meteor Warning, Treasure Goblin, Cooldown Shard, Bell.**

These are **idea-pool concepts, not all canonical systems.**

The previous concept of a **Dropped Ultimate Charge** should no longer be used because ultimates do not have charge meters.

If an ultimate-related pickup exists, it should instead affect the timer.

For example:

### Cooldown Shard

Reduces the remaining ultimate cooldown by a fixed number of seconds.

This preserves the same fun world-object concept while remaining compatible with the timer system.

A possible approach is to maintain a larger pool and activate only a few objects in any individual match.

For example:

**roughly 3 active object types from a pool of 20.**

The exact number remains experimental.

The underlying rule matters more than the exact objects:

**persistent named things create stories.**

A temporary +12% modifier buried in combat math does not.

A crown lying on the jungle floor absolutely does.

---

# 17. Match History Should Remember Objects

Important objects should maintain history.

For example, Blood Crown data could record:

| Field | Example |
|---|---|
| Spawn time | 08:14 |
| First claimant | Hazmat |
| Kills while held | 4 |
| Time held | 91 sec |
| Dropped by | Irene killing Hazmat |
| Second claimant | Irene |

This lets both the UI and later R analysis reconstruct match narratives.

---

# 18. Gank Simulation Philosophy

Ganking should not merely mean:

**AI randomly leaves lane and attacks someone.**

Gank decisions should consider things like target vulnerability, distance, missing information, likely assistance, hero roaming tendency, and opportunity cost.

Likewise, failed ganks should cost something measurable:

**lost XP, lost wave control, lost structure pressure, wasted time, or exposure elsewhere.**

Anti-gank behavior should include threat recognition, retreat tendency, protective allies, and item triggers.

---

# 19. Data / Spreadsheet Structure

The game should remain highly data-driven.

Useful normalized tables include:

| Table | Contains |
|---|---|
| Heroes | Identity, tags, behavior |
| Hero Stats | Base combat values |
| Scaling | Level 1–13 growth / breakpoints |
| Abilities | Targeting, effects, cooldowns |
| Ultimates | Ultimate effect and long cooldown |
| Items | Cost, type, triggers |
| Item Evolutions | Threshold → evolved item |
| Match Events | Everything important that occurs |

Hero configuration should explicitly support:

`max_level = 13`

Ultimate configuration should explicitly support:

`ultimate_cooldown`

and should **not** require:

`ultimate_charge`

or:

`ultimate_cost`

Validation should catch things like:

- duplicate IDs
- hero levels outside 1–13
- macro ratings outside 1–5
- item loadouts exceeding 18 points
- missing evolution targets
- impossible ability targets
- undefined statuses
- invalid ultimate cooldowns

---

# 20. Event Logging

The simulation should produce a rich event log.

Important fields include:

| Field | Purpose |
|---|---|
| Match ID | Identify simulation |
| Time | Sequence events |
| Event Type | Kill, cast, hit, pickup, etc. |
| Actor | Who caused it |
| Target | Who received it |
| Ability | Relevant skill |
| Item | Relevant item |
| Value | Damage/heal/etc. |
| Position | Map location |
| Reason Code | Why the AI acted |

Ultimate-specific events should include:

- `ultimate_cast`
- `ultimate_available`
- remaining cooldown where relevant

This should be exportable to formats usable by R, particularly CSV initially and potentially Parquet later.

---

# 21. Statistics Worth Supporting

The eventual analysis layer should make it easy to examine:

| Analysis | Example |
|---|---|
| Hero win rate | Overall / composition-adjusted |
| Level curves | Performance from Level 1 through Level 13 |
| Item performance | Win rate/value per cost |
| Item evolution | How often and when upgrades happen |
| Gank value | Success vs opportunity cost |
| Matchups | Hero-vs-hero outcomes |
| Role fulfillment | Actual waveclear, protection, siege, etc. |
| Accuracy | Projectile attempts vs hits |
| Survivability | Damage received before death |
| Object history | Blood Crown possession/value |
| Behavioral effects | Pursuit/retreat/roaming outcomes |
| Ultimate frequency | Casts per match |
| Ultimate efficiency | Value generated per cast |
| Ultimate restraint | Time held while available |
| Cooldown waste | Time spent dead while ultimate cooldown runs |

A major goal is being able to discover unexpected relationships rather than simply verify intended balance.

---

# 22. Astra Implementation Priorities

| Priority | Work |
|---|---|
| **1** | Keep hero definitions entirely data-driven |
| **2** | Build reliable autonomous combat and movement |
| **3** | Implement behavioral ratings and decision heuristics |
| **4** | Support hit/miss uncertainty for projectiles |
| **5** | Implement XP and exactly 13 hero levels |
| **6** | Implement normal scaling and level breakpoints |
| **7** | Implement long-timer ultimates |
| **8** | Implement the 18-point item budget |
| **9** | Support static, triggered, and burst-evolving items |
| **10** | Implement gank perception and anti-gank reactions |
| **11** | Add persistent world objects such as Blood Crown |
| **12** | Produce exhaustive structured event logs |
| **13** | Build spectator UI around stories rather than raw simulation internals |
| **14** | Feed results into R for statistical analysis |

---

# 23. Things Astra Should Explicitly Avoid

Do not assume hero//vault is supposed to simulate a conventional mechanically controlled MOBA.

Do not design abilities around what would feel satisfying to manually press.

Do not give every hero four normal skills, a passive, a resource system, and an ultimate merely because MOBAs traditionally do so.

Do not build an ultimate-charge resource.

Do not make ultimates depend on damage dealt, kills, or arbitrary charge accumulation unless a specific hero explicitly breaks the global rule.

Do not resolve every attack automatically.

Do not turn macro ratings directly into arbitrary percentage bonuses.

Do not make item evolution a continuous +0.2-stat-per-creep treadmill.

Do not hide the most entertaining systems in invisible calculations.

Do not make every hero equally rational.

Do not over-balance spectacle out of the game.

The guiding question should repeatedly be:

# **“Would this create an interesting thing to watch or an interesting thing to measure?”**

If neither answer is yes, it probably does not belong in hero//vault yet.

---

# Current Canon / Confidence Snapshot

| Feature | Confidence |
|---|---|
| Autonomous MOBA statistics simulator | **Core** |
| Weaponball-style spectator emphasis | **Core** |
| Simpler hero kits | **Core** |
| Personality expressed through AI behavior | **Core** |
| 1–5 macro ratings | **Core** |
| **13 hero levels** | **Core** |
| XP-driven leveling | **Core** |
| **Ultimates use long cooldown timers, not charge** | **Core** |
| 18-point shared item budget | **Core** |
| Burst item evolution | **Core** |
| Projectile whiffs / outcome uncertainty | **Strong direction** |
| Yellow Colony grows in Size | **Core character gimmick** |
| Hazmat = chemist + physical bruiser | **Strong character direction** |
| Irene = straightforward lifesteal identity | **Strong character direction** |
| Mexai theft | **Strong character direction** |
| Mexai extreme impulsivity | **Core personality direction** |
| Oddity circus loyalty | **Core personality direction** |
| Oddity teleport | **Candidate** |
| Oddity ultimate-copy mechanic | **Candidate** |
| Eleanor simplified | **Direction established, kit TBD** |
| Tank Carry superhero | **Archetype established, details TBD** |
| Invisible Cloak | **Established prototype item** |
| Ambush Shield | **Established prototype item** |
| Lane Rations / Scout Pin / Tempered Sole | **Provisional** |
| Blood Crown | **Strong spectator-system concept** |
| Larger rotating object pool | **Exploratory** |
| Exact ultimate timers | **TBD** |
| Exact damage formulas | **TBD** |
| Exact map architecture | **TBD** |
| Exact team size | **TBD** |
| Exact ability roster for several new heroes | **TBD** |

## One-Sentence North Star

**hero//vault is a data-driven superhero terrarium where autonomous characters develop across 13 levels and collide using distinct statistics, personalities, abilities, long-timer ultimates, and items, producing both analyzable statistics and tiny emergent sports narratives.**