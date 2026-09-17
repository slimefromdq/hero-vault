extends RefCounted
## Fixed-step, seeded simulation. Presentation never changes battle state.

const STEP := 0.05
const Catalog = preload("res://scripts/catalog.gd")
const MapLayout = preload("res://scripts/map_layout.gd")
const Expressions = preload("res://scripts/expressions.gd")
const Kits = preload("res://scripts/hero_kits.gd")
const TeamEconomy = preload("res://scripts/team_economy.gd")
const ShopManager = preload("res://scripts/shop_manager.gd")
const CourierDrone = preload("res://scripts/courier_drone.gd")
const HeroInventory = preload("res://scripts/hero_inventory.gd")
const VAULT_HP := 14000.0
const TOWER_HP := 4200.0
const TOWER_RANGE := 300.0
const HERO_HEALTH_SCALE := 1.4
const WAVE_INTERVAL := 30.0
const NODE_SPAWN := 240.0
const NODE_RESPAWN := 180.0
const NODE_BUFF := 90.0
var wave_number := 0
var empowered_until := [0.0, 0.0]
var match_id := ""
var records: Array = []
var crown := {"spawned": false, "holder": -1, "pos": MapLayout.JUNGLE_CENTER, "since": 0.0, "kills": 0}
var rng := RandomNumberGenerator.new()
var units: Array = []
var shots: Array = []
var events: Array = []
var history: Array = []
var clock := 0.0
var wave_clock := 0.0
var snapshot_clock := 0.0
var vaults := [VAULT_HP, VAULT_HP]
var towers: Array = []
var camps: Array = []
var fields: Array = []
var thefts: Array = []
var health_loans: Array = []
var intermission := {"time": 0.0, "caster": -1}
var melee_swings: Array = []
var team_orders: Array = []
var valid := false
var winner := -1
var plan := 0
var assignment := 0
var opponent := 0
var next_id := 0
var kills := [0, 0]
var overtime := false
var mirroring := false # Guards Poppet damage mirroring from recursing.
# Per-team logistics, indexed by team: shared currency, remote shop + delivery queue, courier drone.
var economies: Array = []
var shops: Array = []
var couriers: Array = []

func setup(seed_value: int, team_plan: int, hero_assignment: int, rival: int, team: Array = Catalog.DEFAULT_TEAM, orders: Array = MapLayout.DEFAULT_ORDERS) -> void:
	if Catalog.validate(team) != "" or orders.size() != 5 or orders.any(func(order): return int(order) < 0 or int(order) > MapLayout.MID_ORDER):
		push_error("Invalid squad or lane orders")
		return
	if Catalog.validate_definitions() != "":
		push_error(Catalog.validate_definitions())
		return
	match_id = "%d-%d-%d-%d" % [seed_value, team_plan, hero_assignment, rival]
	rng.seed = seed_value
	plan = team_plan
	assignment = hero_assignment
	opponent = rival
	team_orders = orders.duplicate()
	var lineups := [team, Catalog.enemy_team(rival)]
	for side in range(2):
		for slot in range(5):
			var order: int = int(orders[slot]) if side == 0 else MapLayout.DEFAULT_ORDERS[slot]
			var lane: int = MapLayout.order_lane(order)
			var id: String = lineups[side][slot]
			var data: Dictionary = Catalog.HEROES[id]
			var front: bool = data.reach < 130
			var progress := 105.0 if front else 55.0
			if side == 1:
				progress = MapLayout.length(lane)-progress
			var pos := MapLayout.point_at(lane, progress)
			pos += MapLayout.forward(pos, lane, side).orthogonal()*[-20, 20, -20, 20, 0][slot]
			var strength: float = 1.0 if side == 0 else [0.88, 0.96, 1.0][rival]
			var u := make_unit(data.name, side, id, pos, data.hp * strength * HERO_HEALTH_SCALE, data.damage * strength, data.reach, lane)
			u.speed = float(data.speed)
			u.roamer = order == MapLayout.ROAM_ORDER
			u.behavior = Catalog.behavior(id)
			u.ultimate = Catalog.ULTIMATES.get(id, {}).get("cooldown", 0.0)
			u.ultimate_cooldown = u.ultimate
		for lane in range(MapLayout.LANE_COUNT):
			towers.append({"team": side, "lane": lane, "hp": TOWER_HP, "max_hp": TOWER_HP, "pos": MapLayout.TOWERS[side][lane], "cooldown": 0.0, "flash": 0.0})
	for i in range(MapLayout.CAMPS.size()):
		camps.append({"pos": MapLayout.CAMPS[i], "name": "Ember Beast" if i == 0 else "Grove Guardian", "kind": "power" if i == 0 else "regen", "hp": 260.0, "max_hp": 260.0, "respawn": 0.0, "cooldown": 0.0, "last_hit": -100.0})
	camps.append({"pos": MapLayout.POWER_NODE, "name": "Central Power Node", "kind": "node", "hp": 0.0, "max_hp": 2400.0, "respawn": NODE_SPAWN, "cooldown": 0.0, "last_hit": -100.0})
	for side in range(2):
		economies.append(TeamEconomy.new(side))
		shops.append(ShopManager.new(side, economies[side], side == 1))
		couriers.append(CourierDrone.new(side, MapLayout.BASES[side]))
	valid = true
	log_event("Deployment", "Five heroes per side. Break a lane tower to reach the vault.", "deploy")
	snapshot()

func make_unit(hero_name: String, team: int, portrait: String, pos: Vector2, hp: float, damage: float, reach: float, lane: int) -> Dictionary:
	var u := {"id": next_id, "name": hero_name, "team": team, "portrait": portrait,
		"pos": pos, "spawn": pos, "hp": hp, "max_hp": hp, "damage": damage,
		"reach": reach, "speed": 45.0, "cooldown": rng.randf_range(0, 0.6),
		"behavior": {"retreat": 3, "pursuit": 3, "roaming": 3, "dueling": 3, "waveclear": 3, "siege": 3, "protection": 3}, "ultimate_cooldown": 0.0, "available_since": 0.0, "ability": 4.0, "ultimate": 0.0, "charge": 0.0, "charge_target": -1,
		"shield": 0.0, "shield_time": 0.0, "respawn": 0.0, "standing": false,
		"copied_ultimate": "", "cast_effect": "", "creep": false, "intent": "Advance with the wave", "facing": MapLayout.forward(pos, lane, team).angle(),
		"flash": 0.0, "xp": 0, "level": 1, "kills": 0, "deaths": 0, "saves": 0,
		"hop": 0.0, "clutch_until": 0.0, "lane": lane, "home_lane": lane,
		"orbit_sign": 1.0 if next_id%2 == 0 else -1.0, "dodge_cd": 0.0, "jungle_buff": 0.0, "buff_kind": "", "camp_target": -1, "roamer": false, "rotation": [], "rotation_from": lane, "rotate_cd": 20.0, "stun": 0.0,
		"curse": 0.0, "curse_source": -1, "attacks": 0,
		"radius": MapLayout.HERO_RADIUS, "items": [], "item_bonus": HeroInventory.empty_bonus(), "last_hit": -100.0,
		"attack_interval": 1.25, "armor": 0.0, "resolve": 0.0,
		"blood_rush": 0.0, "overpressure": 0.0, "hold_line": 0.0,
		"healing_mark": -1, "healing_mark_until": 0.0, "encore_cd": 0.0,
		"copy_until": 0.0, "cast_scale": 1.0, "swing": 0.0,
		"larceny": [], "larceny_time": 0.0, "dash": {}, "damage_done": 0.0,
		"healing_done": 0.0, "last_attacker": -1,
		"retreating": false, "decision_cd": 0.0, "decision": "farm", "creep_kind": "", "empowered": false, "ability2": 6.0, "stability": 5, "flight": {}, "safety": 0.0, "program": 0.0, "program_scale": 1.0, "program_cd": 0.0,
		"warmth": 0.0, "warmth_tick": 0.0, "sun_center": Vector2.ZERO}
	if Catalog.HEROES.has(portrait):
		var data: Dictionary = Catalog.HEROES[portrait]
		u.armor = data.armor
		u.resolve = data.resolve
		u.attack_interval = data.interval
		u.stability = data.get("stability", 5)
		u.radius = data.get("size", MapLayout.HERO_RADIUS)
	units.append(u)
	next_id += 1
	return u

