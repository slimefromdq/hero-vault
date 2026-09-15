extends RefCounted
## Current concept roster. Unfinished names and kits are marked provisional.
const MAX_LEVEL := 13
const XP_PER_LEVEL := 6
const TEAM_SIZE := 5
const ITEM_BUDGET := 18
const BEHAVIOR_KEYS := [
		"retreat",
		"pursuit",
		"roaming",
		"dueling",
		"waveclear",
		"siege",
		"protection"
]
const PROFILES := {
 "hazmat": [1,4,2,5,4,2,2], "irene": [4,4,3,5,3,2,1],
 "oddity": [3,2,4,2,3,3,1], "mexai": [5,4,5,3,2,2,1],
 "eleanor": [3,2,2,3,3,2,5], "colony": [2,3,2,3,5,4,3], "atlas": [2,2,2,3,3,4,5]
}

const GROWTH := {
		"hazmat": [
				32,
				3
		],
		"irene": [
				25,
				3
		],
		"oddity": [
				24,
				2
		],
		"mexai": [
				23,
				3
		],
		"eleanor": [
				28,
				2
		],
		"colony": [
				30,
				3
		],
		"atlas": [
				34,
				2
		]
}
const ULTIMATES := {
 "hazmat": {"id":"OVERPRESSURE", "cooldown":90.0, "windup":1.0, "damage":95.0, "per_level":8.0},
 "irene": {"id":"Blood Rush", "cooldown":75.0, "windup":0.5, "damage":0.0, "per_level":0.0},
 "oddity": {"id":"INTERMISSION", "cooldown":120.0, "windup":1.5, "damage":0.0, "per_level":0.0},
 "mexai": {"id":"Grand Larceny", "cooldown":80.0, "windup":0.6, "damage":45.0, "per_level":4.0},
 "eleanor": {"id":"Hold the Line", "cooldown":100.0, "windup":1.0, "damage":0.0, "per_level":0.0},
 "colony": {"id":"All Together", "cooldown":100.0, "windup":1.3, "damage":110.0, "per_level":8.0},
 "atlas": {"id":"Worldbreaker", "cooldown":110.0, "windup":1.5, "damage":105.0, "per_level":8.0}
}

const HERO_IDS := [
		"hazmat",
		"irene",
		"oddity",
		"mexai",
		"eleanor",
		"colony",
		"atlas"
]
const ITEM_IDS := ["none", "last_stand", "execution", "first_hit", "revenge", "kill_crown", "coward", "bodyguard", "glass", "coin"]

const DEFAULT_TEAM := [
		"hazmat",
		"irene",
		"eleanor",
		"colony",
		"mexai"
]
const DEFAULT_ITEMS := [["last_stand","revenge"],["execution","coin"],["bodyguard","last_stand"],["first_hit","none"],["glass","coward"]]

const HEROES := {
 "hazmat": {"name":"Hazmat", "role":"Juggernaut / Attrition tank", "personality":"Megalomaniacal / Physical", "hp":680, "damage":58, "reach":52, "speed":39, "armor":24.0, "resolve":45.0, "interval":1.9, "windup":0.45, "projectile":0.0, "kit":"Heavy Hands / Red Gas / OVERPRESSURE", "description":"Heavy melee stagger. Moving red gas damages nearby enemies and reduces healing. OVERPRESSURE expands the gas, adds Resolve and heals from gas damage."},
 "irene": {"name":"Irene", "role":"Evasive carry / Duelist", "personality":"Playful / Relentless", "hp":390, "damage":23, "reach":175, "speed":59, "armor":8.0, "resolve":8.0, "interval":0.65, "windup":0.0, "projectile":560.0, "kit":"Juggling Knives / Leeching Cut / Blood Rush", "description":"Fast knives lifesteal. Leeching Cut dashes and temporarily steals maximum HP. Blood Rush boosts attack/move speed, lifesteal, and redirects healing from marked enemies."},
 "oddity": {"name":"Oddity", "role":"Controller / Utility god", "personality":"Amoral / Unpredictable", "hp":430, "damage":26, "reach":210, "speed":49, "armor":15.0, "resolve":28.0, "interval":1.1, "windup":0.0, "projectile":300.0, "kit":"Confetti / Now You See Me / Encore! / INTERMISSION", "description":"Teleports for strange positioning. Encore stores a nearby ultimate for a weaker copy on its own long timer. INTERMISSION freezes combat and rearranges nearby enemies. Does not protect Irene."},
 "mexai": {"name":"Mexai", "role":"Roamer / Item thief", "personality":"Impulsive / Opportunistic", "hp":355, "damage":21, "reach":48, "speed":62, "armor":7.0, "resolve":7.0, "interval":0.7, "windup":0.12, "projectile":0.0, "kit":"Shiv / Pilfer / Grand Larceny", "description":"Fast melee. Pilfer temporarily takes an equipped item and disables it on its owner. Grand Larceny dashes between nearby enemies to damage and steal. Chases valuables but flees danger quickly."},
 "eleanor": {"name":"Eleanor", "role":"Protector tank", "personality":"Stern / Protective", "hp":720, "damage":48, "reach":62, "speed":39, "armor":40.0, "resolve":30.0, "interval":2.1, "windup":0.6, "projectile":0.0, "kit":"Greatsword / Intercede / Hold the Line", "description":"Broad melee swings. Intercede rushes to a wounded ally, shields and pushes enemies away. Hold the Line greatly raises defenses and absorbs nearby ally damage while slowing Eleanor."},
 "colony": {"name":"Yellow Colony", "role":"Growing frontline", "personality":"Collective / Persistent", "hp":570, "damage":28, "reach":68, "speed":39, "armor":20.0, "resolve":16.0, "interval":1.4, "windup":0.3, "projectile":0.0, "kit":"Swarm / Colony Surge / All Together", "description":"Melee swarm and nearby area slam. Physical size grows through 13 levels. All Together is a larger slam and personal shield."},
 "atlas": {"name":"Atlas (working name)", "role":"Scaling superhero tank", "personality":"Valiant / Steadfast", "hp":680, "damage":13, "reach":55, "speed":41, "armor":30.0, "resolve":24.0, "interval":1.5, "windup":0.35, "projectile":0.0, "kit":"Heavy Strike / Stand Firm / Worldbreaker", "description":"Melee tank with low early damage. Personal shield and a heavy ultimate shockwave. Damage increases at levels 5, 9 and 13."}
}

