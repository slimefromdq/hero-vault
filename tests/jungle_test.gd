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
	var u: Dictionary = b.units[4]
	var camp: Dictionary = b.camps[0]
	u.pos = camp.pos+Vector2(40, 0)
	u.camp_target = 0
	u.cooldown = 0
	camp.hp = 1
	var xp: int = u.xp
	b.farm_camp(u, 0.05)
	check(camp.hp == 0 and camp.respawn == 75, "Camp is cleared and schedules respawn")
	check(u.xp == xp+6 and u.level == 2, "Camp grants XP and normal level growth")
	check(u.jungle_buff == 45 and u.buff_kind == "power", "Clearing grants a timed power boost")
	var enemy: Dictionary = b.units[5]
	u.attacks = 0
	b.fire(u, enemy, 100, false)
	check(is_equal_approx(b.melee_swings[-1].damage, b.power(u)*1.2), "Power boost increases attack damage")
	b.snapshot()
	check(b.history[-1].camps[0].hp == 0, "Replay records cleared camps")
	b.update_camps(75)
	check(camp.hp == camp.max_hp and b.history[-1].camps[0].hp == 0, "Camp respawn does not change recorded frames")
	b.update_effects(u, 46)
	u.attacks = 0
	b.fire(u, enemy, 100, false)
	check(b.melee_swings[-1].damage == b.power(u), "Power expires without permanently altering damage")
	u.buff_kind = "regen"
	u.jungle_buff = 45
	u.hp = u.max_hp-30
	var hp: float = u.hp
	b.update_effects(u, 1)
	check(u.hp == hp+3, "Grove boost heals over time")
	u.camp_target = 1
	u.pos = b.camps[1].pos
	u.hp = u.max_hp*0.2
	check(not b.farm_camp(u, 0.05) and u.camp_target == -1, "Wounded heroes abandon the camp")
	u.hp = u.max_hp
	u.camp_target = 1
	u.cooldown = 10
	hp = u.hp
	b.farm_camp(u, 0.05)
	check(u.hp < hp, "Living guardians retaliate")
	b.apply_damage(u, 9999, -2)
	check(u.jungle_buff == 0 and b.kills == [0, 0], "Jungle death clears boosts without awarding an opponent takedown")
	print("JUNGLE PASS" if failures == 0 else "JUNGLE FAIL: %d" % failures)
	quit(1 if failures else 0)