func spawn_wave() -> void:
	wave_number += 1
	for team in range(2):
		for lane in range(MapLayout.LANE_COUNT):
			for index in range(5 if wave_number % 3 == 0 else 4):
				var progress := 20.0 if team == 0 else MapLayout.length(lane)-20.0
				var pos := MapLayout.point_at(lane, progress)
				pos += MapLayout.forward(pos, lane, team).orthogonal()*((index % 3)-1)*19
				var kind: String = "melee" if index < 2 else "ranged" if index < 4 else "siege"
				var stats: Array = {"melee": [240.0, 12.0, 48.0], "ranged": [130.0, 19.0, 160.0], "siege": [380.0, 16.0, 220.0]}[kind]
				var growth := 1.0 + clock/900.0
				var empowered: bool = empowered_until[team] > clock
				var u := make_unit(kind.capitalize()+" creep", team, "", pos, stats[0]*growth*(1.4 if empowered else 1.0), stats[1]*growth, stats[2], lane)
				u.creep = true
				u.creep_kind = kind
				u.empowered = empowered
				u.radius = 12.0
				u.speed = 50.0

func step(dt: float = STEP) -> void:
	if not valid or winner != -1:
		return
	clock += dt
	update_logistics(dt)
	if intermission.time > 0:
		intermission.time = maxf(0, intermission.time-dt)
		var performer := get_unit(intermission.caster)
		if not performer.is_empty() and performer.hp > 0:
			performer.pos = MapLayout.constrain(performer.pos + Vector2.from_angle(clock*2)*20*dt, performer.lane)
			performer.intent = "INTERMISSION / restaging the fight"
		if intermission.time <= 0:
			log_event("CURTAIN UP", "Combat resumes in the new formation.", "intermission_end", intermission.caster)
		snapshot_clock -= dt
		if snapshot_clock <= 0:
			snapshot()
			snapshot_clock = 0.15
		return
	update_loans()
	update_melee(dt)
	if clock >= 720.0 and not overtime:
		overtime = true
		log_event("OVERTIME", "Vault defenses are weakening. Every push matters.", "overtime")
	update_crown()
	update_fields(dt)
	update_camps(dt)
	wave_clock -= dt
	if wave_clock <= 0:
		spawn_wave()
		wave_clock = WAVE_INTERVAL
	for u in units:
		update_ultimate(u, dt)
		if u.hp <= 0:
			if not u.creep:
				u.flight.clear()
				u.respawn -= dt
				if u.respawn <= 0:
					u.hp = u.max_hp
					u.pos = u.spawn
					u.standing = false
					u.shield = 0.0
					u.charge = 0.0
					u.ability = 2.0
					u.hop = 0.0
					u.stun = 0.0
					u.curse = 0.0
					u.rotation.clear()
					u.camp_target = -1
					u.jungle_buff = 0.0
					u.lane = u.home_lane
					log_event(u.name + " returns", "Back in the fight at level %d." % u.level, "respawn", u.id)
			continue
		update_effects(u, dt)
		if u.hp <= 0:
			continue
		if not u.flight.is_empty():
			Kits.update_flight(self, u, dt)
			continue
		u.cooldown -= dt
		u.ability -= dt
		u.ability2 -= dt
		u.hop -= dt
		u.flash = maxf(0, u.flash - dt)
		u.shield_time -= dt
		if u.shield_time <= 0:
			u.shield = 0.0
		if u.stun > 0:
			u.charge = 0.0
			u.intent = "Staggered"
			u.dash.clear()
			u.larceny.clear()
			continue
		if u.swing > 0:
			u.swing = maxf(0, u.swing-dt)
			u.intent = "Melee windup"
			continue
		if not u.dash.is_empty():
			update_dash(u, dt)
			continue
		if not u.larceny.is_empty():
			update_larceny(u, dt)
			continue
		if u.charge > 0:
			u.charge -= dt
			u.intent = "Ultimate windup"
			if u.charge <= 0:
				resolve_ultimate(u, get_unit(u.charge_target))
				if intermission.time > 0:
					break
			continue
		if not u.creep:
			update_decision(u, dt)
			if u.decision == "retreat":
				u.retreating = true
				u.intent = "Retreat / recover at the vault"
				if not u.rotation.is_empty():
					u.lane = MapLayout.nearest_lane(u.pos)
					u.pos = u.pos.move_toward(MapLayout.project(u.pos, u.lane).point, movement_speed(u, u.spawn)*dt)
					if MapLayout.on_lane(u.pos, u.lane):
						u.rotation.clear()
				else:
					u.pos = MapLayout.move_on_lane(u.pos, MapLayout.BASES[u.team], u.lane, movement_speed(u, u.spawn)*1.15*dt)
				if u.pos.distance_to(MapLayout.BASES[u.team]) < 140:
					heal(u, u, u.max_hp*0.08*dt)
				continue
			u.retreating = false
			consider_rotation(u)
		if not u.rotation.is_empty() and u.charge <= 0:
			if u.rotation.size() == 2 and farm_camp(u, dt):
				continue
			u.intent = "Rotate through the jungle"
			if u.rotation.size() == 3:
				u.pos = MapLayout.move_on_lane(u.pos, u.rotation[0], u.rotation_from, movement_speed(u, u.rotation[0])*dt)
			else:
				u.pos = u.pos.move_toward(u.rotation[0], movement_speed(u, u.rotation[0])*dt)
			if u.pos.distance_to(u.rotation[0]) < 2:
				u.rotation.pop_front()
			continue
		var enemy := select_enemy(u)
		if not u.creep and avoid_tower(u, dt):
			continue
		if not u.creep:
			use_abilities(u, enemy)
			if u.charge > 0 or not u.dash.is_empty() or not u.flight.is_empty():
				continue
		if not enemy.is_empty():
			var distance: float = u.pos.distance_to(enemy.pos)
			u.facing = u.pos.angle_to_point(enemy.pos)
			if distance > u.reach:
				u.intent = "Approach " + enemy.name
				var destination: Vector2 = enemy.pos
				u.pos = MapLayout.move_on_lane(u.pos, destination, u.lane, movement_speed(u, destination)*dt)
			else:
				u.intent = "Attack " + enemy.name
				if u.cooldown <= 0:
					fire(u, enemy, u.damage, false)
					u.cooldown = attack_interval(u)
				if not u.creep and not enemy.creep:
					duel_move(u, enemy, dt)
		else:
			siege(u, dt)
			if winner != -1:
				snapshot()
				return
		if not u.creep:
			u.retreating = u.intent.begins_with("Retreat")
		if not u.creep and u.pos.distance_to(u.spawn) < 85:
			heal(u, u, 12.0 * dt)
		# Small separation maintains readable tokens without physics-dependent outcomes.
		for other in units:
			if other.id <= u.id or other.hp <= 0 or not other.flight.is_empty():
				continue
			var gap: Vector2 = u.pos - other.pos
			var minimum: float = u.radius + other.radius + 5.0
			if gap.length() < minimum and gap.length() > 0.01:
				var push := gap.normalized() * (minimum - gap.length()) * 0.12
				u.pos += push
				other.pos -= push
		u.pos = MapLayout.constrain(u.pos, u.lane)
	if intermission.time <= 0:
		update_towers(dt)
		update_shots(dt)
	units = units.filter(func(u): return not u.creep or u.hp > 0)
	snapshot_clock -= dt
	if snapshot_clock <= 0 or winner != -1:
		snapshot()
		snapshot_clock = 0.15

