extends RefCounted
## Hero, item and rival data. Simulation rules live in battle.gd / hero_kits.gd.
## IDs are stable save/CSV keys; change display names instead of IDs.

const MAX_LEVEL := 13
const XP_PER_LEVEL := 6
const TEAM_SIZE := 5
const ITEM_BUDGET := 18

# Behavior ratings (1-5) are AI heuristics, never hidden damage bonuses.
const BEHAVIOR_KEYS := ["retreat", "pursuit", "roaming", "dueling", "waveclear", "siege", "protection"]
const PROFILES := {
	"hazmat": [1, 4, 2, 5, 4, 2, 2],
	"irene": [4, 4, 3, 5, 3, 2, 1],
	"oddity": [3, 2, 4, 2, 3, 3, 1],
	"mexai": [5, 4, 5, 3, 2, 2, 1],
	"eleanor": [3, 2, 2, 3, 3, 2, 5],
	"colony": [2, 3, 2, 3, 5, 4, 3],
	"poppet": [4, 3, 3, 3, 2, 2, 2],
	"crash_test": [1, 5, 3, 4, 2, 3, 2],
	"kiln": [2, 2, 1, 2, 5, 5, 2],
	"sunday": [4, 1, 2, 1, 2, 2, 5],
}

# Per-level growth: [max HP, basic damage].
const GROWTH := {
	"hazmat": [32, 3],
	"irene": [25, 3],
	"oddity": [24, 2],
	"mexai": [23, 3],
	"eleanor": [28, 2],
	"colony": [30, 3],
	"poppet": [22, 3],
	"crash_test": [34, 3],
	"kiln": [28, 3],
	"sunday": [24, 2],
}

# Ultimates run on long timers (seconds). There is no charge resource.
const ULTIMATES := {
	"hazmat": {"id": "OVERPRESSURE", "cooldown": 90.0, "windup": 1.0, "damage": 95.0, "per_level": 8.0},
	"irene": {"id": "Blood Rush", "cooldown": 75.0, "windup": 0.5, "damage": 0.0, "per_level": 0.0},
	"oddity": {"id": "INTERMISSION", "cooldown": 120.0, "windup": 1.5, "damage": 0.0, "per_level": 0.0},
	"mexai": {"id": "Grand Larceny", "cooldown": 80.0, "windup": 0.6, "damage": 45.0, "per_level": 4.0},
	"eleanor": {"id": "Hold the Line", "cooldown": 100.0, "windup": 1.0, "damage": 0.0, "per_level": 0.0},
	"colony": {"id": "All Together", "cooldown": 100.0, "windup": 1.3, "damage": 110.0, "per_level": 8.0},
	"poppet": {"id": "Pincushion", "cooldown": 85.0, "windup": 0.7, "damage": 38.0, "per_level": 4.0},
	"crash_test": {"id": "Total Write-Off", "cooldown": 95.0, "windup": 0.4, "damage": 60.0, "per_level": 6.0},
	"kiln": {"id": "Open the Door", "cooldown": 100.0, "windup": 1.2, "damage": 90.0, "per_level": 7.0},
	"sunday": {"id": "Sunday Best", "cooldown": 90.0, "windup": 0.8, "damage": 0.0, "per_level": 0.0},
}

const HERO_IDS := ["hazmat", "irene", "oddity", "mexai", "eleanor", "colony", "poppet", "crash_test", "kiln", "sunday"]

