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
		u.lane = 0
		u.home_lane = 0
	return b
func _init() -> void:
	check(Catalog.validate_definitions() == "", "Roster definitions validate")
	check(not Battle.ShopManager.ITEMS.has("idol"), "Double Damage Idol is never purchasable")
	for rival in range(3):
		check(Catalog.validate(Catalog.enemy_team(rival)) == "", "Rival squads validate")
	var dupes: Array = Catalog.DEFAULT_TEAM.duplicate()
	dupes[1] = dupes[0]
	check(Catalog.validate(dupes) != "", "Duplicate hero rejected")
	var b = clean()
	var a: Dictionary = b.units[0]
	var t: Dictionary = b.units[5]
	var hp: float
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
	t.items = ["power_cell"]
	var Inventory = Battle.HeroInventory
	Inventory.refresh(b,t)
	var owner_power: float = t.damage
	var thief_power: float = mexai.damage
	b.steal(mexai,t,false)
	Inventory.refresh(b,t)
	Inventory.refresh(b,mexai)
	check(not b.has_item(t,"power_cell") and b.has_item(mexai,"power_cell"), "Pilfer disables owner item and grants thief its effect")
	check(t.damage == owner_power-20 and mexai.damage == thief_power+20, "Stolen stat bonus moves to the thief")
	b.clock += 9
	b.update_loans()
	Inventory.refresh(b,t)
	Inventory.refresh(b,mexai)
	check(b.has_item(t,"power_cell") and not b.has_item(mexai,"power_cell") and t.damage == owner_power and mexai.damage == thief_power, "Stolen item returns on expiry")
	b.steal(mexai,t,false)
	b.apply_damage(mexai,99999,t.id)
	check(b.thefts.is_empty() and b.has_item(t,"power_cell"), "Thief death returns item")
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
		b.units[i].items = ["swift_treads"]
	mexai.cast_effect = "mexai"
	b.resolve_ultimate(mexai,b.units[5])
	for i in range(30):
		if not mexai.larceny.is_empty():
			b.update_larceny(mexai,0.05)
	check(b.thefts.size() == 5, "Grand Larceny reaches and steals from multiple nearby heroes")
	print("REWORK PASS" if failures == 0 else "REWORK FAIL: %d" % failures)
	quit(1 if failures else 0)