func get_unit(id: int) -> Dictionary:
	for u in units:
		if u.id == id:
			return u
	return {}

func protected_ally(u: Dictionary) -> Dictionary:
	# Lore relationships never create a bodyguard order for Oddity.
	if u.portrait == "oddity":
		return {}
	return weakest_ally(u, 230)

func weakest_ally(u: Dictionary, reach: float) -> Dictionary:
	var best: Dictionary = {}
	var ratio := 1.01
	for ally in units:
		if ally.id != u.id and can_protect(u, ally) and ally.team == u.team and not ally.creep and ally.hp > 0 and ally.lane == u.lane and ally.rotation.is_empty() and u.pos.distance_to(ally.pos) <= reach and ally.hp / ally.max_hp < ratio:
			best = ally
			ratio = ally.hp / ally.max_hp
	return best

func grant_shield(source: Dictionary, target: Dictionary, amount: float, duration: float) -> void:
	if not can_protect(source, target):
		return
	target.shield = maxf(target.shield, amount)
	target.shield_time = maxf(target.shield_time, duration)

func stagger(target: Dictionary, seconds: float) -> void:
	target.stun = maxf(target.stun, seconds/(1+target.resolve/100))

func update_effects(u: Dictionary, dt: float) -> void:
	for timer in ["dodge_cd", "jungle_buff", "stun", "blood_rush", "overpressure", "hold_line", "encore_cd", "curse"]:
		u[timer] = maxf(0, u[timer]-dt)
	Kits.tick(self, u, dt)
	if not u.creep:
		HeroInventory.refresh(self, u)
	u.rotate_cd -= dt
	if u.jungle_buff > 0 and u.buff_kind == "regen":
		heal(u, u, 3.0*dt)
	if u.copy_until <= clock:
		u.copied_ultimate = ""

func leading_creep(u: Dictionary) -> Dictionary:
	var front: Dictionary = {}
	var best := -INF
	for ally in units:
		if ally.team != u.team or not ally.creep or ally.hp <= 0 or ally.lane != u.lane:
			continue
		var progress: float = MapLayout.project(ally.pos, u.lane).progress * (1.0 if u.team == 0 else -1.0)
		if progress > best:
			best = progress
			front = ally
	return front

func wave_support(u: Dictionary, position: Vector2) -> bool:
	return units.any(func(a): return a.creep and a.team == u.team and a.lane == u.lane and a.hp > 0 and a.pos.distance_to(position) <= TOWER_RANGE)

func avoid_tower(u: Dictionary, dt: float) -> bool:
	var target := objective(u)
	if target.get("vault", false) or wave_support(u, target.pos):
		return false
	if u.pos.distance_to(target.pos) > TOWER_RANGE + 60:
		return false
	var progress: float = MapLayout.project(target.pos, u.lane).progress
	var safe := MapLayout.point_at(u.lane, progress + (-TOWER_RANGE-85 if u.team == 0 else TOWER_RANGE+85))
	u.intent = "Wait for wave / tower danger"
	u.pos = MapLayout.move_on_lane(u.pos, safe, u.lane, movement_speed(u, safe)*dt)
	return true

func update_decision(u: Dictionary, dt: float) -> void:
	u.decision_cd -= dt
	if u.decision_cd > 0:
		return
	u.decision_cd = 0.3
	var friends := 1
	var threats := 0
	for other in units:
		if other.id == u.id or other.hp <= 0 or other.creep or not other.flight.is_empty() or other.pos.distance_to(u.pos) > 260:
			continue
		if other.team == u.team:
			friends += 1
		else:
			threats += 1
	var threshold: float = 0.20 + u.behavior.retreat*0.07 + maxf(0, threats-friends)*0.08
	if u.team == 0:
		threshold *= [1.0, 0.8, 1.15][plan]
	var previous: String = u.decision
	if u.hp/u.max_hp < threshold or (previous == "retreat" and u.hp/u.max_hp < 0.8):
		u.decision = "retreat"
		u.camp_target = -1
	elif not u.rotation.is_empty():
		u.decision = "rotate"
	else:
		var enemy := select_enemy(u)
		u.decision = "fight" if not enemy.is_empty() and not enemy.creep else "push" if not leading_creep(u).is_empty() else "farm"
	if u.decision != previous:
		record_event("decision", u.id, -1, 0, {"from": previous, "to": u.decision, "nearby_enemies": threats, "nearby_allies": friends})

func consider_rotation(u: Dictionary) -> void:
	if u.rotate_cd > 0 or not u.rotation.is_empty() or u.hp/u.max_hp < 0.5:
		return
	# Commit only part of a squad, leaving the other heroes to protect their waves.
	var node: Dictionary = camps[-1]
	var committed := units.filter(func(a): return a.team == u.team and not a.creep and a.hp > 0 and a.camp_target == camps.size()-1).size()
	if node.hp > 0 and committed < 3 and (u.roamer or u.behavior.roaming >= 3) and select_enemy(u).is_empty():
		begin_rotation(u, u.lane)
		u.camp_target = camps.size()-1
		u.rotate_cd = 35.0
		log_event("CONTEST POWER NODE", u.name + " leaves lane for the empowered-wave objective.", "node_rotate", u.id)
		return
	if not u.roamer:
		return
	u.rotate_cd = 30.0-u.behavior.roaming*4.0
	var other_lane: int = (u.lane+1)%MapLayout.LANE_COUNT
	var best_pressure := -INF
	for lane in range(MapLayout.LANE_COUNT):
		if lane == u.lane:
			continue
		var allies := 0
		var enemies := 0
		var wounded := false
		for hero in units:
			if hero.creep or hero.hp <= 0 or hero.lane != lane or not hero.rotation.is_empty():
				continue
			if hero.team == u.team:
				allies += 1
			else:
				enemies += 1
				wounded = wounded or hero.hp / hero.max_hp < 0.65
		if enemies > 0 and (wounded or enemies >= allies):
			var pressure: float = enemies-allies+(2.0 if wounded else 0.0)
			if pressure > best_pressure:
				best_pressure = pressure
				other_lane = lane
	if best_pressure > -INF:
		begin_rotation(u, other_lane)
		u.rotate_cd = 34.0
		log_event("Rotation  -  " + u.name, "Through the jungle toward " + MapLayout.LANE_NAMES[other_lane].to_lower() + " lane. Available camps provide farm during travel.", "rotate", u.id)

	elif camps.any(func(c): return c.hp > 0):
		begin_rotation(u, other_lane)
		u.rotate_cd = 45.0