const ITEMS := {
 "none": {"name":"Empty", "cost":0, "description":"Leave this slot empty."},
 "last_stand": {"name":"Last Stand Shield", "cost":2, "description":"Below 25% HP, gain a shield worth 35% maximum HP for 5 seconds. Once per life; lethal hits cannot trigger it after death."},
 "execution": {"name":"Execution Blade", "cost":3, "description":"Deal 60% more damage to enemy heroes already below 20% HP."},
 "first_hit": {"name":"First Hit Hammer", "cost":2, "description":"First basic hit against each enemy hero deals +60 damage. Refreshes after 8 seconds without exchanging damage with that hero."},
 "revenge": {"name":"Revenge Armor", "cost":2, "description":"After an enemy hero kills you, gain +40 Armor and Resolve against that specific hero until you kill them. Rivalries survive respawn."},
 "kill_crown": {"name":"Kill Streak Crown", "cost":3, "description":"Gain +8 Power per consecutive hero kill. All stacks are lost on death. Separate from the jungle Idol."},
 "coward": {"name":"Coward's Boots", "cost":1, "description":"Below 30% HP, gain 50% movement speed while moving away from the nearest visible enemy hero within 240 range."},
 "bodyguard": {"name":"Bodyguard Vest", "cost":2, "description":"Take 25% less damage while within 120 range of a living allied hero with lower current HP than you."},
 "glass": {"name":"Glass Cannon", "cost":2, "description":"+25 Power, -25 Armor and Resolve. Negative defenses increase damage taken."},
 "coin": {"name":"Lucky Coin", "cost":1, "description":"Basic attacks have a seeded 8% chance to deal triple damage. Rolls on a connected hit, once per swing."}
}

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
		return "Over budget: %d / 18 points. Remove or replace an item." % budget(loadout)
	return ""

static func enemy_team(rival: int) -> Array:
	return [["hazmat", "irene", "eleanor", "colony", "oddity"], ["atlas", "hazmat", "mexai", "eleanor", "irene"], ["irene", "colony", "atlas", "oddity", "mexai"]][rival].duplicate()

static func enemy_items(rival: int) -> Array:
	return [
	[["last_stand","revenge"],["execution","coin"],["bodyguard","last_stand"],["first_hit","none"],["glass","coward"]],
	[["last_stand","glass"],["first_hit","revenge"],["coward","coin"],["bodyguard","none"],["execution","none"]],
	[["execution","coin"],["revenge","last_stand"],["kill_crown","none"],["glass","none"],["first_hit","coward"]]
	][rival].duplicate(true)

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
		if id in seen or not PROFILES.has(id) or not GROWTH.has(id):
			return "Missing or duplicate hero data"
		seen.append(id)
		if PROFILES[id].size() != BEHAVIOR_KEYS.size():
			return "Incomplete behavior profile"
		for rating in PROFILES[id]:
			if rating < 1 or rating > 5:
				return "Behavior ratings must be 1-5"
	for id in ULTIMATES:
		if not HEROES.has(id) or ULTIMATES[id].cooldown < 45:
			return "Invalid ultimate cooldown"
	return ""
