extends SceneTree
const Battle = preload("res://scripts/battle.gd")
const Catalog = preload("res://scripts/catalog.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: "+message)
func clean():
	var b = Battle.new()
	b.setup(47,0,0,0)
	for u in b.units:
		u.items.clear()
		u.armor = 0
		u.resolve = 0
		u.pos = Vector2(500,80)
	return b
func _init() -> void:
	check(Catalog.validate_definitions() == "", "Roster definitions validate")
	check(not Catalog.ITEMS.has("idol") and not "idol" in Catalog.ITEM_IDS, "Double Damage Idol is never purchasable")
	for rival in range(3):
		check(Catalog.validate(Catalog.enemy_team(rival),Catalog.enemy_items(rival)) == "", "Rival equipment fits shared budget")
	var gear := Catalog.DEFAULT_ITEMS.duplicate(true)
	gear[0] = ["kill_crown","execution"]
	check(Catalog.validate(Catalog.DEFAULT_TEAM,gear) != "", "Over-budget rejected")
	gear[0] = ["last_stand","last_stand"]
	check(Catalog.validate(Catalog.DEFAULT_TEAM,gear) != "", "Duplicate item rejected")
	var b = clean()
	var a: Dictionary = b.units[0]
	var t: Dictionary = b.units[5]
	a.items = ["first_hit"]
	var hp: float = t.hp
	b.apply_damage(t,10,a.id,false,"basic")
	check(t.hp == hp-70, "Hammer first hit gains bonus")
	hp = t.hp
	b.apply_damage(t,10,a.id,false,"basic")
	check(t.hp == hp-10, "Hammer cannot trigger repeatedly")
	b.clock = 9
	hp = t.hp
	b.apply_damage(t,10,a.id,false,"basic")
	check(t.hp == hp-70, "Hammer refreshes out of combat")
	t.items = ["last_stand"]
	t.hp = t.max_hp*0.24
	b.check_last_stand(t)
	check(t.shield > 0 and t.last_stand_used, "Last Stand triggers under threshold")
	t.shield = 0
	b.check_last_stand(t)
	check(t.shield == 0, "Last Stand only once per life")
	a.items = ["execution"]
	t.items.clear()
	t.hp = 100
	b.apply_damage(t,10,a.id)
	check(t.hp == 84, "Execution amplifies damage below twenty percent")
	a.items = ["glass"]
	check(b.power(a) == a.damage+25, "Glass Cannon raises Power")
	hp = a.hp
	b.apply_damage(a,100,t.id)
	check(is_equal_approx(hp-a.hp,120), "Negative Resolve increases incoming damage")
	a.items = ["bodyguard"]
	b.units[1].hp = 1
	hp = a.hp
	b.apply_damage(a,100,t.id)
	check(a.hp == hp-75, "Bodyguard reduces damage beside lower current HP ally")
	a.items = ["coward"]
	a.hp = a.max_hp*0.2
	t.pos = a.pos-Vector2(50,0)
	for i in range(6,10):
		b.units[i].pos = Vector2(100,420)
	check(b.movement_speed(a,a.pos+Vector2(10,0)) == a.speed*1.5, "Boots reward fleeing enemy")
	check(b.movement_speed(a,a.pos-Vector2(10,0)) == a.speed, "Boots do not reward pursuit")
	a.items = ["revenge"]
	t.items = ["kill_crown"]
	b.apply_damage(a,99999,t.id)
	check(t.kill_streak == 1 and t.id in a.revenge_targets, "Death establishes rivalry and kill streak")
	a.hp = a.max_hp
	hp = a.hp
	b.apply_damage(a,140,t.id)
	check(is_equal_approx(a.hp,hp-100), "Revenge defense applies against killer")
	b.apply_damage(t,99999,a.id)
	check(t.kill_streak == 0 and t.id not in a.revenge_targets, "Revenge ends on kill; crown resets on death")
	b = clean()
	var irene: Dictionary = b.units[1]
	t = b.units[5]
	irene.hp = 100
	b.apply_damage(t,100,irene.id,false,"basic")
	check(irene.hp == 125, "Knife lifesteal uses actual HP damage")
	t.shield = 100
	b.apply_damage(t,100,irene.id,false,"basic")
	check(irene.hp == 125, "Shields do not generate lifesteal")
	t.shield = 0
	irene.dash = {"kind":"leech","target":t.id,"time":0.45}
	var original: float = t.max_hp
	var own_max: float = irene.max_hp
	b.update_dash(irene,0.05)
	check(t.max_hp < original and irene.max_hp > own_max, "Leeching Cut temporarily transfers max HP")
	b.clock += 8
	b.update_loans()
	check(is_equal_approx(t.max_hp,original) and is_equal_approx(irene.max_hp,own_max), "Max HP returns exactly")
	irene.cast_effect = "irene"
	b.resolve_ultimate(irene,t)
	check(irene.blood_rush > 0 and b.attack_interval(irene) < irene.attack_interval, "Blood Rush changes attack cadence")
	b.apply_damage(t,20,irene.id,false,"basic")
	hp = irene.hp
	var enemy_hp: float = t.hp
	b.heal(t,t,100)
	check(is_equal_approx(t.hp-enemy_hp,65) and is_equal_approx(irene.hp-hp,35), "Blood Rush redirects enemy healing")
	var mexai: Dictionary = b.units[4]
	t.items = ["glass"]
	b.steal(mexai,t,false)
	check(not b.has_item(t,"glass") and b.has_item(mexai,"glass"), "Pilfer disables owner item and grants thief its effect")
	b.clock += 9
	b.update_loans()
	check(b.has_item(t,"glass") and not b.has_item(mexai,"glass"), "Stolen item returns on expiry")
	b.steal(mexai,t,false)
	b.apply_damage(mexai,99999,t.id)
	check(b.thefts.is_empty() and b.has_item(t,"glass"), "Thief death returns item")
	var oddity := b.make_unit("Oddity",0,"oddity",Vector2(500,80),430,26,210,0)
	oddity.cast_effect = "oddity"
	var irene_pos: Vector2 = irene.pos
	b.resolve_ultimate(oddity,t)
	hp = t.hp
	b.apply_damage(t,999,oddity.id)
	check(t.hp == hp and b.intermission.time > 0, "Intermission blocks damage")
	check(irene.pos == irene_pos and b.protected_ally(oddity).is_empty(), "Oddity never selects or relocates Irene for protection")
	b.grant_shield(oddity,irene,100,3)
	check(irene.shield == 0, "Copied protection cannot shield Irene")
	var target_pos: Vector2 = t.pos
	b.step(0.05)
	check(t.pos == target_pos, "Frozen enemy cannot act")
	b.intermission.time = 0
	a = b.units[0]
	a.cast_effect = "hazmat"
	b.begin_ultimate(a,t)
	check(oddity.copied_ultimate == "hazmat" and oddity.copy_until > b.clock, "Encore witnesses nearby ultimate")
	oddity.cast_effect = "hazmat"
	oddity.cast_scale = 0.7
	b.resolve_ultimate(oddity,t)
	check(b.fields.size() == 1 and is_equal_approx(oddity.overpressure,5.6), "Copied gas duration is weaker")
	b.fields.clear()
	a.cast_scale = 1
	b.resolve_ultimate(a,t)
	a.hp = 100
	a.pos = t.pos
	hp = a.hp
	b.update_fields(0.05)
	check(a.hp > hp and b.fields[0].pos == a.pos, "Overpressure follows caster and heals from gas damage")
	var eleanor: Dictionary = b.units[2]
	eleanor.cast_effect = "eleanor"
	b.resolve_ultimate(eleanor,t)
	check(eleanor.hold_line > 0 and b.movement_speed(eleanor,t.pos) < eleanor.speed, "Hold the Line anchors Eleanor")
	irene.hp = irene.max_hp
	hp = irene.hp
	var protector_hp: float = eleanor.hp
	b.fields.clear()
	b.apply_damage(irene,100,t.id)
	check(irene.hp == hp-65 and eleanor.hp < protector_hp, "Eleanor absorbs ally damage")
	b = clean()
	a = b.units[0]
	t = b.units[5]
	b.fire(a,t,58,false)
	check(b.shots.is_empty() and b.melee_swings.size() == 1, "Heavy Hands uses melee windup, not projectile")
	t.pos = Vector2(745,420)
	hp = t.hp
	b.update_melee(0.5)
	check(t.hp == hp and b.records[-1].kind == "melee_miss", "Leaving range evades a committed melee swing")
	irene = b.units[1]
	irene.items = ["coin"]
	var rolls: Array = []
	for i in range(100):
		t.hp = t.max_hp
		hp = t.hp
		b.apply_damage(t,10,irene.id,false,"basic")
		rolls.append(hp-t.hp)
	check(rolls.has(30.0) and rolls.has(10.0), "Lucky Coin produces normal and triple hits")
	var second = clean()
	second.units[1].items = ["coin"]
	for i in range(100):
		second.units[5].hp = second.units[5].max_hp
		hp = second.units[5].hp
		second.apply_damage(second.units[5],10,1,false,"basic")
		check(hp-second.units[5].hp == rolls[i], "Coin sequence reproducible by seed")
	b = clean()
	eleanor = b.units[2]
	irene = b.units[1]
	irene.hp = 100
	eleanor.lane = irene.lane
	eleanor.dash = {"kind":"intercede","target":irene.id,"time":0.75}
	b.update_dash(eleanor,0.05)
	check(irene.shield > 0 and eleanor.saves == 1, "Intercede arrives and shields endangered ally")
	mexai = b.units[4]
	for i in range(5,10):
		b.units[i].pos = mexai.pos+Vector2(25,0)
		b.units[i].lane = mexai.lane
		b.units[i].items = ["coin"]
	mexai.cast_effect = "mexai"
	b.resolve_ultimate(mexai,b.units[5])
	for i in range(30):
		if not mexai.larceny.is_empty():
			b.update_larceny(mexai,0.05)
	check(b.thefts.size() == 5, "Grand Larceny reaches and steals from multiple nearby heroes")
	print("REWORK PASS" if failures == 0 else "REWORK FAIL: %d" % failures)
	quit(1 if failures else 0)