const HEROES := {
	"hazmat": {"name": "Hazmat", "category": "Other", "role": "Juggernaut / Attrition tank", "personality": "Megalomaniacal / Physical",
		"hp": 680, "damage": 58, "reach": 52, "speed": 39, "armor": 24.0, "resolve": 45.0, "interval": 1.9, "windup": 0.45, "projectile": 0.0,
		"kit": "Heavy Hands / Red Gas / OVERPRESSURE",
		"description": "Heavy melee stagger. Moving red gas damages nearby enemies and reduces healing. OVERPRESSURE expands the gas, adds Resolve and heals from gas damage."},
	"irene": {"name": "Irene", "category": "Circus", "role": "Evasive carry / Duelist", "personality": "Playful / Relentless",
		"hp": 390, "damage": 23, "reach": 175, "speed": 59, "armor": 8.0, "resolve": 8.0, "interval": 0.65, "windup": 0.0, "projectile": 560.0,
		"kit": "Juggling Knives / Leeching Cut / Blood Rush",
		"description": "Fast knives lifesteal. Leeching Cut dashes and temporarily steals maximum HP. Blood Rush boosts attack/move speed, lifesteal, and redirects healing from marked enemies."},
	"oddity": {"name": "Oddity", "category": "Circus", "role": "Controller / Utility god", "personality": "Amoral / Unpredictable",
		"hp": 430, "damage": 26, "reach": 210, "speed": 49, "armor": 15.0, "resolve": 28.0, "interval": 1.1, "windup": 0.0, "projectile": 300.0,
		"kit": "Confetti / Now You See Me / Encore! / INTERMISSION",
		"description": "Teleports for strange positioning. Encore stores a nearby ultimate for a weaker copy on its own long timer. INTERMISSION freezes combat and rearranges nearby enemies. Does not protect Irene."},
	"mexai": {"name": "Mexai", "category": "Fantasy", "role": "Roamer / Item thief", "personality": "Impulsive / Opportunistic",
		"hp": 355, "damage": 21, "reach": 48, "speed": 62, "armor": 7.0, "resolve": 7.0, "interval": 0.7, "windup": 0.12, "projectile": 0.0,
		"kit": "Shiv / Pilfer / Grand Larceny",
		"description": "Fast melee. Pilfer temporarily takes an equipped item and disables it on its owner. Grand Larceny dashes between nearby enemies to damage and steal. Chases valuables but flees danger quickly."},
	"eleanor": {"name": "Eleanor", "category": "Fantasy", "role": "Protector tank", "personality": "Stern / Protective",
		"hp": 720, "damage": 48, "reach": 62, "speed": 39, "armor": 40.0, "resolve": 30.0, "interval": 2.1, "windup": 0.6, "projectile": 0.0,
		"kit": "Greatsword / Intercede / Hold the Line",
		"description": "Broad melee swings. Intercede rushes to a wounded ally, shields and pushes enemies away. Hold the Line greatly raises defenses and absorbs nearby ally damage while slowing Eleanor."},
	"colony": {"name": "Yellow Colony", "category": "Other", "role": "Growing frontline", "personality": "Collective / Persistent",
		"hp": 570, "damage": 28, "reach": 68, "speed": 39, "armor": 20.0, "resolve": 16.0, "interval": 1.4, "windup": 0.3, "projectile": 0.0,
		"kit": "Swarm / Colony Surge / All Together",
		"description": "Melee swarm and nearby area slam. Physical size grows through 13 levels. All Together is a larger slam and personal shield."},
	"poppet": {"name": "Poppet", "category": "Objects given life", "role": "Hex marksman", "personality": "Spiteful / Patient",
		"hp": 380, "damage": 24, "reach": 190, "speed": 50, "armor": 10.0, "resolve": 22.0, "interval": 0.95, "windup": 0.0, "projectile": 620.0,
		"kit": "Needle / Stitch / Pincushion",
		"description": "Fast needle shots. Stitch binds an enemy hero for 5s: 35% of the damage Poppet takes is also dealt to them. Pincushion throws a dodgeable fan of five needles."},
	"crash_test": {"name": "Crash Test", "category": "Objects given life", "role": "Reckless initiator", "personality": "Fearless / Oblivious",
		"hp": 640, "damage": 44, "reach": 50, "speed": 46, "armor": 32.0, "resolve": 18.0, "interval": 1.5, "windup": 0.3, "projectile": 0.0,
		"kit": "Bumper / Impact Test / Total Write-Off",
		"description": "Impact Test charges in a straight line: the first enemy hero hit is damaged and stunned; a whiff leaves Crash Test dazed. Total Write-Off adds a shield for 8s, then explodes for extra damage based on everything it absorbed. Also explodes if destroyed early."},
	"kiln": {"name": "Kiln", "category": "Objects given life", "role": "Zone control / Siege", "personality": "Slow-burning / Stubborn",
		"hp": 600, "damage": 36, "reach": 150, "speed": 36, "armor": 28.0, "resolve": 30.0, "interval": 1.6, "windup": 0.0, "projectile": 240.0,
		"kit": "Ember Lob / Firing / Open the Door",
		"description": "Slow, dodgeable ember lobs. Firing leaves a burning patch where an enemy stands. Open the Door blasts a wide area and leaves a large fire. Deals +50% damage to towers and vaults."},
	"sunday": {"name": "Sunday", "category": "Other", "role": "Restorative support", "personality": "Serene / Unhurried",
		"hp": 400, "damage": 18, "reach": 200, "speed": 47, "armor": 10.0, "resolve": 20.0, "interval": 1.1, "windup": 0.0, "projectile": 450.0,
		"kit": "Sunbeam / Day of Rest / Sunday Best",
		"description": "Day of Rest instantly heals the most wounded nearby ally (or herself). Sunday Best gives nearby allies 25% max-HP healing over 5s and +20% movement. Prefers to stay back."},
}

