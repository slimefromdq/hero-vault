extends SceneTree
const Battle = preload("res://scripts/battle.gd")
const Catalog = preload("res://scripts/catalog.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _init() -> void:
	check(Catalog.validate_definitions() == "", "Catalog validates")
	var b = Battle.new()
	b.setup(47, 0, 0, 0)
	var rally: Dictionary = b.units[0]
	var colony: Dictionary = b.units[3]
	b.grant_xp(colony, 9999)
	check(colony.level == 13 and colony.radius == 38, "Colony reaches level 13 and final size")
	var hp: float = colony.max_hp
	b.grant_xp(colony, 9999)
	check(colony.level == 13 and colony.max_hp == hp, "Level cap cannot award further stats")
	check(rally.ultimate == 90, "Hazmat ultimate starts with a long cooldown")
	rally.hp = 0
	rally.respawn = 0.01
	b.step()
	check(rally.hp > 0 and rally.ultimate > 89, "Respawn does not reset the ultimate timer")
	b.update_ultimate(rally, 100)
	check(rally.ultimate == 0, "Ultimate becomes available")
	b.clock += 12
	b.begin_ultimate(rally, b.units[5])
	check(rally.ultimate == 90 and b.records[-1].held_seconds == 12, "Ultimate tracks ready holding time and cooldown")
	b.clock = 120
	b.update_crown()
	check(b.crown.spawned and b.crown.holder == -1, "Crown spawns on the jungle floor")
	rally.pos = b.MapLayout.JUNGLE_CENTER
	b.update_crown()
	check(b.crown.holder == rally.id and b.crown_multiplier(rally) == 2, "Hero claims double-damage crown")
	b.snapshot()
	rally.standing = true
	b.apply_damage(rally, 99999, 5)
	check(b.crown.holder == -1 and b.crown.pos == rally.pos, "Death drops the crown at the carrier position")
	check(b.history[-1].crown.holder == rally.id, "Replay preserves prior possession")
	var rival: Dictionary = b.units[5]
	rival.pos = b.crown.pos
	b.update_crown()
	check(b.crown.holder == rival.id, "Enemy can claim the dropped crown")
	check(b.export_csv("user://handoff-test.csv") == OK, "Structured events export to CSV")
	var csv := FileAccess.get_file_as_string("user://handoff-test.csv")
	check(csv.contains("ultimate_cast") and csv.contains("crown_possession") and csv.contains("held_seconds"), "CSV includes timing and object history")
	print("HANDOFF PASS" if failures == 0 else "HANDOFF FAIL: %d" % failures)
	quit(1 if failures else 0)
