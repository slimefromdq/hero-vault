extends Node2D
## A clipped, presentation-only camera. Coordinates never feed back into combat.
const MapLayout = preload("res://scripts/map_layout.gd")
const WORLD_SCALE := 0.328
const Battle = preload("res://scripts/battle.gd")
const INK := Color("0a1220")
const PANEL := Color("111e30")
const BORDER := Color("28394e")
const TEXT := Color("e4ebf3")
const MUTED := Color("8d9fb7")
const GOLD := Color("ffd387")
const BLUE := Color("83bbff")
const RED := Color("f49bae")
const GREEN := Color("8cddc6")
const SUN := Color("ffe08a")

var host: Node2D
var font: Font = ThemeDB.fallback_font
var portraits: Dictionary = {}
var camera_center := Vector2(713.5, 419)
var camera_zoom := 1.0
const VIEW_CENTER := Vector2(391.5, 205)

func update_camera(delta: float, snap: bool = false) -> void:
	var target := Vector2(713.5, 419)
	var zoom_target := 1.0
	if host.follow_hero >= 0 and not host.battles.is_empty():
		var frame: Dictionary = host.display_frame()
		var hero: Dictionary = frame.units[host.follow_hero]
		target = arena_point(hero.pos)
		zoom_target = host.focus_zoom
	var weight := 1.0 if snap else 1.0 - exp(-8.0 * delta)
	camera_center = camera_center.lerp(target, weight)
	camera_zoom = lerpf(camera_zoom, zoom_target, weight)
	queue_redraw()

func project_point(world_position: Vector2) -> Vector2:
	return VIEW_CENTER + (arena_point(world_position) - camera_center) * camera_zoom

func arena_point(pos: Vector2) -> Vector2:
	return Vector2(713.5, 419) + (pos - MapLayout.JUNGLE_CENTER) * WORLD_SCALE