# Evolving items change into a stronger named version once, at a visible threshold.
# trigger: level (holder level), procs (item activations), kills (hero kills while held),
# blocked (damage prevented), retreats (retreat boosts used).
const ITEM_IDS := ["none", "last_stand", "execution", "first_hit", "revenge", "kill_crown", "coward", "bodyguard", "glass", "coin",
	"ambush", "cloak", "rations", "scout", "sole"]
const EVOLVE_TRIGGERS := ["level", "procs", "kills", "blocked", "retreats"]

const ITEMS := {
	"none": {"name": "Empty", "cost": 0, "description": "Leave this slot empty."},
	"last_stand": {"name": "Last Stand Shield", "cost": 2,
		"description": "Below 25% HP, gain a shield worth 35% maximum HP for 5 seconds. Once per life; lethal hits cannot trigger it after death."},
	"execution": {"name": "Execution Blade", "cost": 3,
		"description": "Deal 60% more damage to enemy heroes already below 20% HP.",
		"evolve": {"name": "Headsman's Axe", "trigger": "kills", "at": 3, "summary": "Execute threshold rises to 30% HP."}},
	"first_hit": {"name": "First Hit Hammer", "cost": 2,
		"description": "First basic hit against each enemy hero deals +60 damage. Refreshes after 8 seconds without exchanging damage with that hero.",
		"evolve": {"name": "Opening Sledge", "trigger": "procs", "at": 5, "summary": "+100 first-hit damage and a 0.4s stagger."}},
	"revenge": {"name": "Revenge Armor", "cost": 2,
		"description": "After an enemy hero kills you, gain +40 Armor and Resolve against that specific hero until you kill them. Rivalries survive respawn."},
	"kill_crown": {"name": "Kill Streak Crown", "cost": 3,
		"description": "Gain +8 Power per consecutive hero kill. All stacks are lost on death. Separate from the jungle Idol."},
	"coward": {"name": "Coward's Boots", "cost": 1,
		"description": "Below 30% HP, gain 50% movement speed while moving away from the nearest visible enemy hero within 240 range."},
	"bodyguard": {"name": "Bodyguard Vest", "cost": 2,
		"description": "Take 25% less damage while within 120 range of a living allied hero with lower current HP than you.",
		"evolve": {"name": "Shield Wall Vest", "trigger": "blocked", "at": 400, "summary": "Damage reduction rises to 35%."}},
	"glass": {"name": "Glass Cannon", "cost": 2,
		"description": "+25 Power, -25 Armor and Resolve. Negative defenses increase damage taken."},
	"coin": {"name": "Lucky Coin", "cost": 1,
		"description": "Basic attacks have a seeded 8% chance to deal triple damage. Rolls on a connected hit, once per swing.",
		"evolve": {"name": "Two-Headed Coin", "trigger": "level", "at": 13, "summary": "Triple-damage chance rises to 14%."}},
	"ambush": {"name": "Ambush Shield", "cost": 2,
		"description": "Losing 30% maximum HP within 2 seconds grants a shield worth 30% maximum HP for 3 seconds. 20s cooldown."},
	"cloak": {"name": "Invisible Cloak", "cost": 3,
		"description": "When starting a jungle rotation or closing in on a distant enemy hero, become unseen by enemies for 6s. Attacking, taking damage, or coming within 60 range of an enemy hero reveals you. 30s cooldown."},
	"rations": {"name": "Lane Rations", "cost": 1,
		"description": "After 6s without taking hero damage, recover 4 HP per second (+0.4 per level).",
		"evolve": {"name": "Hearty Rations", "trigger": "level", "at": 9, "summary": "Starts after 4s and heals twice as fast."}},
	"scout": {"name": "Scout Pin", "cost": 1,
		"description": "Checks for hidden enemy heroes within 260 range and reveals them. 10s cooldown after a reveal."},
	"sole": {"name": "Tempered Sole", "cost": 1,
		"description": "When beginning a natural retreat, gain 40% movement speed for 2.5s. 12s cooldown.",
		"evolve": {"name": "Tempered Greaves", "trigger": "retreats", "at": 4, "summary": "The boost lasts 4s and gives 55% movement speed."}},
}

const DEFAULT_TEAM := ["hazmat", "irene", "eleanor", "colony", "mexai"]
const DEFAULT_ITEMS := [["last_stand", "revenge"], ["execution", "coin"], ["bodyguard", "last_stand"], ["first_hit", "none"], ["glass", "coward"]]

