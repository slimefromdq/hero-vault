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
	check(Map.length(0) == Map.length(1), "Outer lanes have equal travel length")
	for lane in range(Map.LANE_COUNT):
		for side in range(2):
			var position: Vector2 = Map.BASES[side]
			var corner_seen := false
			var stayed_on_road := true
			for step in range(1200):
				position = Map.move_on_lane(position, Map.BASES[1-side], lane, 2.5)
				corner_seen = corner_seen or position.distance_to(Map.path(lane)[1]) < 3
				stayed_on_road = stayed_on_road and Map.on_lane(position, lane) and (lane == 2 or not Map.JUNGLE.has_point(position))
			check(corner_seen and stayed_on_road, "Lane traffic follows its route through the midpoint")
			check(position.distance_to(Map.BASES[1-side]) < 1, "Lane traffic reaches the opposing base")
			check(Map.on_lane(Map.TOWERS[side][lane], lane), "Tower sits on its assigned lane")
	var battle = Battle.new()
	battle.setup(47, 0, 0, 0)
	check(battle.towers.size() == 6, "Exactly six towers")
	check(Map.length(2) < Map.length(0), "Mid lane is the shorter vault approach")
	check(battle.units[2].lane == 2 and not battle.units[2].roamer, "Default squad deploys a dedicated mid hero")
	check(battle.units[4].roamer, "Saved assignment 2 remains jungle roaming")
	battle.spawn_wave()
	for lane in range(Map.LANE_COUNT):
		check(battle.units.filter(func(u): return u.creep and u.lane == lane).size() == 6, "Each lane receives both creep waves")
	for destination in [1, 2, 0]:
		var roamer: Dictionary = battle.units[4]
		battle.begin_rotation(roamer, destination)
		var visited_jungle := false
		for step in range(2000):
			battle.step()
			visited_jungle = visited_jungle or Map.JUNGLE.has_point(roamer.pos)
			if roamer.rotation.is_empty():
				break
		check(visited_jungle and roamer.rotation.is_empty() and Map.on_lane(roamer.pos, destination), "Roamer crosses jungle to each lane")
	check(Map.nearest_lane(Vector2(500, 250)) == 2, "FULL SEND can select mid on landing")
	var pressure = Battle.new()
	pressure.setup(48, 0, 0, 0)
	var scout: Dictionary = pressure.units[4]
	for hero in pressure.units:
		hero.lane = 0
	pressure.units[5].lane = 2
	pressure.units[5].hp = pressure.units[5].max_hp*0.4
	scout.rotate_cd = 0
	pressure.consider_rotation(scout)
	check(scout.lane == 2 and not scout.rotation.is_empty(), "Roamer responds to a vulnerable opponent in mid")
	var mid_hero: Dictionary = pressure.units[2]
	mid_hero.lane = 2
	check(pressure.objective(mid_hero).pos == Map.TOWERS[1][2], "Mid attacks its own opposing tower")
	var crash: Dictionary = pressure.make_unit("Crash Test", 0, "crash_test", Map.BASES[0], 800, 50, 65, 0)
	crash.flight = {"from": crash.pos, "to": Map.JUNGLE_CENTER, "time": 0.0, "total": 1.0, "distance": 300.0, "target": -1}
	pressure.Kits.update_flight(pressure, crash, 1.0)
	check(crash.flight.is_empty() and crash.lane == 2 and crash.pos == Map.JUNGLE_CENTER, "FULL SEND actually lands on mid")
	print("MAP PASS" if failures == 0 else "MAP FAIL: %d" % failures)
	quit(1 if failures else 0)