func begin_rotation(u: Dictionary, destination_lane: int) -> void:
	u.camp_target = -1
	if u.roamer and u.hp/u.max_hp >= 0.5:
		var best := INF
		for i in range(camps.size()):
			var distance: float = u.pos.distance_to(camps[i].pos)
			if camps[i].kind != "node" and camps[i].hp > 0 and distance < best:
				best = distance
				u.camp_target = i
	u.rotation_from = u.lane
	u.rotation = [MapLayout.ENTRANCES[u.lane], MapLayout.JUNGLE_CENTER, MapLayout.ENTRANCES[destination_lane]]
	u.lane = destination_lane

func objective(u: Dictionary) -> Dictionary:
	for tower in towers:
		if tower.team != u.team and tower.lane == u.lane and tower.hp > 0:
			return tower
	return {"team": 1-u.team, "lane": u.lane, "hp": vaults[1-u.team], "pos": MapLayout.BASES[1-u.team], "vault": true}

func siege(u: Dictionary, dt: float) -> void:
	var target := objective(u)
	var destination: Vector2 = target.pos
	var is_vault: bool = target.get("vault", false)
	if not u.creep:
		var wave := leading_creep(u)
		if not wave.is_empty() and u.pos.distance_to(target.pos) > TOWER_RANGE:
			var wave_progress: float = MapLayout.project(wave.pos, u.lane).progress
			var behind := MapLayout.point_at(u.lane, wave_progress + (-65.0 if u.team == 0 else 65.0))
			if u.pos.distance_to(behind) > 90:
				u.intent = "Follow allied wave"
				u.pos = MapLayout.move_on_lane(u.pos, behind, u.lane, movement_speed(u, behind)*dt)
				return
	u.facing = u.pos.angle_to_point(destination)
	if u.pos.distance_to(target.pos) > u.reach + 30 or destination != target.pos:
		u.pos = MapLayout.move_on_lane(u.pos, destination, u.lane, movement_speed(u, destination)*dt)
		u.intent = "Push " + MapLayout.LANE_NAMES[u.lane].to_lower() + (" vault approach" if is_vault else " tower")
		return
	u.intent = "Siege vault" if is_vault else "Siege lane tower"
	if u.cooldown > 0:
		return
	var multiplier := 0.20 if not overtime else 1.0 + (clock - 720.0)/90.0
	if u.creep:
		multiplier *= (3.5 if u.creep_kind == "siege" else 1.0) * (1.6 if u.empowered else 1.0)
	elif not wave_support(u, target.pos):
		multiplier *= 0.15
	var amount: float = power(u) * crown_multiplier(u) * multiplier * Kits.siege_multiplier(self, u)
	u.cooldown = attack_interval(u)
	u.flash = 0.12
	if is_vault:
		vaults[1-u.team] = maxf(0, vaults[1-u.team] - amount)
		if vaults[1-u.team] <= 0 and winner == -1:
			winner = u.team
			log_event("VAULT DESTROYED", "Your squad wins." if winner == 0 else "The opposing squad wins.", "victory", u.id)
	else:
		target.hp = maxf(0, target.hp-amount)
		if target.hp <= 0:
			log_event("TOWER FALLS", "The lane is open.", "tower", u.id)

func update_towers(dt: float) -> void:
	for tower in towers:
		tower.flash = maxf(0, tower.flash - dt)
		tower.cooldown -= dt
		if tower.hp <= 0 or tower.cooldown > 0:
			continue
		var target: Dictionary = {}
		var best := INF
		for u in units:
			if u.team == tower.team or u.hp <= 0 or u.lane != tower.lane or not u.flight.is_empty():
				continue
			var distance: float = tower.pos.distance_to(u.pos)
			if distance > TOWER_RANGE:
				continue
			var priority: float = distance - (1000 if u.creep else 0)
			if priority < best:
				best = priority
				target = u
		if not target.is_empty():
			apply_damage(target, 55 if target.creep else target.max_hp*0.22, -1, false, "tower")
			tower.cooldown = 1.2
			tower.flash = 0.2
			tower["target_pos"] = target.pos

