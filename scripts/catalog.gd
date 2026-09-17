extends RefCounted
## Hero and rival data. Shop items live in shop_catalog.gd. Simulation rules live in battle.gd / hero_kits.gd.
## IDs are stable save/CSV keys; change display names instead of IDs.

const MAX_LEVEL := 13
const XP_PER_LEVEL := 6
const TEAM_SIZE := 5
const ShopCatalog = preload("res://scripts/shop_catalog.gd")

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
	"crash_test": [1, 5, 5, 4, 3, 3, 1],
	"kiln": [2, 2, 1, 2, 5, 5, 2],
	"sunday": [3, 1, 1, 1, 4, 5, 4],
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
	"crash_test": [38, 2],
	"kiln": [28, 3],
	"sunday": [26, 3],
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
	"crash_test": {"id": "CRASH PROGRAM", "cooldown": 95.0, "windup": 0.3, "damage": 35.0, "per_level": 4.0},
	"kiln": {"id": "Open the Door", "cooldown": 100.0, "windup": 1.2, "damage": 90.0, "per_level": 7.0},
	"sunday": {"id": "BEAUTIFUL DAY", "cooldown": 110.0, "windup": 1.0, "damage": 12.0, "per_level": 1.5},
}

const HERO_IDS := ["hazmat", "irene", "oddity", "mexai", "eleanor", "colony", "poppet", "crash_test", "kiln", "sunday"]

