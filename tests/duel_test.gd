extends SceneTree
const Battle = preload("res://scripts/battle.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _init() -> void:
	var b = Battle.new()
	b.setup(47, 0, 0, 0)
	var u: Dictionary = b.units[1]
	var enemy: Dictionary = b.units[5]
	u.lane = 0
	enemy.lane = 0
	u.pos = Vector2(600, 80)
	enemy.pos = Vector2(440, 80)
	var start: Vector2 = u.pos
	b.duel_move(u, enemy, 0.05)
	check(u.pos.distance_to(start) > 0.1 and absf(u.pos.y-start.y) > 0.1, "In-range heroes move laterally during a duel")
	for i in range(400):
		b.duel_move(u, enemy, 0.05)
	check(b.MapLayout.on_lane(u.pos, 0), "Footwork stays within the lane")
	u.pos = Vector2(600, 80)
	u.dodge_cd = 0
	b.shots = [{"team": 1, "pos": Vector2(520, 80), "direction": Vector2.RIGHT}]
	start = u.pos
	b.duel_move(u, enemy, 0.05)
	check(u.dodge_cd > 0 and u.pos.distance_to(start) > 15, "An approaching hostile shot triggers a sidestep")
	start = u.pos
	b.duel_move(u, enemy, 0.05)
	check(u.pos.distance_to(start) < 5, "Dodge cooldown prevents repeated instant movement")
	u.dodge_cd = 0
	u.pos = Vector2(600, 80)
	b.shots[0].team = 0
	b.duel_move(u, enemy, 0.05)
	check(u.dodge_cd == 0, "Friendly shots do not trigger dodges")
	check(b.MapLayout.BASES[0] == Vector2(745, 80) and b.camps.size() == 2, "Compact map retains both jungle camps")
	print("DUEL PASS" if failures == 0 else "DUEL FAIL: %d" % failures)
	quit(1 if failures else 0)