func panel_style(color: Color, radius: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	return style

func label_at(value: String, pos: Vector2, size: int = 16, color: Color = TEXT) -> void:
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func box(rect: Rect2, color: Color = PANEL, radius: int = 12) -> void:
	draw_style_box(panel_style(color, radius), rect)

func bar(rect: Rect2, fraction: float, color: Color) -> void:
	draw_style_box(panel_style(Color("263345"), 3), rect)
	if fraction > 0:
		draw_style_box(panel_style(color, 3), Rect2(rect.position, Vector2(rect.size.x * clampf(fraction, 0, 1), rect.size.y)))


func _draw() -> void:
	if host == null or host.battles.is_empty():
		return
	var frame: Dictionary = host.display_frame()
	draw_rect(Rect2(0, 0, 783, 410), Color("101c2a"))
	draw_set_transform(VIEW_CENTER - camera_center * camera_zoom, 0, Vector2.ONE * camera_zoom)
	draw_terrain()
	for field in frame.get("fields", []):
		# Red = Hazmat gas (also cuts healing); orange = fire; gold = BEAUTIFUL DAY.
		var kind: String = field.get("kind", "gas")
		if kind == "sun":
			var glow := arena_point(field.pos)
			draw_circle(glow, field.radius*WORLD_SCALE, Color(SUN, 0.16))
			draw_circle(glow, field.radius*WORLD_SCALE*0.67, Color(1, 1, 0.9, 0.08))
			draw_arc(glow, field.radius*WORLD_SCALE, 0, TAU, 64, SUN, 3, true)
			label_at("BEAUTIFUL DAY", glow+Vector2(-40, -field.radius*WORLD_SCALE-6), 10, SUN)
			continue
		var tint := Color("f08a3c") if kind == "fire" else Color("e15b62")
		draw_circle(arena_point(field.pos), field.radius*WORLD_SCALE, Color(tint, 0.2))
		draw_arc(arena_point(field.pos), field.radius*WORLD_SCALE, 0, TAU, 48, tint, 2, true)
	draw_camps(frame)
	draw_crown(frame)
	for tower in frame.towers:
		var center := arena_point(tower.pos)
		var color := BLUE if tower.team == 0 else RED
		if tower.hp <= 0:
			draw_arc(center, 19, 0, TAU, 6, Color("53616c"), 3, true)
			draw_line(center-Vector2(10, 10), center+Vector2(10, 10), Color("53616c"), 4)
			continue
		draw_circle(center+Vector2(0, 4), 27, Color(0, 0, 0, 0.25))
		draw_circle(center, 24, Color("303a46"))
		draw_arc(center, 24, 0, TAU, 8, Color("89919a"), 5, true)
		draw_circle(center, 8, color)
		draw_arc(center, 14, 0, TAU, 32, Color(color, 0.3), 1, true)
		bar(Rect2(center+Vector2(-25, 30), Vector2(50, 5)), tower.hp/tower.max_hp, color)
		if tower.flash > 0 and tower.has("target_pos"):
			draw_line(center, arena_point(tower.target_pos), Color(color, 0.65), 2, true)
	for team in range(2):
		var center := arena_point(MapLayout.BASES[team])
		var color := BLUE if team == 0 else RED
		draw_circle(center, 44, Color(color, 0.06))
		var core := PackedVector2Array()
		if team == 0:
			for i in range(10):
				core.append(center+Vector2.from_angle(-PI/2+i*PI/5)*(29 if i%2 == 0 else 13))
		else:
			for offset in [Vector2(-23, -8), Vector2(-19, -21), Vector2(-8, -23), Vector2(0, -13), Vector2(8, -23), Vector2(19, -21), Vector2(23, -8), Vector2(19, 6), Vector2(0, 28), Vector2(-19, 6)]:
				core.append(center+offset)
		draw_colored_polygon(core, color.darkened(0.6))
		core.append(core[0])
		draw_polyline(core, color, 4, true)
		label_at("BLUE VAULT" if team == 0 else "RED VAULT", center+Vector2(-34, -43), 10, color)
		bar(Rect2(center+Vector2(-35, 44), Vector2(70, 6)), frame.vaults[team]/Battle.VAULT_HP, color)
		label_at("%d" % frame.vaults[team], center+Vector2(-17, 62), 11, color)
	for u in frame.units:
		if u.hp > 0:
			if u.get("camp_target", -1) >= 0 and u.flash > 0:
				var camp: Dictionary = frame.camps[u.camp_target]
				if u.pos.distance_to(camp.pos) <= 75:
					draw_line(arena_point(u.pos), arena_point(camp.pos), GOLD, 4, true)
			draw_unit(u, frame.time, frame.winner)
	for shot in frame.shots:
		var p := arena_point(shot.pos)
		var color := GOLD if shot.ultimate else (BLUE if shot.team == 0 else RED)
		if shot.get("kind", "bolt") == "orb":
			# Flare: big, slow and easy to read.
			draw_circle(p, 24, Color(SUN, 0.18))
			draw_circle(p, 13, SUN)
			continue
		if shot.get("splash", 0.0) > 0:
			draw_circle(p, 7, Color(SUN, 0.35))
			draw_circle(p, 4, SUN)
			continue
		draw_line(p - shot.direction * (28 if shot.ultimate else 12), p, color, 7 if shot.ultimate else 3, true)
		if shot.ultimate:
			draw_circle(p, 13, Color(GOLD, 0.15))

	if host.follow_hero >= 0:
		var hero: Dictionary = frame.units[host.follow_hero]
		if hero.hp <= 0:
			var marker := arena_point(hero.pos)
			draw_arc(marker, 34, 0, TAU, 48, MUTED, 2, true)
			label_at("RETURNING IN %ds" % int(ceil(hero.respawn)), marker + Vector2(-55, 4), 12, GOLD)
	draw_set_transform(Vector2(-322, -214))
	if frame.get("intermission",{}).get("time",0) > 0:
		label_at("INTERMISSION / COMBAT FROZEN",Vector2(570,260),16,Color("dfbcff"))
	if frame.time < Battle.NODE_SPAWN:
		label_at("EARLY GAME / LANES", Vector2(338, 229), 11, MUTED)
	elif frame.time < 720:
		label_at("MIDGAME / CONTEST POWER NODE", Vector2(338, 229), 11, GOLD)
	if frame.time >= 720:
		label_at("OVERTIME / VAULT DEFENSES WEAKENING", Vector2(338, 229), 11, GOLD)
	for team in range(2):
		var remaining: float = frame.get("empowered_until", [0.0, 0.0])[team]-frame.time
		if remaining > 0:
			label_at(("BLUE" if team == 0 else "RED")+" EMPOWERED WAVES / %ds" % int(ceil(remaining)), Vector2(338+team*375, 608), 11, BLUE if team == 0 else RED)
	if frame.winner != -1:
		box(Rect2(526, 356, 375, 105), Color("101b2b"))
		label_at("VICTORY" if frame.winner == 0 else "DEFEAT", Vector2(624, 402), 29, GREEN if frame.winner == 0 else RED)
		label_at("The vault has fallen. The story stays.", Vector2(569, 432), 14, MUTED)

func draw_terrain() -> void:
	var outer := panel_style(Color("16242b"), 35)
	outer.border_color = Color("66716e")
	outer.set_border_width_all(2)
	draw_style_box(outer, Rect2(arena_point(MapLayout.BOUNDS.position), MapLayout.BOUNDS.size*WORLD_SCALE))
	# One contiguous jungle, with small trail entrances for autonomous rotations.
	var jungle := panel_style(Color("153e2c"), 15)
	jungle.border_color = Color("729b72")
	jungle.set_border_width_all(3)
	draw_style_box(jungle, Rect2(arena_point(MapLayout.JUNGLE.position), MapLayout.JUNGLE.size*WORLD_SCALE))
	for side in range(2):
		draw_dashed_line(arena_point(MapLayout.ENTRANCES[side]), arena_point(MapLayout.JUNGLE_CENTER), Color("456c43"), 9, 8)
	for i in range(23):
		var point := MapLayout.JUNGLE.position+Vector2(35+(i*137)%490, 30+(i*119)%320)
		if MapLayout.on_lane(point, 2):
			continue
		var center := arena_point(point)
		draw_circle(center+Vector2(2, 4), 12, Color("112e24"))
		draw_circle(center, 10+(i%3)*2, [Color("286943"), Color("337d4b"), Color("225c3c")][i%3])
		draw_line(center, center+Vector2(0, 8), Color("4b6441"), 2)
	for lane in range(MapLayout.LANE_COUNT):
		var road := PackedVector2Array()
		for point in MapLayout.path(lane):
			road.append(arena_point(point))
		draw_polyline(road, Color("879085"), MapLayout.ROAD_HALF_WIDTH*(WORLD_SCALE*2)+4, true)
		draw_polyline(road, Color("343e41"), MapLayout.ROAD_HALF_WIDTH*(WORLD_SCALE*2), true)
		# Rounded lane bends and subtle paving keep the broad routes clear.
		for p in road:
			draw_circle(p, MapLayout.ROAD_HALF_WIDTH*WORLD_SCALE, Color("343e41"))
		for progress in range(100, int(MapLayout.length(lane))-70, 78):
			var point := MapLayout.point_at(lane, progress)
			var tangent := MapLayout.forward(point, lane, 0)
			var center := arena_point(point)
			draw_line(center-tangent.orthogonal()*MapLayout.ROAD_HALF_WIDTH*WORLD_SCALE*0.65, center+tangent.orthogonal()*MapLayout.ROAD_HALF_WIDTH*WORLD_SCALE*0.65, Color("475050"), 1)
	label_at("MID LANE", arena_point(MapLayout.JUNGLE_CENTER+Vector2(45, -30)), 10, GOLD)
	label_at("NORTH / WEST LANE", arena_point(Vector2(455, -32)), 10, MUTED)
	label_at("SOUTH / EAST LANE", arena_point(Vector2(917.5, 1065)), 10, MUTED)
	# Side landmarks echo the sketch without adding combat objects.
	for offset in [Vector2(-46, -26), Vector2(37, 28), Vector2(-40, 27)]:
		var blue: Vector2 = arena_point(MapLayout.BASES[0])+offset
		draw_line(blue, blue+Vector2(6, 11), Color("c49b48"), 4, true)
		var red: Vector2 = arena_point(MapLayout.BASES[1])-offset
		draw_line(red, red+Vector2(-4, -9), Color("3f985c"), 4, true)

func draw_unit(u: Dictionary, time: float, winner: int = -1) -> void:
	var center := arena_point(u.pos)
	var radius: float = maxf(8.0, u.radius*WORLD_SCALE)
	var flight: Dictionary = u.get("flight", {})
	if not flight.is_empty():
		# FULL SEND: shadow on the ground, token high in the arc, landing marker.
		var t: float = clampf(flight.time/flight.total, 0, 1)
		var landing := arena_point(flight.to)
		draw_arc(landing, 62, 0, TAU, 32, Color(RED if u.team == 1 else BLUE, 0.7), 2, true)
		label_at("INCOMING", landing+Vector2(-26, -66), 10, GOLD)
		draw_circle(center, radius*(0.6+0.4*(1.0-sin(PI*t))), Color(0, 0, 0, 0.35))
		center += Vector2(0, -sin(PI*t)*80)
	if u.get("jungle_buff", 0) > 0:
		draw_arc(center, radius+7, 0, TAU, 32, GOLD if u.buff_kind == "power" else GREEN, 3, true)
	var color := BLUE if u.team == 0 else RED
	if u.creep:
		if u.get("empowered", false):
			draw_arc(center, 15, 0, TAU, 24, GOLD, 2, true)
		draw_circle(center + Vector2(0, 4), 11, Color(0, 0, 0, 0.25))
		draw_colored_polygon(PackedVector2Array([center + Vector2(-7, -7), center + Vector2(7, -7), center + Vector2(9, 7), center + Vector2(-9, 7)]), color.darkened(0.35))
		if u.get("creep_kind", "") == "siege":
			draw_line(center, center+Vector2.from_angle(u.facing)*16, TEXT, 5, true)
		elif u.get("creep_kind", "") == "ranged":
			draw_circle(center, 3, TEXT)
		else:
			draw_line(center + Vector2(-3, -2), center + Vector2(3, -2), TEXT, 2)
		bar(Rect2(center + Vector2(-10, 12), Vector2(20, 3)), u.hp / u.max_hp, color)
		return
	draw_circle(center + Vector2(0, 7), radius+4, Color(0, 0, 0, 0.3))
	if u.charge > 0:
		var charge: float = clampf(1.0 - u.charge / 1.7, 0.0, 1.0)
		draw_circle(center, radius+15 + sin(time * 15) * 3, Color(GOLD, 0.09 + charge * 0.13))
		draw_arc(center, radius+12, -PI / 2, -PI / 2 + TAU * charge, 48, GOLD, 4, true)
		var target_pos := center + Vector2.from_angle(u.facing) * 200
		draw_dashed_line(center, target_pos, Color(GOLD, 0.5), 1, 7)
	if u.shield > 0:
		draw_arc(center, radius+6, 0, TAU, 48, GREEN, 3, true)
		draw_circle(center, radius+8, Color(GREEN, 0.08))
	var token_radius: float = radius + 1
	draw_texture_rect(host.expressions.texture(u.portrait, host.expressions.resolve(u, time, winner)), Rect2(center-Vector2.ONE*token_radius, Vector2.ONE*token_radius*2), false, Color(1, 1, 1, 0.35 if u.invisible > 0 else 1.0))
	host.Expressions.draw_fire(self, Rect2(center-Vector2.ONE*token_radius, Vector2.ONE*token_radius*2), u, time)
	if u.curse > 0 or u.stun > 0:
		draw_arc(center, token_radius+7, -PI/2, TAU, 6, Color("d5a0ef"), 3, true)
		label_at("DISABLED" if u.stun > 0 else "STITCHED", center+Vector2(-23, -token_radius-15), 9, Color("d5a0ef"))
	if not u.evolved.is_empty():
		draw_circle(center+Vector2(token_radius-4, -token_radius+4), 5, GOLD)
	# Low-health ring stays outside the supplied portrait artwork.
	if u.hp / u.max_hp < 0.25:
		draw_arc(center, radius+1, 0, TAU, 48, GOLD if u.standing else RED, 2, true)
	var aim := Vector2.from_angle(u.facing)
	var side := aim.orthogonal()
	var weapon: Vector2 = center + aim * (radius + 1 - u.flash * 22)
	var length := 13.0
	if u.portrait == "eleanor":
		draw_line(weapon-side*5, weapon+side*5, GOLD, 3, true)
		draw_line(weapon, weapon+aim*21, Color("dce5ee"), 4, true)
	elif u.portrait == "hazmat":
		draw_circle(weapon+aim*4, 6, Color("d89788"))
	elif u.portrait == "mexai" or u.portrait == "irene":
		draw_colored_polygon(PackedVector2Array([weapon-side*3,weapon+aim*14,weapon+side*3]),Color("d1edee"))
	elif u.portrait == "oddity":
		draw_arc(weapon+aim*4, 5, 0, TAU, 5, Color("dcb9fa"),2,true)
	elif u.portrait == "poppet":
		draw_line(weapon, weapon+aim*16, Color("e8e2d0"), 2, true)
	elif u.portrait == "crash_test":
		draw_rect(Rect2(weapon+aim*2-Vector2(5, 5), Vector2(10, 10)), Color("f2c230"))
	elif u.portrait == "kiln":
		draw_circle(weapon+aim*4, 5, Color("f08a3c"))
	elif u.portrait == "sunday":
		draw_arc(weapon+aim*4, 4, 0, TAU, 12, SUN, 2, true)
	else:
		draw_circle(weapon+aim*3, 5, GOLD)
	if u.flash > 0:
		draw_arc(center,radius+8,u.facing-0.6,u.facing+0.6,12,GOLD,3,true)
	if u.get("blood_rush",0) > 0:
		draw_arc(center,radius+4,0,TAU,32,RED,2,true)
	if u.get("program",0) > 0:
		draw_arc(center,radius+10+sin(time*20)*2,0,TAU,24,Color("f2c230"),3,true)
		label_at("CRASH PROGRAM",center+Vector2(-36,radius+34),8,Color("f2c230"))
	if u.get("safety",0) > 0:
		draw_rect(Rect2(center-Vector2.ONE*(radius+6), Vector2.ONE*(radius+6)*2), Color("9aa5b1"), false, 3)
	if u.get("warmth",0) > 0:
		draw_circle(center,130*WORLD_SCALE,Color(SUN,0.07))
		draw_arc(center,130*WORLD_SCALE,0,TAU,48,Color(SUN,0.5),2,true)
	if u.get("hold_line",0) > 0:
		draw_arc(center,140*WORLD_SCALE,0,TAU,48,Color(GREEN,0.4),2,true)
	if u.get("kill_streak",0) > 0:
		label_at("+%d POWER" % (u.kill_streak*8),center+Vector2(-23,radius+24),8,GOLD)
	bar(Rect2(center + Vector2(-22, radius+7), Vector2(44, 4)), u.hp / u.max_hp, color)
	if u.shield > 0:
		bar(Rect2(center + Vector2(-22, radius+13), Vector2(44, 3)), u.shield / 115.0, GREEN)
	var name_height: float = -radius - (35 if u.curse > 0 or u.stun > 0 else 11)
	label_at(u.name.to_upper() + "  " + str(u.level), center + Vector2(-28, name_height), 10, color)
	if u.hp <= 1.1:
		label_at("1 HP", center + Vector2(-16, 61), 15, GOLD)


func draw_camps(frame: Dictionary) -> void:
	for camp in frame.get("camps", []):
		var center := arena_point(camp.pos)
		var color := GOLD if camp.kind in ["power", "node"] else GREEN
		draw_circle(center, 22, Color("172a24"))
		draw_arc(center, 22, 0, TAU, 40, color.darkened(0.4), 3, true)
		if camp.hp > 0:
			draw_circle(center, 13, color.darkened(0.5))
			draw_line(center+Vector2(-15, -10), center+Vector2(-5, -3), color, 5)
			draw_line(center+Vector2(15, -10), center+Vector2(5, -3), color, 5)
			bar(Rect2(center+Vector2(-24, 25), Vector2(48, 4)), camp.hp/camp.max_hp, color)
		else:
			label_at("%ds" % int(ceil(camp.respawn)), center+Vector2(-13, 5), 12, MUTED)
		label_at("POWER NODE" if camp.kind == "node" else camp.name, center+Vector2(-30, -29), 9, color)
		label_at("TEAM WAVES + XP" if camp.kind == "node" else "POWER + XP" if camp.kind == "power" else "REGEN + XP", center+Vector2(-30, 39), 8, color)

func draw_crown(frame: Dictionary) -> void:
	var crown: Dictionary = frame.get("crown", {})
	if crown.is_empty() or not crown.spawned:
		return
	var center := arena_point(crown.pos)
	if crown.holder >= 0:
		center += Vector2(0, -37)
	var points := PackedVector2Array([center+Vector2(-18, 10), center+Vector2(-22, -10), center+Vector2(-8, -2), center+Vector2(0, -19), center+Vector2(8, -2), center+Vector2(22, -10), center+Vector2(18, 10)])
	draw_circle(center, 31, Color(0.85, 0.14, 0.18, 0.2))
	draw_colored_polygon(points, GOLD)
	label_at("DAMAGE IDOL / 2x", center+Vector2(-54, 30), 11, GOLD)