const HEROES := {
	"hazmat": {"name": "Hazmat", "category": "Other", "role": "Juggernaut / Attrition tank", "personality": "Megalomaniacal / Physical",
		"hp": 680, "damage": 58, "reach": 52, "speed": 39, "armor": 24.0, "resolve": 45.0, "interval": 1.9, "windup": 0.45, "projectile": 0.0, "stability": 7,
		"kit": "Heavy Hands / Red Gas / OVERPRESSURE",
		"description": "Heavy melee stagger. Moving red gas damages nearby enemies and reduces healing. OVERPRESSURE expands the gas, adds Resolve and heals from gas damage."},
	"irene": {"name": "Irene", "category": "Circus", "role": "Evasive carry / Duelist", "personality": "Playful / Relentless",
		"hp": 390, "damage": 23, "reach": 175, "speed": 59, "armor": 8.0, "resolve": 8.0, "interval": 0.65, "windup": 0.0, "projectile": 560.0, "stability": 3,
		"kit": "Juggling Knives / Leeching Cut / Blood Rush",
		"description": "Fast knives lifesteal. Leeching Cut dashes and temporarily steals maximum HP. Blood Rush boosts attack/move speed, lifesteal, and redirects healing from marked enemies."},
	"oddity": {"name": "Oddity", "category": "Circus", "role": "Controller / Utility god", "personality": "Amoral / Unpredictable",
		"hp": 430, "damage": 26, "reach": 210, "speed": 49, "armor": 15.0, "resolve": 28.0, "interval": 1.1, "windup": 0.0, "projectile": 300.0, "stability": 4,
		"kit": "Confetti / Now You See Me / Encore! / INTERMISSION",
		"description": "Teleports for strange positioning. Encore stores a nearby ultimate for a weaker copy on its own long timer. INTERMISSION freezes combat and rearranges nearby enemies. Does not protect Irene."},
	"mexai": {"name": "Mexai", "category": "Fantasy", "role": "Roamer / Item thief", "personality": "Impulsive / Opportunistic",
		"hp": 355, "damage": 21, "reach": 48, "speed": 62, "armor": 7.0, "resolve": 7.0, "interval": 0.7, "windup": 0.12, "projectile": 0.0, "stability": 2,
		"kit": "Shiv / Pilfer / Grand Larceny",
		"description": "Fast melee. Pilfer temporarily takes a delivered item and disables it on its owner. Grand Larceny dashes between nearby enemies to damage and steal. Chases valuables but flees danger quickly."},
	"eleanor": {"name": "Eleanor", "category": "Fantasy", "role": "Protector tank", "personality": "Stern / Protective",
		"hp": 720, "damage": 48, "reach": 62, "speed": 39, "armor": 40.0, "resolve": 30.0, "interval": 2.1, "windup": 0.6, "projectile": 0.0, "stability": 8,
		"kit": "Greatsword / Intercede / Hold the Line",
		"description": "Broad melee swings. Intercede rushes to a wounded ally, shields and pushes enemies away. Hold the Line greatly raises defenses and absorbs nearby ally damage while slowing Eleanor."},
	"colony": {"name": "Yellow Colony", "category": "Other", "role": "Growing frontline", "personality": "Collective / Persistent",
		"hp": 570, "damage": 28, "reach": 68, "speed": 39, "armor": 20.0, "resolve": 16.0, "interval": 1.4, "windup": 0.3, "projectile": 0.0, "stability": 6,
		"kit": "Swarm / Colony Surge / All Together",
		"description": "Melee swarm and nearby area slam. Physical size grows through 13 levels. All Together is a larger slam and personal shield."},
	"poppet": {"name": "Poppet", "category": "Objects given life", "role": "Hex marksman", "personality": "Spiteful / Patient",
		"hp": 380, "damage": 24, "reach": 190, "speed": 50, "armor": 10.0, "resolve": 22.0, "interval": 0.95, "windup": 0.0, "projectile": 620.0, "stability": 3,
		"kit": "Needle / Stitch / Pincushion",
		"description": "Fast needle shots. Stitch binds an enemy hero for 5s: 35% of the damage Poppet takes is also dealt to them. Pincushion throws a dodgeable fan of five needles."},
	"crash_test": {"name": "Crash Test", "title": "The Human Safety Violation", "category": "Objects given life", "role": "Tank / Disruptor", "personality": "Committed / Oblivious",
		"hp": 780, "damage": 40, "reach": 50, "speed": 45, "armor": 48.0, "resolve": 25.0, "interval": 1.8, "windup": 0.35, "projectile": 0.0, "stability": 1, "size": 21.0,
		"kit": "Impact Test / FULL SEND / SAFETY RATING: ZERO / CRASH PROGRAM",
		"description": "Monstrously durable with the worst Stability in the roster. Clumsy punches knock enemies back. FULL SEND catapults across the map at a distant fight and can land on nobody. SAFETY RATING: ZERO makes them heavy and immovable for a moment. CRASH PROGRAM turns every knockback, landing and wall hit into a shockwave."},
	"kiln": {"name": "Kiln", "category": "Objects given life", "role": "Zone control / Siege", "personality": "Slow-burning / Stubborn",
		"hp": 600, "damage": 36, "reach": 150, "speed": 36, "armor": 28.0, "resolve": 30.0, "interval": 1.6, "windup": 0.0, "projectile": 240.0, "stability": 9,
		"kit": "Ember Lob / Firing / Open the Door",
		"description": "Slow, dodgeable ember lobs. Firing leaves a burning patch where an enemy stands. Open the Door blasts a wide area and leaves a large fire. Deals +50% damage to towers and vaults."},
	"sunday": {"name": "Sunday", "title": "The Daystar Darling", "category": "Other", "role": "Support / Artillery", "personality": "Serene / Helpful",
		"hp": 480, "damage": 40, "reach": 235, "speed": 40, "armor": 14.0, "resolve": 38.0, "interval": 1.8, "windup": 0.0, "projectile": 170.0, "stability": 7,
		"splash": 36.0, "shot_life": 4.0,
		"kit": "Sunbeam / Warmth / Flare / BEAUTIFUL DAY",
		"description": "Slow, heavy Sunbeam bolts with a small splash; you can watch them miss. Warmth heals nearby allies and adds Resolve, and she walks toward wounded allies to use it. Flare is a painfully slow solar orb that explodes, burns and knocks back. BEAUTIFUL DAY creates a huge stationary sun zone that heals allies and burns enemies."},
}

const DEFAULT_TEAM := ["hazmat", "irene", "eleanor", "colony", "mexai"]

const RIVAL_TEAMS := [
	["hazmat", "irene", "eleanor", "colony", "oddity"],
	["crash_test", "hazmat", "mexai", "sunday", "irene"],
	["kiln", "poppet", "irene", "oddity", "mexai"],
]
static func validate(team: Array) -> String:
	if team.size() != TEAM_SIZE:
		return "Choose five heroes."
	var seen := []
	for i in range(TEAM_SIZE):
		if not HEROES.has(team[i]) or team[i] in seen:
			return "Each hero can appear only once in your squad."
		seen.append(team[i])
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
	if ShopCatalog.validate() != "":
		return ShopCatalog.validate()
	for rival in range(RIVAL_TEAMS.size()):
		if validate(RIVAL_TEAMS[rival]) != "":
			return "Invalid rival squad %d" % rival
	return ""
