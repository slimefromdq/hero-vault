extends SceneTree
const Map = preload("res://scripts/map_layout.gd")
const Battle = preload("res://scripts/battle.gd")
const Catalog = preload("res://scripts/catalog.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _init() -> void:
	check(Map.BASES[0].x > Map.BASES[1].x and Map.BASES[0].y < Map.BASES[1].y, "Blue northeast, red southwest")
	check(Map.LANE_COUNT == 3, "Three lanes")
	check(Map.length(Map.TOP) == Map.length(Map.BOT), "Outer lanes have equal travel length")
	check(Map.length(Map.MID) < Map.length(Map.TOP) * 0.8, "Mid is the short lane")
	check(Map.COVER.size() == 4, "Bottom has cover patches")
	for bush in Map.COVER:
		check(Map.on_lane(bush.get_center(), Map.BOT), "Cover sits on bottom lane")
	for lane in range(Map.LANE_COUNT):
		for side in range(2):
			var position: Vector2 = Map.BASES[side]
			var corner_seen := lane == Map.MID
			var stayed_on_road := true
			var cut_jungle := false
			for step in range(1400):
				position = Map.move_on_lane(position, Map.BASES[1-side], lane, 2.5)
				if lane != Map.MID:
					corner_seen = corner_seen or position.distance_to(Map.path(lane)[1]) < 3
				stayed_on_road = stayed_on_road and Map.on_lane(position, lane)
				cut_jungle = cut_jungle or Map.in_jungle(position)
			check(corner_seen and stayed_on_road and not cut_jungle, "Lane %d traffic stays on the road and out of jungle" % lane)
			check(position.distance_to(Map.BASES[1-side]) < 1, "Lane %d reaches the opposing base" % lane)
			check(Map.on_lane(Map.TOWERS[side][lane], lane), "Tower sits on lane %d" % lane)
	var mid_cut: Array = Map.rotation_waypoints(Map.MID, Map.TOP)
	var long_cut: Array = Map.rotation_waypoints(Map.TOP, Map.BOT)
	check(mid_cut[0].distance_to(mid_cut[2]) < long_cut[0].distance_to(long_cut[2]), "Mid-to-top river cut is shorter than top-to-bottom")
	var blocked := Map.cover_blocks(Vector2(745, 140), Vector2(745, 360), Vector2(INF, INF))
	check(blocked, "A shot down bottom's east corridor is stopped by cover")
	check(not Map.cover_blocks(Vector2(745, 140), Vector2(745, 360), Vector2(727, 194)), "Cover does not hide a target standing in that bush")
	var battle = Battle.new()
	battle.setup(47, 0, 0, 0)
	check(battle.towers.size() == 6, "Six towers, two per lane")
	check(battle.units[0].lane == Map.TOP and battle.units[1].lane == Map.MID and battle.units[2].lane == Map.BOT, "Default lineup is top, mid, bottom duo")
	check(battle.units[4].roamer and battle.units[4].lane == Map.MID, "Roamer starts in mid")
	var roamer: Dictionary = battle.units[4]
	battle.begin_rotation(roamer, Map.BOT)
	var visited_jungle := false
	for step in range(2000):
		battle.step()
		visited_jungle = visited_jungle or Map.in_jungle(roamer.pos)
		if roamer.rotation.is_empty():
			break
	check(visited_jungle and roamer.rotation.is_empty() and Map.on_lane(roamer.pos, Map.BOT), "Roamer crosses jungle and arrives in the other lane")
	check(Catalog.migrate_lanes([0, 0, 1, 1, 2]) == [0, 1, 2, 2, 3], "Two-lane saves become top, mid, bottom duo, roam")
	print("MAP PASS" if failures == 0 else "MAP FAIL: %d" % failures)
	quit(1 if failures else 0)
