extends SceneTree
const Battle = preload("res://scripts/battle.gd")
const Catalog = preload("res://scripts/catalog.gd")
## Usage: godot --headless --path . --script res://tools/balance_probe.gd  (set N for match count)
func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var stats := {}
	for id in Catalog.HERO_IDS:
		stats[id] = {"games":0,"wins":0,"kills":0,"deaths":0,"dmg":0.0,"heal":0.0}
	var n := int(OS.get_environment("N")) if OS.get_environment("N") != "" else 30
	var times := []
	for g in range(n):
		var pool: Array = Catalog.HERO_IDS.duplicate()
		var team := []
		for i in range(5):
			team.append(pool.pop_at(rng.randi_range(0, pool.size()-1)))
		var b = Battle.new()
		b.setup(1000+g, g%3, 0, g%3, team, Catalog.DEFAULT_ITEMS, Catalog.DEFAULT_LANES)
		while b.winner == -1 and b.clock < 1100:
			b.step()
		times.append(int(b.clock))
		for u in b.units:
			if u.creep: continue
			var s = stats[u.portrait]
			s.games += 1
			s.wins += 1 if b.winner == u.team else 0
			s.kills += u.kills; s.deaths += u.deaths; s.dmg += u.damage_done; s.heal += u.healing_done
	for id in Catalog.HERO_IDS:
		var s = stats[id]
		if s.games == 0: continue
		print("%-11s g=%3d win=%.2f k=%.1f d=%.1f dmg=%5d heal=%4d" % [id, s.games, float(s.wins)/s.games, float(s.kills)/s.games, float(s.deaths)/s.games, s.dmg/s.games, s.heal/s.games])
	print("times ", times)
	quit()