func select_enemy(u: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_score := INF
	var ally: Dictionary = weakest_ally(u, 250) if not u.creep else {}
	var vault_pos: Vector2 = objective(u).pos
	# Convert lane pressure: once in siege range, only a nearby hero forces
	# a defender to abandon the vault attack. Creeps must not cause endless chasing.
	var siege_window: bool = u.pos.distance_to(vault_pos) <= u.reach + 30
	# In late overtime, commit a successful push instead of repeatedly chasing defenders.
	if siege_window and (clock >= 840 or u.behavior.siege == 5):
		return {}
	for enemy in units:
		if enemy.team == u.team or enemy.hp <= 0 or enemy.lane != u.lane or not enemy.flight.is_empty():
			continue
		if not MapLayout.on_lane(enemy.pos, u.lane):
			continue
		var distance: float = u.pos.distance_to(enemy.pos)
		if siege_window and (enemy.creep or distance > 115):
			continue
		if distance > 200 + u.behavior.pursuit*30:
			continue
		var score: float = distance
		if enemy.creep:
			score -= u.behavior.waveclear*6
		else:
			score -= (u.behavior.pursuit*15 + u.behavior.dueling*8)*(1.0-enemy.hp/enemy.max_hp)
			if not ally.is_empty() and enemy.pos.distance_to(ally.pos) < 160:
				score -= u.behavior.protection*12
		if u.team == 0 and plan == 1 and not enemy.creep:
			score -= 65
		if u.team == 0 and plan == 2 and enemy.creep:
			score -= 45
		score += Kits.target_bias(self, u, enemy)
		if not enemy.creep and in_sunlight(enemy, u.team):
			score -= 40.0 # BEAUTIFUL DAY makes enemies easier to target.
		if score < best_score:
			best_score = score
			best = enemy
	return best

func use_abilities(u: Dictionary, enemy: Dictionary) -> void:
	if u.ability <= 0:
		Kits.signature(self, u, enemy)
	if u.ability2 <= 0 and u.dash.is_empty() and u.flight.is_empty():
		Kits.signature2(self, u, enemy)
	if not u.dash.is_empty() or enemy.is_empty() or enemy.creep or u.pos.distance_to(enemy.pos) > 240:
		return
	if u.portrait == "oddity" and u.encore_cd <= 0 and u.copied_ultimate != "" and u.copy_until > clock:
		u.cast_effect = u.copied_ultimate
		u.copied_ultimate = ""
		u.cast_scale = 0.7
		u.charge = 1.0
		u.charge_target = enemy.id
		u.encore_cd = 105.0
		record_event("encore_cast", u.id, enemy.id, 0.7, {"ability":Catalog.ULTIMATES[u.cast_effect].id, "next_available":clock+105})
		return
	if u.ultimate > 0:
		return
	if Kits.ultimate_held(self, u, enemy):
		return
	if assignment == 2 and u.team == 0 and enemy.hp/enemy.max_hp > 0.65:
		return
	u.cast_effect = u.portrait
	u.cast_scale = 1.0
	u.charge = Catalog.ULTIMATES[u.portrait].windup
	u.charge_target = enemy.id
	begin_ultimate(u, enemy)
	log_event("Ultimate windup", u.name + " prepares " + Catalog.ULTIMATES[u.cast_effect].id + ".", "charge", u.id)

func resolve_ultimate(u: Dictionary, _enemy: Dictionary) -> void:
	var effect: String = u.cast_effect
	if not Catalog.ULTIMATES.has(effect) or u.hp <= 0:
		return
	var data: Dictionary = Catalog.ULTIMATES[effect]
	var damage: float = (data.damage+data.per_level*u.level)*u.cast_scale
	Kits.resolve(self, u, effect, damage)
	log_event(data.id, u.name + " releases " + data.id + ".", "ultimate_release", u.id)

func area_hit(u: Dictionary, position: Vector2, radius: float, damage: float) -> void:
	for target in units:
		if target.team != u.team and target.hp > 0 and target.pos.distance_to(position) < radius:
			apply_damage(target, damage*crown_multiplier(u), u.id, false, "ability")
	u.flash = 0.3

func heal(source: Dictionary, target: Dictionary, amount: float, redirect: bool = true) -> void:
	if target.hp <= 0 or intermission.time > 0:
		return
	for field in fields:
		if field.kind == "gas" and field.team != target.team and field.time > 0 and target.pos.distance_to(field.pos) < field.radius:
			amount *= 0.8
			break
	if redirect and target.healing_mark_until > clock:
		var vampire := get_unit(target.healing_mark)
		if not vampire.is_empty() and vampire.hp > 0 and vampire.blood_rush > 0:
			var stolen: float = amount*0.35
			amount -= stolen
			heal(vampire, vampire, stolen, false)
			record_event("healing_redirect", vampire.id, target.id, stolen)
	var before: float = target.hp
	target.hp = minf(target.max_hp, target.hp+amount)
	source.healing_done += target.hp-before
	if target.hp > before:
		record_event("heal", source.id, target.id, target.hp-before)
	if before/target.max_hp < 0.2 and target.hp/target.max_hp >= 0.2:
		log_event("BACK FROM THE BRINK", target.name + " steals another chance to survive.", "clutch", target.id)

func steal(u: Dictionary, enemy: Dictionary, grand: bool) -> void:
	Kits.steal(self, u, enemy, grand)

func update_fields(dt: float) -> void:
	for field in fields:
		var owner := get_unit(field.source)
		# Moving gas ends with its owner; anchored fire and sunlight stay until they expire.
		if owner.is_empty() or (owner.hp <= 0 and not field.anchored):
			field.time = 0.0
			continue
		if not field.anchored:
			field.pos = owner.pos
		field.time -= dt
		field.tick -= dt
		if field.tick > 0 or field.time <= 0:
			continue
		field.tick = 0.5
		for target in units:
			if target.hp <= 0 or not target.flight.is_empty() or target.pos.distance_to(field.pos) >= field.radius:
				continue
			if target.team == field.team:
				if field.kind == "sun" and not target.creep:
					heal(owner, target, target.max_hp*0.015)
				continue
			var before: float = target.hp
			apply_damage(target, field.damage*crown_multiplier(owner), field.source, field.overload, "magic")
			if field.overload:
				heal(owner, owner, maxf(0,before-target.hp)*0.3)
	fields = fields.filter(func(field): return field.time > 0)

func in_sunlight(target: Dictionary, sun_team: int) -> bool:
	for field in fields:
		if field.kind == "sun" and field.team == sun_team and target.pos.distance_to(field.pos) < field.radius:
			return true
	return false

## True when an enemy hero is currently trading blows with a hero of `team`.
func fighting_team(enemy: Dictionary, team: int) -> bool:
	var attacker := get_unit(enemy.last_attacker)
	if not attacker.is_empty() and attacker.team == team and not attacker.creep and clock-enemy.last_hit < 3.0:
		return true
	for ally in units:
		if ally.team == team and not ally.creep and ally.hp > 0 and ally.last_attacker == enemy.id and clock-ally.last_hit < 3.0:
			return true
	return false

## Pushes a unit away from origin, scaled by Stability. Being stopped by the
## lane edge counts as a wall collision.
func knockback(target: Dictionary, origin: Vector2, distance: float, source_id: int) -> void:
	if target.hp <= 0 or not target.flight.is_empty() or intermission.time > 0:
		return
	var push: float = distance*(Kits.knockback_scale(self, target) if not target.creep else 1.0)
	if push < 1.0:
		return
	var direction: Vector2 = origin.direction_to(target.pos)
	if direction == Vector2.ZERO:
		direction = MapLayout.forward(target.pos, target.lane, 1-target.team)
	var wanted: Vector2 = target.pos+direction*push
	var landed: Vector2 = MapLayout.constrain(wanted, target.lane)
	target.pos = landed
	if target.creep:
		return
	record_event("knockback", source_id, target.id, push)
	Kits.on_displaced(self, target, push, "knockback")
	var blocked: float = wanted.distance_to(landed)
	if blocked >= 18.0:
		wall_slam(target, source_id, blocked)

func wall_slam(target: Dictionary, source_id: int, force: float) -> void:
	var sturdy: bool = Kits.built_for_crashes(self, target)
	var damage: float = target.max_hp*(0.01 if sturdy else 0.03)
	record_event("wall_slam", source_id, target.id, force)
	if sturdy or force >= 30.0:
		log_event("WALL SLAM", target.name + " hits the wall.", "wall_slam", target.id)
	apply_damage(target, damage, source_id, false, "collision")
	target.stun = maxf(target.stun, 0.5 if sturdy else 0.25)
	if sturdy:
		for enemy in units:
			if enemy.team != target.team and not enemy.creep and enemy.hp > 0 and enemy.pos.distance_to(target.pos) < 70:
				stagger(enemy, 0.4)
	Kits.on_displaced(self, target, force, "wall hit")

func fire(u: Dictionary, enemy: Dictionary, damage: float, ultimate: bool) -> void:
	if intermission.time > 0 or u.hp <= 0:
		return
	u.attacks += 1
	var base: float = damage if ultimate else power(u)
	if u.jungle_buff > 0 and u.buff_kind == "power":
		base *= 1.2
	base *= crown_multiplier(u)
	var data: Dictionary = Catalog.HEROES.get(u.portrait, {})
	if not ultimate and not u.creep and data.get("projectile",0.0) == 0:
		u.swing = data.windup
		melee_swings.append({"source":u.id,"target":enemy.id,"time":u.swing,"damage":base,"angle":u.pos.angle_to_point(enemy.pos)})
		record_event("melee_windup", u.id, enemy.id, base)
		return
	record_event("projectile_fired", u.id, enemy.id, base, {"ability": u.cast_effect if ultimate else "attack"})
	var shot := launch(u, u.pos.direction_to(enemy.pos), base, 520.0 if ultimate else data.get("projectile", 390.0), ultimate)
	if not ultimate:
		shot.life = data.get("shot_life", 1.2)
		shot.splash = data.get("splash", 0.0)

## Projectiles fly straight and can miss; ultimate shots have a slightly wider hitbox.
func launch(u: Dictionary, direction: Vector2, damage: float, speed: float, ultimate: bool = true) -> Dictionary:
	var shot := {"pos":u.pos+direction*(u.radius+2), "direction":direction,
		"team":u.team,"source":u.id,"damage":damage,"ultimate":ultimate,
		"life":1.2,"speed":speed,"kind":"bolt","splash":0.0,"knock":0.0,"explode_on_expire":false}
	shots.append(shot)
	u.flash = 0.15
	return shot

## Sunday's Flare: a huge, very slow orb that bursts where the target stood,
## or earlier if someone walks into it.
func launch_orb(u: Dictionary, target_pos: Vector2, damage: float) -> void:
	var shot := launch(u, u.pos.direction_to(target_pos), damage, 95.0)
	shot.kind = "orb"
	shot.splash = 80.0
	shot.knock = 45.0
	shot.explode_on_expire = true
	shot.life = maxf(0.3, (u.pos.distance_to(target_pos)-u.radius-2)/95.0)
	record_event("projectile_fired", u.id, -1, damage, {"ability": "Flare"})

func update_shots(dt: float) -> void:
	for shot in shots:
		var before: Vector2 = shot.pos
		shot.pos += shot.direction * shot.speed * dt
		shot.life -= dt
		var victim: Dictionary = {}
		var nearest := INF
		for u in units:
			if u.team == shot.team or u.hp <= 0 or not u.flight.is_empty():
				continue
			var point := Geometry2D.get_closest_point_to_segment(u.pos, before, shot.pos)
			var radius: float = u.radius + (16.0 if shot.kind == "orb" else 0.0)
			if point.distance_to(u.pos) < radius + (8 if shot.ultimate else 3):
				var distance: float = before.distance_to(point)
				if distance < nearest:
					nearest = distance
					victim = u
		if not victim.is_empty():
			record_event("projectile_hit", shot.source, victim.id, shot.damage, {"ability": "Flare" if shot.kind == "orb" else ""})
			if shot.kind != "orb":
				apply_damage(victim, shot.damage, shot.source, shot.ultimate, "ability" if shot.ultimate else "basic")
			if shot.splash > 0:
				explode(shot, victim.pos, victim.id)
			shot.life = 0
		elif shot.life <= 0:
			if shot.explode_on_expire:
				explode(shot, shot.pos, -1)
			else:
				record_event("projectile_miss", shot.source)
	shots = shots.filter(func(s): return s.life > 0)

## Splash on impact. Orbs (Flare) deal full damage in the whole radius, knock back
## and leave a brief burn; Sunbeam splash deals half damage around the victim.
func explode(shot: Dictionary, center: Vector2, victim_id: int) -> void:
	var owner := get_unit(shot.source)
	var hits := 0
	for target in units:
		if target.team == shot.team or target.hp <= 0 or not target.flight.is_empty() or target.pos.distance_to(center) > shot.splash:
			continue
		if shot.kind == "orb":
			apply_damage(target, shot.damage, shot.source, false, "ability")
			if shot.knock > 0:
				knockback(target, center, shot.knock, shot.source)
		elif target.id != victim_id:
			apply_damage(target, shot.damage*0.5, shot.source, false, "splash")
		if not target.creep:
			hits += 1
	if shot.kind == "orb":
		record_event("flare_burst", shot.source, victim_id, hits, {"ability": "Flare", "detail": "hit" if hits > 0 else "miss"})
		if not owner.is_empty():
			fields.append({"kind": "fire", "anchored": true, "pos": center, "source": shot.source, "team": shot.team, "time": 2.0,
				"tick": 0.0, "radius": 55.0, "overload": false, "damage": 6.0+owner.level})

func apply_damage(target: Dictionary, amount: float, source_id: int, ultimate: bool = false, kind: String = "ability", transferred: bool = false) -> void:
	if target.hp <= 0 or intermission.time > 0 or not target.flight.is_empty():
		return
	var attacker := get_unit(source_id)
	if not transferred and not attacker.is_empty() and attacker.team != target.team and attacker.blood_rush > 0:
		target.healing_mark = attacker.id
		target.healing_mark_until = clock+3.0
	# One protector absorbs a portion; transferred damage cannot recurse.
	if not transferred:
		for ally in units:
			if ally.id != target.id and ally.hp > 0 and ally.team == target.team and ally.hold_line > 0 and can_protect(ally,target) and ally.pos.distance_to(target.pos) < 140:
				var share: float = amount*0.35
				amount -= share
				apply_damage(ally, share, source_id, ultimate, kind, true)
				record_event("damage_intercepted", ally.id, target.id, share)
				break
	var defense: float = target.resolve + Kits.resolve_bonus(self, target) if kind in ["magic", "ability", "splash"] else target.armor + Kits.armor_bonus(self, target)
	if target.overpressure > 0 and kind in ["magic","ability"]:
		defense += 65
	if target.hold_line > 0:
		defense += 100
	amount *= 100.0/(100.0+defense) if defense >= 0 else 2.0-100.0/(100.0-defense)
	target.last_hit = clock
	target.last_attacker = source_id
	var absorbed := minf(target.shield, amount)
	target.shield -= absorbed
	amount -= absorbed
	var hp_before: float = target.hp
	target.hp = maxf(0, target.hp-amount)
	var actual: float = hp_before-target.hp
	record_event("damage", source_id, target.id, actual, {"damage_type":kind,"absorbed":absorbed})
	if not target.creep:
		Kits.on_damaged(self, target, actual, absorbed, source_id)
	if not attacker.is_empty() and attacker.team != target.team:
		attacker.damage_done += actual
		if kind == "basic" and attacker.portrait == "irene":
			heal(attacker, attacker, actual*(0.5 if attacker.blood_rush > 0 else 0.25))
	if target.hp > 0:
		return
	var source := get_unit(source_id)
	if crown.holder == target.id:
		drop_crown(target, source_id)
	if target.ultimate > 0 and target.ultimate_cooldown > 0:
		record_event("ultimate_death", target.id, source_id, target.ultimate)
	if not source.is_empty() and crown.holder == source.id and not target.creep:
		crown.kills += 1
		record_event("crown_kill", source.id, target.id, crown.kills)
	target.deaths += 1
	target.blood_rush = 0.0
	target.hold_line = 0.0
	target.overpressure = 0.0
	target.dash.clear()
	target.larceny.clear()
	Kits.on_death(self, target)
	update_loans()
	target.charge = 0.0
	target.jungle_buff = 0.0
	if not source.is_empty() and not target.creep:
		source.kills += 1
	if not target.creep:
		target.respawn = minf(45, 16 + clock / 35)
		if source_id != -2:
			kills[1 - target.team] += 1
	if source_id != -2:
		economies[1 - target.team].earn_bounty(target.creep)
	if not target.creep:
		var killer: String = source.name if not source.is_empty() else ("A jungle guardian" if source_id == -2 else "An attack")
		log_event(target.name + " falls", killer + " earns a takedown. Respawn in %ds." % int(target.respawn), "kill", target.id)
		if ultimate and not source.is_empty() and source.clutch_until >= clock and source.hp > 0:
			log_event("THE LAST SHOT", source.name + " turns the fight with a last shot.", "clutch", source.id)
	for ally in units:
		if ally.team != target.team and not ally.creep and ally.hp > 0 and ally.pos.distance_to(target.pos) < 320:
			grant_xp(ally, 1 if target.creep else 3)

func grant_xp(ally: Dictionary, amount: int) -> void:
	ally.xp += amount
	while ally.xp >= ally.level*Catalog.XP_PER_LEVEL and ally.level < Catalog.MAX_LEVEL:
		ally.level += 1
		ally.max_hp += Catalog.GROWTH[ally.portrait][0]*HERO_HEALTH_SCALE
		ally.hp += Catalog.GROWTH[ally.portrait][0]*HERO_HEALTH_SCALE
		ally.damage += Catalog.GROWTH[ally.portrait][1]
		if ally.portrait == "colony":
			ally.radius = MapLayout.HERO_RADIUS + floorf((ally.level-1)/2.0)*3.5
		log_event(ally.name + "  -  level %d" % ally.level, "More health and stronger basic attacks.", "level", ally.id)

func update_camps(dt: float) -> void:
	for camp in camps:
		camp.cooldown = maxf(0, camp.cooldown-dt)
		if camp.hp <= 0:
			camp.respawn -= dt
			if camp.respawn <= 0:
				camp.hp = camp.max_hp
				if camp.kind == "node":
					log_event("POWER NODE ONLINE", "Midgame objective: clear it for 90s of empowered waves and team XP.", "node_spawn")
		elif clock-camp.last_hit > 6:
			camp.hp = minf(camp.max_hp, camp.hp+25*dt)

func farm_camp(u: Dictionary, dt: float) -> bool:
	if u.camp_target < 0:
		return false
	var camp: Dictionary = camps[u.camp_target]
	if camp.hp <= 0 or u.hp/u.max_hp < 0.3:
		u.camp_target = -1
		return false
	u.intent = "Jungle  -  " + camp.name
	if camp.kind == "node":
		var opponent: Dictionary = {}
		for enemy in units:
			if enemy.team != u.team and not enemy.creep and enemy.hp > 0 and enemy.flight.is_empty() and enemy.pos.distance_to(u.pos) < 240 and enemy.pos.distance_to(camp.pos) < 300:
				opponent = enemy
				break
		if not opponent.is_empty():
			u.intent = "Fight / contest the power node"
			use_abilities(u, opponent)
			if u.charge > 0 or not u.flight.is_empty() or not u.dash.is_empty():
				return true
			if u.pos.distance_to(opponent.pos) > u.reach:
				u.pos = u.pos.move_toward(opponent.pos, movement_speed(u, opponent.pos)*dt)
			elif u.cooldown <= 0:
				fire(u, opponent, u.damage, false)
				u.cooldown = attack_interval(u)
			return true
	u.facing = u.pos.angle_to_point(camp.pos)
	if u.pos.distance_to(camp.pos) > 70:
		u.pos = u.pos.move_toward(camp.pos, u.speed*dt)
		return true
	if u.cooldown <= 0:
		var damage: float = power(u) * crown_multiplier(u) * (1.2 if u.jungle_buff > 0 and u.buff_kind == "power" else 1.0)
		var dealt: float = minf(camp.hp, damage)
		u.attacks += 1
		camp.hp = maxf(0, camp.hp-damage)
		if camp.kind == "node":
			record_event("node_damage", u.id, -1, dealt, {"remaining_hp": camp.hp})
		camp.last_hit = clock
		u.cooldown = attack_interval(u)
		u.flash = 0.2
		if camp.hp <= 0:
			if camp.kind == "node":
				camp.respawn = NODE_RESPAWN
				empowered_until[u.team] = clock + NODE_BUFF
				for ally in units:
					if ally.team == u.team and not ally.creep:
						grant_xp(ally, 12)
				log_event("POWER NODE CLAIMED", u.name + " earns team XP and 90s of empowered waves.", "node_capture", u.id)
				u.camp_target = -1
				return true
			camp.respawn = 75.0
			grant_xp(u, 6)
			u.jungle_buff = 45.0
			u.buff_kind = camp.kind
			u.camp_target = -1
			log_event("CAMP CLEARED", u.name + " gains 6 XP and 45s of " + ("+20% attack damage." if camp.kind == "power" else "+3 health per second."), "jungle", u.id)
			return true
	if camp.cooldown <= 0:
		apply_damage(u, 45.0 if camp.kind == "node" else 9.0, -2)
		camp.cooldown = 1.5
	return true

func log_event(title: String, detail: String, kind: String, actor: int = -1) -> void:
	record_event(kind, actor, -1, 0, {"detail": detail})
	events.append({"time": clock, "title": title, "detail": detail, "kind": kind, "actor": actor})

func snapshot() -> void:
	history.append({"time": clock, "units": units.duplicate(true), "shots": shots.duplicate(true), "vaults": vaults.duplicate(), "winner": winner, "kills": kills.duplicate(), "towers": towers.duplicate(true), "camps": camps.duplicate(true), "crown": crown.duplicate(true), "fields": fields.duplicate(true), "thefts":thefts.duplicate(true), "intermission":intermission.duplicate(true), "empowered_until": empowered_until.duplicate(), "logistics": logistics_state()})
	# About 30 seconds of replay, bounded even during long battles.
	if history.size() > 210:
		history.pop_front()

func frame() -> Dictionary:
	return {"time": clock, "units": units, "shots": shots, "vaults": vaults, "winner": winner, "kills": kills, "towers": towers, "camps": camps, "crown": crown, "fields": fields, "thefts":thefts, "intermission":intermission, "empowered_until": empowered_until, "logistics": logistics_state()}

func duel_move(u: Dictionary, enemy: Dictionary, dt: float) -> void:
	if Kits.holds_ground(self, u):
		return # Heavy melee commits to its swing; carries provide evasive footwork.
	# Seed-independent, fixed-step footwork: ranged heroes strafe, brawlers circle.
	var away: Vector2 = enemy.pos.direction_to(u.pos)
	if away == Vector2.ZERO:
		away = MapLayout.forward(u.pos, u.lane, u.team)
	var desired: float = maxf(u.radius+enemy.radius+8, u.reach*Kits.preferred_range(self, u))
	var gap: float = u.pos.distance_to(enemy.pos)
	var radial := clampf((desired-gap)/45.0, -0.6, 0.8)
	var motion: Vector2 = away.orthogonal()*u.orbit_sign + away*radial
	var next: Vector2 = u.pos + motion.normalized()*movement_speed(u, u.pos+motion)*0.8*dt
	if not MapLayout.on_lane(next, u.lane) or MapLayout.project(next, u.lane).distance > MapLayout.ROAD_HALF_WIDTH-4:
		u.orbit_sign *= -1
		motion = away.orthogonal()*u.orbit_sign + away*radial
		next = u.pos + motion.normalized()*movement_speed(u, u.pos+motion)*0.8*dt
	u.pos = MapLayout.constrain(next, u.lane)
	u.intent = ("Circle " if u.reach < 130 else "Strafe ") + enemy.name
	# React only to a visible shot already in flight; dodges have a cooldown.
	if u.dodge_cd > 0:
		return
	for shot in shots:
		if shot.team == u.team:
			continue
		var offset: Vector2 = u.pos-shot.pos
		var ahead: float = offset.dot(shot.direction)
		var miss: float = absf(offset.cross(shot.direction))
		if ahead > 30 and ahead < 135 and miss < u.radius+8:
			var sidestep: Vector2 = shot.direction.orthogonal()*u.orbit_sign
			var target: Vector2 = MapLayout.constrain(u.pos+sidestep*32, u.lane)
			if target.distance_to(u.pos) < 12:
				target = MapLayout.constrain(u.pos-sidestep*32, u.lane)
			u.pos = u.pos.move_toward(target, 26)
			u.dodge_cd = 5.0-u.behavior.dueling*0.3
			u.intent = "Sidestep incoming fire"
			break

func update_ultimate(u: Dictionary, dt: float) -> void:
	if u.ultimate_cooldown <= 0 or u.ultimate <= 0:
		return
	u.ultimate = maxf(0, u.ultimate-dt)
	if u.ultimate == 0:
		u.available_since = clock
		log_event("Ultimate ready", u.name + " can use " + Catalog.ULTIMATES[u.portrait].id + ".", "ultimate_available", u.id)

func begin_ultimate(u: Dictionary, target: Dictionary) -> void:
	u.ultimate = u.ultimate_cooldown
	for witness in units:
		if witness.portrait == "oddity" and witness.hp > 0 and witness.id != u.id and witness.pos.distance_to(u.pos) < 350 and u.cast_effect != "":
			witness.copied_ultimate = u.cast_effect
			witness.copy_until = clock+40.0
			log_event("ENCORE LEARNED", witness.name + " witnesses " + Catalog.ULTIMATES[u.cast_effect].id + ".", "copy", witness.id)
	record_event("ultimate_cast", u.id, target.id, u.ultimate, {"ability": Catalog.ULTIMATES[u.portrait].id, "next_available": clock+u.ultimate, "held_seconds": maxf(0, clock-u.available_since)})

func record_event(kind: String, actor: int = -1, target: int = -1, value: float = 0, extra: Dictionary = {}) -> void:
	var u := get_unit(actor)
	var recipient := get_unit(target)
	Expressions.record(kind, u, recipient, value, clock)
	var row := {"match_id": match_id, "time": clock, "kind": kind, "actor": actor, "target": target, "value": value, "x": u.pos.x if not u.is_empty() else 0.0, "y": u.pos.y if not u.is_empty() else 0.0}
	row["actor_hero"] = u.get("portrait", "")
	row["actor_team"] = u.get("team", -1)
	row["actor_level"] = u.get("level", 0)
	row["target_hero"] = recipient.get("portrait", "")
	row["reason"] = u.get("intent", "")
	row.merge(extra, true)
	records.append(row)

func crown_multiplier(u: Dictionary) -> float:
	return 2.0 if crown.holder == u.id else 1.0

func update_crown() -> void:
	if not crown.spawned:
		if clock < 120:
			return
		crown.spawned = true
		log_event("DOUBLE DAMAGE IDOL", "An idol appears in the jungle. Its carrier deals double damage.", "crown_spawn")
	if crown.holder >= 0:
		var holder := get_unit(crown.holder)
		if not holder.is_empty():
			crown.pos = holder.pos
		return
	var closest: Dictionary = {}
	var distance := 46.0
	for u in units:
		if u.creep or u.hp <= 0:
			continue
		var gap: float = u.pos.distance_to(crown.pos)
		if gap < distance:
			closest = u
			distance = gap
	if not closest.is_empty():
		crown.holder = closest.id
		crown.pos = closest.pos
		crown.since = clock
		crown.kills = 0
		log_event("IDOL CLAIMED", closest.name + " takes the Double Damage Idol. Double damage until death.", "crown_pickup", closest.id)

func drop_crown(u: Dictionary, killer: int) -> void:
	record_event("crown_possession", u.id, killer, crown.kills, {"held_seconds": clock-crown.since})
	crown.holder = -1
	crown.pos = u.pos
	log_event("IDOL DROPPED", u.name + " falls. The Double Damage Idol waits for a new carrier.", "crown_drop", u.id)

func export_csv(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var columns := PackedStringArray(["match_id", "time", "kind", "actor", "target", "value", "x", "y", "ability", "next_available", "held_seconds", "detail", "actor_hero", "actor_team", "actor_level", "target_hero", "reason", "item", "damage_type", "absorbed", "from", "to", "nearby_enemies", "nearby_allies", "remaining_hp"])
	file.store_csv_line(columns)
	for row in records:
		var cells := PackedStringArray()
		for column in columns:
			cells.append(str(row.get(column, "")))
		file.store_csv_line(cells)
	return OK

func can_protect(source: Dictionary, target: Dictionary) -> bool:
	return not (source.portrait == "oddity" and target.portrait == "irene")

func slot_stolen(owner: int, slot: int) -> bool:
	for loan in thefts:
		if loan.owner == owner and loan.slot == slot and loan.until > clock:
			return true
	return false

func effective_items(u: Dictionary) -> Array:
	var result: Array = []
	for slot in range(u.items.size()):
		if not slot_stolen(u.id, slot):
			result.append(u.items[slot])
	for loan in thefts:
		if loan.thief == u.id and loan.until > clock and loan.item not in result:
			result.append(loan.item)
	return result

func has_item(u: Dictionary, item: String) -> bool:
	return item in effective_items(u)

func item_value(u: Dictionary) -> float:
	var total := 0.0
	for item in effective_items(u):
		total += ShopManager.item_cost(item)
	return total

func power(u: Dictionary) -> float:
	return u.damage

func attack_interval(u: Dictionary) -> float:
	return u.attack_interval/(1.65 if u.blood_rush > 0 else 1.0)

func movement_speed(u: Dictionary, destination: Vector2) -> float:
	var value: float = u.speed*(1.35 if u.blood_rush > 0 else 1.0)*(0.2 if u.hold_line > 0 else 1.0)*Kits.speed_scale(self, u)
	return value

# --- Remote shop and courier delivery -----------------------------------------

## Passive income, then each team's drone advances one tick. Deliveries only
## touch HeroInventory, so the shop and drone never edit hero stats directly.
func update_logistics(dt: float) -> void:
	for team in range(2):
		economies[team].tick(dt)
		shops[team].tick(self, dt)
		couriers[team].update(self, shops[team], dt)

## Called by UI (or the rival auto-buyer) through the team's ShopManager.
func request_purchase(team: int, hero_id: int, item: String) -> Dictionary:
	return shops[team].request_purchase(self, hero_id, item)

func logistics_state() -> Dictionary:
	return {"economy": economies.map(func(e): return e.to_dict()),
		"couriers": couriers.map(func(c): return c.to_dict()),
		"queues": shops.map(func(q): return q.to_dict())}

func update_loans() -> void:
	for loan in thefts:
		var owner := get_unit(loan.owner)
		var thief := get_unit(loan.thief)
		if loan.until <= clock or owner.is_empty() or thief.is_empty() or owner.hp <= 0 or thief.hp <= 0:
			loan.until = 0.0
			record_event("item_returned",loan.thief,loan.owner,0,{"item":loan.item})
	thefts = thefts.filter(func(loan): return loan.until > clock)
	for loan in health_loans:
		var owner := get_unit(loan.owner)
		var thief := get_unit(loan.thief)
		if loan.until <= clock or owner.is_empty() or thief.is_empty() or owner.hp <= 0 or thief.hp <= 0:
			if not owner.is_empty():
				owner.max_hp += loan.amount
			if not thief.is_empty():
				thief.max_hp = maxf(1,thief.max_hp-loan.amount)
				thief.hp = minf(thief.hp,thief.max_hp)
			loan.until = 0.0
			record_event("health_returned",loan.thief,loan.owner,loan.amount)
	health_loans = health_loans.filter(func(loan): return loan.until > clock)

func update_dash(u: Dictionary, dt: float) -> void:
	Kits.update_dash(self, u, dt)

func update_larceny(u: Dictionary, dt: float) -> void:
	Kits.update_larceny(self, u, dt)

func update_melee(dt: float) -> void:
	for swing in melee_swings:
		swing.time -= dt
		if swing.time > 0:
			continue
		var u := get_unit(swing.source)
		if u.is_empty() or u.hp <= 0 or u.stun > 0:
			continue
		var hit := false
		for target in units:
			if target.team == u.team or target.hp <= 0 or target.pos.distance_to(u.pos) > u.reach+target.radius:
				continue
			var cleave: bool = Kits.melee_cleaves(self, u)
			if not cleave and target.id != swing.target:
				continue
			if cleave and absf(angle_difference(swing.angle,u.pos.angle_to_point(target.pos))) > PI*0.45:
				continue
			# Roll once per swing, even for Eleanor's cleave.
			apply_damage(target,swing.damage,u.id,false,"melee_basic")
			Kits.on_melee_hit(self, u, target)
			record_event("melee_hit",u.id,target.id,swing.damage)
			hit = true
		if not hit:
			record_event("melee_miss",u.id,swing.target)
		u.flash = 0.18
	melee_swings = melee_swings.filter(func(swing): return swing.time > 0)