const RIVAL_TEAMS := [
	["hazmat", "irene", "eleanor", "colony", "oddity"],
	["crash_test", "hazmat", "mexai", "sunday", "irene"],
	["kiln", "poppet", "irene", "oddity", "mexai"],
]
const RIVAL_ITEMS := [
	[["last_stand", "revenge"], ["execution", "coin"], ["bodyguard", "last_stand"], ["first_hit", "none"], ["glass", "coward"]],
	[["last_stand", "glass"], ["first_hit", "revenge"], ["coward", "coin"], ["bodyguard", "rations"], ["execution", "none"]],
	[["execution", "coin"], ["revenge", "last_stand"], ["kill_crown", "none"], ["scout", "ambush"], ["cloak", "coward"]],
]

static func budget(loadout: Array) -> int:
	var total := 0
	for slots in loadout:
		if slots is Array:
			for item in slots:
				if ITEMS.has(item):
					total += ITEMS[item].cost
	return total

static func validate(team: Array, loadout: Array) -> String:
	if team.size() != TEAM_SIZE or loadout.size() != TEAM_SIZE:
		return "Choose five heroes and five item rows."
	var seen := []
	for i in range(TEAM_SIZE):
		if not HEROES.has(team[i]) or team[i] in seen:
			return "Each hero can appear only once in your squad."
		seen.append(team[i])
		if not loadout[i] is Array or loadout[i].size() != 2:
			return "Each hero has two item slots."
		for item in loadout[i]:
			if not ITEMS.has(item):
				return "Unknown item."
		if loadout[i][0] != "none" and loadout[i][0] == loadout[i][1]:
			return "A hero cannot equip the same item twice."
	if budget(loadout) > ITEM_BUDGET:
		return "Over budget: %d / %d points. Remove or replace an item." % [budget(loadout), ITEM_BUDGET]
	return ""

## Keeps a saved roster usable after heroes are retired: unknown or duplicate
## IDs are swapped for unused current heroes instead of discarding the squad.
static func migrate_team(saved: Array) -> Array:
	var result: Array = []
	for id in saved:
		result.append(id if HEROES.has(id) and id not in result else "")
	for i in range(result.size()):
		if result[i] == "":
			for id in DEFAULT_TEAM + HERO_IDS:
				if id not in result:
					result[i] = id
					break
	return result

static func enemy_team(rival: int) -> Array:
	return RIVAL_TEAMS[rival].duplicate()

static func enemy_items(rival: int) -> Array:
	return RIVAL_ITEMS[rival].duplicate(true)

static func item_name(id: String, evolved: bool) -> String:
	return ITEMS[id].evolve.name if evolved and ITEMS[id].has("evolve") else ITEMS[id].name

static func item_tooltip(id: String) -> String:
	var data: Dictionary = ITEMS[id]
	if not data.has("evolve"):
		return data.description
	var evolve: Dictionary = data.evolve
	var condition: String = {
		"level": "at hero level %d",
		"procs": "after %d activations",
		"kills": "after %d hero kills while held",
		"blocked": "after preventing %d damage",
		"retreats": "after %d boosted retreats",
	}[evolve.trigger] % evolve.at
	return "%s\nEVOLVES %s into %s: %s" % [data.description, condition, evolve.name, evolve.summary]

static func behavior(id: String) -> Dictionary:
	var result := {}
	for i in range(BEHAVIOR_KEYS.size()):
		result[BEHAVIOR_KEYS[i]] = PROFILES[id][i]
	return result

static func validate_definitions() -> String:
	if HERO_IDS.size() != HEROES.size():
		return "Hero IDs must be unique and complete"
	var seen := []
	for id in HERO_IDS:
		if id in seen or not HEROES.has(id) or not PROFILES.has(id) or not GROWTH.has(id) or not ULTIMATES.has(id):
			return "Missing or duplicate hero data: " + id
		seen.append(id)
		if PROFILES[id].size() != BEHAVIOR_KEYS.size():
			return "Incomplete behavior profile: " + id
		for rating in PROFILES[id]:
			if rating < 1 or rating > 5:
				return "Behavior ratings must be 1-5"
	for id in ULTIMATES:
		if not HEROES.has(id) or ULTIMATES[id].cooldown < 45:
			return "Invalid ultimate cooldown"
	if ITEM_IDS.size() != ITEMS.size():
		return "Item IDs must be unique and complete"
	for id in ITEM_IDS:
		if not ITEMS.has(id):
			return "Missing item data: " + id
		if ITEMS[id].has("evolve"):
			var evolve: Dictionary = ITEMS[id].evolve
			if evolve.trigger not in EVOLVE_TRIGGERS or evolve.at <= 0 or (evolve.trigger == "level" and evolve.at > MAX_LEVEL):
				return "Invalid evolution: " + id
	for rival in range(RIVAL_TEAMS.size()):
		if validate(RIVAL_TEAMS[rival], RIVAL_ITEMS[rival]) != "":
			return "Invalid rival squad %d" % rival
	return ""
