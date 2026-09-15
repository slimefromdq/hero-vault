extends SceneTree
const Map = preload("res://scripts/map_layout.gd")
const Battle = preload("res://scripts/battle.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _init() -> void:
	check(Map.BASES[0].x > Map.BASES[1].x and Map.BASES[0].y < Map.BASES[1].y, "Blue northeast, red southwest")
	check(Map.length(0) == Map.length(1), "Both lanes have equal travel length")
	for lane in range(2):
		for side in range(2):
			var position: Vector2 = Map.BASES[side]
			var corner_seen := false
			var stayed_on_road := true
			for step in range(1200):
				position = Map.move_on_lane(position, Map.BASES[1-side], lane, 2.5)
				corner_seen = corner_seen or position.distance_to(Map.path(lane)[1]) < 3
				stayed_on_road = stayed_on_road and Map.on_lane(position, lane) and not Map.JUNGLE.has_point(position)
			check(corner_seen and stayed_on_road, "Lane traffic rounds its outer corner without cutting the jungle")
			check(position.distance_to(Map.BASES[1-side]) < 1, "Lane traffic reaches the opposing base")
			check(Map.on_lane(Map.TOWERS[side][lane], lane), "Tower sits on its assigned lane")
	var battle = Battle.new()
	battle.setup(47, 0, 0, 0)
	check(battle.towers.size() == 4, "Exactly four towers")
	var roamer: Dictionary = battle.units[4]
	battle.begin_rotation(roamer, 1)
	var visited_jungle := false
	for step in range(2000):
		battle.step()
		visited_jungle = visited_jungle or Map.JUNGLE.has_point(roamer.pos)
		if roamer.rotation.is_empty():
			break
	check(visited_jungle and roamer.rotation.is_empty() and Map.on_lane(roamer.pos, 1), "Roamer crosses jungle and arrives in the other lane")
	print("MAP PASS" if failures == 0 else "MAP FAIL: %d" % failures)
	quit(1 if failures else 0)
