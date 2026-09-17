extends RefCounted
## Shared team currency. Knows nothing about items, heroes or the drone.

const STARTING_CREDITS := 300.0
const PASSIVE_PER_SECOND := 2.0
const HERO_BOUNTY := 75.0
const CREEP_BOUNTY := 6.0

var team := 0
var credits := STARTING_CREDITS
var earned := STARTING_CREDITS
var spent := 0.0

func _init(team_index: int) -> void:
	team = team_index

func tick(dt: float) -> void:
	add(PASSIVE_PER_SECOND*dt)

func can_afford(cost: float) -> bool:
	return cost >= 0 and credits >= cost

## Returns false (and changes nothing) when the team cannot pay.
func spend(cost: float) -> bool:
	if not can_afford(cost):
		return false
	credits -= cost
	spent += cost
	return true

func add(amount: float) -> void:
	if amount <= 0:
		return
	credits += amount
	earned += amount

func earn_bounty(creep: bool) -> void:
	add(CREEP_BOUNTY if creep else HERO_BOUNTY)

func balance() -> int:
	return int(floor(credits))

func to_dict() -> Dictionary:
	return {"team": team, "credits": credits, "earned": earned, "spent": spent}
