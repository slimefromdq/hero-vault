extends RefCounted
## Remote-shop item data. ShopManager sells these; HeroInventory applies their stats.
## Prototype set: exists to verify purchase -> delivery -> inventory, not for balance.

const ITEM_IDS := ["power_cell", "vital_plate", "swift_treads"]
# stats keys: power (basic/structure damage), max_hp, speed (movement).
const ITEMS := {
	"power_cell": {"name": "Power Cell", "cost": 250, "stats": {"power": 20.0}, "summary": "+20 Power"},
	"vital_plate": {"name": "Vital Plate", "cost": 200, "stats": {"max_hp": 100.0}, "summary": "+100 Max HP"},
	"swift_treads": {"name": "Swift Treads", "cost": 150, "stats": {"speed": 2.0}, "summary": "+2 Move Speed"},
}
const STAT_KEYS := ["power", "max_hp", "speed"]

static func validate() -> String:
	if ITEM_IDS.size() != ITEMS.size():
		return "Shop item IDs must be unique and complete"
	for id in ITEM_IDS:
		if not ITEMS.has(id):
			return "Missing shop item: " + id
		if int(ITEMS[id].cost) <= 0:
			return "Shop items must cost something: " + id
		for stat in ITEMS[id].stats:
			if stat not in STAT_KEYS:
				return "Unknown item stat: " + stat
	return ""
