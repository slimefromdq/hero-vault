extends Node2D
## A clipped, presentation-only camera. Coordinates never feed back into combat.
const MapLayout = preload("res://scripts/map_layout.gd")
const Catalog = preload("res://scripts/catalog.gd")
const POPUP_SECONDS := 1.3
## Floating number colors by damage type (see docs/VISUAL_CLARITY.md).
const DAMAGE_COLORS := {"basic": Color("eef3f8"), "melee_basic": Color("eef3f8"), "ability": Color("ffb45c"),
	"splash": Color("ffb45c"), "magic": Color("c9a2ff"), "collision": Color("9fc3e6")}
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
	return Vector2(303.5, 214) + pos * Vector2.ONE * 0.82

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
			draw_circle(glow, field.radius*0.82, Color(SUN, 0.16))
			draw_circle(glow, field.radius*0.55, Color(1, 1, 0.9, 0.08))
			draw_arc(glow, field.radius*0.82, 0, TAU, 64, SUN, 3, true)
			label_at("BEAUTIFUL DAY", glow+Vector2(-40, -field.radius*0.82-6), 10, SUN)
			continue
		var tint := Color("f08a3c") if kind == "fire" else Color("e15b62")
		draw_circle(arena_point(field.pos), field.radius*0.82, Color(tint, 0.2))
		draw_arc(arena_point(field.pos), field.radius*0.82, 0, TAU, 48, tint, 2, true)
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
		bar(Rect2(center+Vector2(-35, 44), Vector2(70, 6)), frame.vaults[team]/3000.0, color)
		label_at("%d" % frame.vaults[team], center+Vector2(-17, 62), 11, color)
	var by_id := {}
	for u in frame.units:
		by_id[u.id] = u
	draw_telegraphs(frame, by_id)
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
		# A fading tail shows where each shot came from and where it is headed.
		draw_line(p - shot.direction * (46 if shot.ultimate else 26), p - shot.direction * (28 if shot.ultimate else 12), Color(color, 0.3), 5 if shot.ultimate else 2, true)
		draw_line(p - shot.direction * (28 if shot.ultimate else 12), p, color, 7 if shot.ultimate else 3, true)
		draw_circle(p, 4 if shot.ultimate else 2.5, Color(1, 1, 1, 0.9))
		if shot.ultimate:
			draw_circle(p, 13, Color(GOLD, 0.15))
	draw_popups(frame)

	if host.follow_hero >= 0:
		var hero: Dictionary = frame.units[host.follow_hero]
		if hero.hp <= 0:
			var marker := arena_point(hero.pos)
			draw_arc(marker, 34, 0, TAU, 48, MUTED, 2, true)
			label_at("RETURNING IN %ds" % int(ceil(hero.respawn)), marker + Vector2(-55, 4), 12, GOLD)
	draw_set_transform(Vector2(-322, -214))
	if frame.get("intermission",{}).get("time",0) > 0:
		label_at("INTERMISSION / COMBAT FROZEN",Vector2(570,260),16,Color("dfbcff"))
	if frame.time >= 720:
		label_at("OVERTIME / VAULT DEFENSES WEAKENING", Vector2(530, 242), 11, GOLD)
	if frame.winner != -1:
		box(Rect2(526, 356, 375, 105), Color("101b2b"))
		label_at("VICTORY" if frame.winner == 0 else "DEFEAT", Vector2(624, 402), 29, GREEN if frame.winner == 0 else RED)
		label_at("The vault has fallen. The story stays.", Vector2(569, 432), 14, MUTED)

## Deterministic pseudo-random value in [0, 1) for scenery placement.
static func noise(i: int, salt: int = 0) -> float:
	return fposmod(sin(float(i)*12.9898+float(salt)*78.233)*43758.5453, 1.0)

func draw_terrain() -> void:
	var bounds := Rect2(arena_point(MapLayout.BOUNDS.position), MapLayout.BOUNDS.size*0.82)
	var outer := panel_style(Color("1a2c2a"), 35)
	outer.border_color = Color("66716e")
	outer.set_border_width_all(2)
	draw_style_box(outer, bounds)
	# Meadow: tufts, flowers and stones outside the roads. Scenery only; never collides.
	for i in range(170):
		var world := MapLayout.BOUNDS.position+Vector2(14+noise(i, 1)*(MapLayout.BOUNDS.size.x-28), 14+noise(i, 2)*(MapLayout.BOUNDS.size.y-28))
		if MapLayout.JUNGLE.grow(6).has_point(world) or MapLayout.on_lane(world, 0) or MapLayout.on_lane(world, 1):
			continue
		var p := arena_point(world)
		var roll := noise(i, 3)
		if roll < 0.55:
			var tint := Color("2b4a3a") if roll < 0.3 else Color("35573f")
			draw_line(p, p+Vector2(-2, -4), tint, 1.2, true)
			draw_line(p, p+Vector2(0, -5), tint, 1.2, true)
			draw_line(p, p+Vector2(2, -4), tint, 1.2, true)
		elif roll < 0.72:
			draw_circle(p, 1.4, [Color("d9c16a"), Color("c98fb0"), Color("9fc3e6")][i%3])
		else:
			draw_circle(p+Vector2(1, 1.5), 2.8+noise(i, 4)*2.2, Color(0, 0, 0, 0.22))
			draw_circle(p, 2.5+noise(i, 4)*2.2, Color("56615f"))
			draw_circle(p+Vector2(-0.8, -0.8), 1.0, Color("7a8683"))
	for lane in range(2):
		var road := PackedVector2Array()
		for point in MapLayout.path(lane):
			road.append(arena_point(point))
		var width := MapLayout.ROAD_HALF_WIDTH*1.64
		# Curb, verge and paving, with rounded bends.
		draw_polyline(road, Color("26352f"), width+10, true)
		draw_polyline(road, Color("7d857a"), width+4, true)
		draw_polyline(road, Color("343e41"), width, true)
		draw_polyline(road, Color("3b4649"), width*0.45, true) # Worn centre track.
		var total := MapLayout.length(lane)
		for progress in range(30, int(total)-20, 26):
			var point := MapLayout.point_at(lane, progress)
			var tangent := MapLayout.forward(point, lane, 0)
			var center := arena_point(point)
			var side := tangent.orthogonal()
			if progress % 78 == 20:
				draw_line(center-side*27, center+side*27, Color("475050"), 1)
			# Paving cracks and curb stones.
			var n := noise(progress, lane+7)
			if n < 0.35:
				var crack := center+side*(n*60-10)
				draw_line(crack, crack+tangent*6+side*3, Color("2a3336"), 1)
			draw_line(center+side*(width/2+1)-tangent*5, center+side*(width/2+1)+tangent*5, Color("646c63"), 2)
			draw_line(center-side*(width/2+1)-tangent*5, center-side*(width/2+1)+tangent*5, Color("646c63"), 2)
	# Stone plazas around each vault.
	for team in range(2):
		var plaza := arena_point(MapLayout.BASES[team])
		var tint := BLUE if team == 0 else RED
		draw_circle(plaza, 54, Color("3a4447"))
		for ring in range(3):
			draw_arc(plaza, 26+ring*10, 0, TAU, 40, Color("4a5557"), 1, true)
		for spoke in range(12):
			var dir := Vector2.from_angle(spoke*TAU/12)
			draw_line(plaza+dir*26, plaza+dir*54, Color("4a5557"), 1)
		draw_arc(plaza, 54, 0, TAU, 48, Color(tint, 0.45), 2, true)
	# Tower foundations.
	for team in range(2):
		for tower_pos in MapLayout.TOWERS[team]:
			var base := arena_point(tower_pos)
			draw_rect(Rect2(base-Vector2(30, 30), Vector2(60, 60)), Color("2d3638"))
			draw_rect(Rect2(base-Vector2(30, 30), Vector2(60, 60)), Color("596366"), false, 1)
	draw_jungle()
	label_at("NORTH / WEST LANE", arena_point(Vector2(335, 35)), 10, MUTED)
	label_at("SOUTH / EAST LANE", arena_point(Vector2(520, 474)), 10, MUTED)
	# Side landmarks echo the sketch without adding combat objects.
	for offset in [Vector2(-46, -26), Vector2(37, 28), Vector2(-40, 27)]:
		var blue: Vector2 = arena_point(MapLayout.BASES[0])+offset
		draw_line(blue, blue+Vector2(6, 11), Color("c49b48"), 4, true)
		var red: Vector2 = arena_point(MapLayout.BASES[1])-offset
		draw_line(red, red+Vector2(-4, -9), Color("3f985c"), 4, true)

## One contiguous jungle: ragged canopy edge, dirt trails, clearings, a pond and layered trees.
func draw_jungle() -> void:
	var area := MapLayout.JUNGLE
	var edge := PackedVector2Array()
	var steps := 48
	for i in range(steps):
		var t := float(i)/steps
		var world: Vector2
		var perimeter := 2*(area.size.x+area.size.y)
		var d := t*perimeter
		if d < area.size.x: world = area.position+Vector2(d, 0)
		elif d < area.size.x+area.size.y: world = area.position+Vector2(area.size.x, d-area.size.x)
		elif d < 2*area.size.x+area.size.y: world = area.end-Vector2(d-area.size.x-area.size.y, 0)
		else: world = area.position+Vector2(0, area.size.y-(d-2*area.size.x-area.size.y))
		var inward := (area.get_center()-world).normalized()
		edge.append(arena_point(world+inward*(noise(i, 11)*7)))
	draw_colored_polygon(edge, Color("163b2b"))
	var outline := edge.duplicate()
	outline.append(edge[0])
	draw_polyline(outline, Color("5f8a60"), 3, true)
	# Undergrowth speckle.
	for i in range(90):
		var p := arena_point(area.position+Vector2(8+noise(i, 12)*(area.size.x-16), 8+noise(i, 13)*(area.size.y-16)))
		draw_circle(p, 1.3+noise(i, 14)*1.5, Color("1f4a34") if i%2 == 0 else Color("12321f"))
	# Dirt trails from each lane entrance through the centre to each camp.
	var trail_color := Color("433f30")
	for side in range(2):
		var entrance: Vector2 = MapLayout.ENTRANCES[side]
		# Start at the road's edge so the footpath never paints over the lane.
		var start: Vector2 = entrance.move_toward(MapLayout.JUNGLE_CENTER, MapLayout.ROAD_HALF_WIDTH+4)
		var bend: Vector2 = entrance.lerp(MapLayout.JUNGLE_CENTER, 0.6)+Vector2(10 if side == 0 else -10, 0)
		var trail := PackedVector2Array([arena_point(start), arena_point(bend), arena_point(MapLayout.JUNGLE_CENTER)])
		draw_polyline(trail, Color("2e2a1f"), 9, true)
		draw_polyline(trail, trail_color, 6, true)
	for camp in MapLayout.CAMPS:
		draw_line(arena_point(MapLayout.JUNGLE_CENTER), arena_point(camp), trail_color, 6, true)
	# Pond.
	var pond := arena_point(area.position+Vector2(186, 38))
	draw_circle(pond, 15, Color("214b4f"))
	draw_circle(pond+Vector2(3, 2), 11, Color("2d6a70"))
	draw_arc(pond+Vector2(-3, -2), 6, PI, TAU, 10, Color(1, 1, 1, 0.25), 1, true)
	# Clearings under each camp.
	for camp in MapLayout.CAMPS:
		draw_circle(arena_point(camp), 38, Color("3a3a2a"))
		draw_circle(arena_point(camp), 33, Color("45432f"))
	# Trees: shadow, trunk, two-tone canopy. Kept off trails and clearings.
	var placed := 0
	for i in range(80):
		if placed >= 30:
			break
		var world := area.position+Vector2(12+noise(i, 15)*(area.size.x-24), 14+noise(i, 16)*(area.size.y-26))
		var blocked := world.distance_to(MapLayout.JUNGLE_CENTER) < 26 or world.distance_to(area.position+Vector2(186, 38)) < 24
		for camp in MapLayout.CAMPS:
			blocked = blocked or world.distance_to(camp) < 52
		for side in range(2):
			blocked = blocked or Geometry2D.get_closest_point_to_segment(world, MapLayout.ENTRANCES[side], MapLayout.JUNGLE_CENTER).distance_to(world) < 16
		if blocked:
			continue
		placed += 1
		var p := arena_point(world)
		var size := 7.0+noise(i, 17)*5.0
		draw_circle(p+Vector2(3, 5), size, Color(0, 0, 0, 0.3))
		draw_line(p, p+Vector2(0, size*0.9), Color("5b4a33"), 2)
		var shades := [Color("276842"), Color("2f7a4a"), Color("215c3a")]
		draw_circle(p, size, shades[i%3])
		draw_circle(p+Vector2(-size*0.3, -size*0.3), size*0.55, shades[(i+1)%3].lightened(0.12))
		if noise(i, 18) < 0.3:
			draw_circle(p+Vector2(size*0.35, -size*0.1), 1.3, Color("e0a35a")) # Fruit.
	label_at("JUNGLE", arena_point(area.position+Vector2(6, area.size.y-6)), 11, Color("cef0af"))

func draw_unit(u: Dictionary, time: float, winner: int = -1) -> void:
	var center := arena_point(u.pos)
	var radius: float = u.radius*0.82
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
		draw_circle(center + Vector2(0, 4), 11, Color(0, 0, 0, 0.25))
		draw_colored_polygon(PackedVector2Array([center + Vector2(-7, -7), center + Vector2(7, -7), center + Vector2(9, 7), center + Vector2(-9, 7)]), color.darkened(0.35))
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
		var effect: String = u.cast_effect if Catalog.ULTIMATES.has(u.cast_effect) else u.portrait
		if Catalog.ULTIMATES.has(effect):
			var title: String = Catalog.ULTIMATES[effect].id.to_upper()
			label_at(title, center+Vector2(-font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x/2, radius+44), 9, GOLD)
	if u.shield > 0:
		draw_arc(center, radius+6, 0, TAU, 48, GREEN, 3, true)
		draw_circle(center, radius+8, Color(GREEN, 0.08))
	var token_radius: float = radius + 1
	var hurt_age: float = time-u.get("hurt_at", -100.0)
	if hurt_age >= 0 and hurt_age < 0.18:
		draw_circle(center, radius+5, Color(1, 0.35, 0.35, 0.45*(1.0-hurt_age/0.18)))
	draw_texture_rect(host.expressions.texture(u.portrait, host.expressions.resolve(u, time, winner)), Rect2(center-Vector2.ONE*token_radius, Vector2.ONE*token_radius*2), false, Color(1, 1, 1, 0.35 if u.invisible > 0 else 1.0))
	host.Expressions.draw_fire(self, Rect2(center-Vector2.ONE*token_radius, Vector2.ONE*token_radius*2), u, time)
	if u.curse > 0 or u.stun > 0:
		draw_arc(center, token_radius+7, -PI/2, TAU, 6, Color("d5a0ef"), 3, true)
	if u.stun > 0:
		# Orbiting stars read as "dazed" at any zoom.
		for i in range(3):
			var star := center+Vector2.from_angle(time*5.0+i*TAU/3)*Vector2(token_radius*0.8, token_radius*0.3)-Vector2(0, token_radius+2)
			draw_circle(star, 2.2, Color("f5e27a"))
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
	if u.get("safety",0) > 0:
		draw_rect(Rect2(center-Vector2.ONE*(radius+6), Vector2.ONE*(radius+6)*2), Color("9aa5b1"), false, 3)
	if u.get("warmth",0) > 0:
		draw_circle(center,130*0.82,Color(SUN,0.07))
		draw_arc(center,130*0.82,0,TAU,48,Color(SUN,0.5),2,true)
	if u.get("hold_line",0) > 0:
		draw_arc(center,140*0.82,0,TAU,48,Color(GREEN,0.4),2,true)
	if u.get("kill_streak",0) > 0:
		label_at("+%d POWER" % (u.kill_streak*8),center+Vector2(-23,radius+24),8,GOLD)
	bar(Rect2(center + Vector2(-22, radius+7), Vector2(44, 4)), u.hp / u.max_hp, color)
	if u.shield > 0:
		bar(Rect2(center + Vector2(-22, radius+13), Vector2(44, 3)), u.shield / 115.0, GREEN)
	label_at(u.name.to_upper() + "  " + str(u.level), center + Vector2(-28, -radius-11), 10, color)
	draw_status_pills(u, center+Vector2(0, -radius-26))
	if u.hp <= 1.1:
		label_at("1 HP", center + Vector2(-16, 61), 15, GOLD)


func draw_camps(frame: Dictionary) -> void:
	for camp in frame.get("camps", []):
		var center := arena_point(camp.pos)
		var power: bool = camp.kind == "power"
		var color := GOLD if power else GREEN
		# Ring of lair stones.
		for i in range(10):
			var stone := center+Vector2.from_angle(i*TAU/10+0.2)*29
			draw_circle(stone+Vector2(0.8, 1.2), 3.4, Color(0, 0, 0, 0.3))
			draw_circle(stone, 3.2, Color("6f675a") if power else Color("5d6f5a"))
		draw_arc(center, 25, 0, TAU, 40, Color(color, 0.35), 2, true)
		if camp.hp > 0:
			if power:
				# Ember Beast: horned, glowing.
				draw_circle(center, 20, Color(1.0, 0.5, 0.2, 0.18))
				draw_circle(center, 14, Color("5a2e1c"))
				draw_colored_polygon(PackedVector2Array([center+Vector2(-12, -6), center+Vector2(-19, -19), center+Vector2(-6, -11)]), Color("e8d3a8"))
				draw_colored_polygon(PackedVector2Array([center+Vector2(12, -6), center+Vector2(19, -19), center+Vector2(6, -11)]), Color("e8d3a8"))
				draw_circle(center+Vector2(-5, -2), 2.5, Color("ffb45c"))
				draw_circle(center+Vector2(5, -2), 2.5, Color("ffb45c"))
				draw_line(center+Vector2(-4, 6), center+Vector2(4, 6), Color("ffb45c"), 2)
			else:
				# Grove Guardian: mossy stump with leaves.
				draw_circle(center, 15, Color("3f5a3a"))
				draw_arc(center, 9, 0, TAU, 20, Color("5f7c52"), 1, true)
				draw_arc(center, 4, 0, TAU, 12, Color("5f7c52"), 1, true)
				for leaf in range(5):
					var dir := Vector2.from_angle(-PI/2+(leaf-2)*0.45)
					draw_circle(center+dir*17, 4, Color("7fcf8e"))
				draw_circle(center+Vector2(-5, -2), 2, GREEN)
				draw_circle(center+Vector2(5, -2), 2, GREEN)
			if camp.get("last_hit", -100.0) > frame.time-0.15:
				draw_circle(center, 21, Color(1, 1, 1, 0.25))
			bar(Rect2(center+Vector2(-26, 32), Vector2(52, 5)), camp.hp/camp.max_hp, color)
		else:
			draw_circle(center, 13, Color(0, 0, 0, 0.35))
			label_at("%ds" % int(ceil(camp.respawn)), center+Vector2(-10, 5), 13, MUTED)
		var title: String = camp.name.to_upper()
		var width: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		label_at(title, center+Vector2(-width/2, -35), 8, color)
		var tag := "POWER + XP" if power else "REGEN + XP"
		width = font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		label_at(tag, center+Vector2(-width/2, 47), 7, Color(color, 0.8))

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


## Short labelled pills above a hero; one per active status, most urgent first.
static func statuses(u: Dictionary) -> Array:
	var tags := []
	if u.get("stun", 0) > 0: tags.append(["STUN", Color("f5e27a")])
	if u.get("curse", 0) > 0: tags.append(["STITCH", Color("d5a0ef")])
	if u.get("invisible", 0) > 0: tags.append(["HIDDEN", Color("aab6c4")])
	if u.get("shield", 0) > 0: tags.append(["SHIELD", Color("8cddc6")])
	if u.get("hold_line", 0) > 0: tags.append(["HOLD", Color("8cddc6")])
	if u.get("overpressure", 0) > 0: tags.append(["OVERP", Color("f08a3c")])
	if u.get("blood_rush", 0) > 0: tags.append(["RUSH", Color("f49bae")])
	if u.get("safety", 0) > 0: tags.append(["SAFE", Color("c7d0da")])
	if u.get("program", 0) > 0: tags.append(["PROGRAM", Color("f2c230")])
	if u.get("warmth", 0) > 0: tags.append(["WARM", Color("ffe08a")])
	if u.get("jungle_buff", 0) > 0: tags.append(["POWER" if u.get("buff_kind", "") == "power" else "REGEN", Color("ffd387") if u.get("buff_kind", "") == "power" else Color("8cddc6")])
	if u.get("retreating", false): tags.append(["RETREAT", Color("8d9fb7")])
	return tags

func draw_status_pills(u: Dictionary, anchor: Vector2) -> void:
	var tags := statuses(u)
	if tags.is_empty():
		return
	tags = tags.slice(0, 4)
	var widths := []
	var total := 0.0
	for tag in tags:
		var w: float = font.get_string_size(tag[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x+8
		widths.append(w)
		total += w+2
	var x: float = anchor.x-total/2
	for i in range(tags.size()):
		var rect := Rect2(x, anchor.y-8, widths[i], 10)
		draw_rect(rect, Color(0.04, 0.07, 0.12, 0.85))
		draw_rect(rect, tags[i][1], false, 1)
		label_at(tags[i][0], Vector2(x+4, anchor.y), 7, tags[i][1])
		x += widths[i]+2

## Wind-up wedges for melee swings and lines for committed dashes.
func draw_telegraphs(frame: Dictionary, by_id: Dictionary) -> void:
	for swing in frame.get("swings", []):
		var u: Dictionary = by_id.get(swing.source, {})
		if u.is_empty() or u.hp <= 0:
			continue
		var total: float = maxf(0.05, swing.get("total", 0.5))
		var progress: float = clampf(1.0-swing.time/total, 0.0, 1.0)
		var center := arena_point(u.pos)
		var reach: float = swing.get("reach", u.reach)*0.82+u.radius*0.82
		var spread: float = PI*0.45 if u.portrait == "eleanor" else 0.5
		var tint := Color("ff7a6b") if u.team == 1 else Color("7fb6ff")
		var wedge := PackedVector2Array([center])
		for i in range(13):
			wedge.append(center+Vector2.from_angle(swing.angle-spread+spread*2*i/12.0)*reach)
		draw_colored_polygon(wedge, Color(tint, 0.06+0.16*progress))
		draw_arc(center, reach*progress, swing.angle-spread, swing.angle+spread, 12, Color(tint, 0.85), 2, true)
		draw_arc(center, reach, swing.angle-spread, swing.angle+spread, 12, Color(tint, 0.35), 1, true)
	for u in frame.units:
		var dash: Dictionary = u.get("dash", {})
		if u.hp <= 0 or dash.is_empty() or dash.get("kind", "") == "walk":
			continue
		var target: Dictionary = by_id.get(dash.get("target", -1), {})
		if target.is_empty():
			continue
		var tint := RED if dash.kind == "leech" else GREEN
		draw_dashed_line(arena_point(u.pos), arena_point(target.pos), Color(tint, 0.8), 2, 6)
		draw_arc(arena_point(target.pos), target.radius*0.82+6, 0, TAU, 24, Color(tint, 0.8), 2, true)

func popup_font_size(base: float) -> int:
	return maxi(7, int(round(base/sqrt(maxf(camera_zoom, 0.5)))))

## Floating combat text. Uses snapshot timestamps so replays play it back identically.
func draw_popups(frame: Dictionary) -> void:
	for p in frame.get("popups", []):
		var age: float = frame.time-p.time
		if age < 0 or age > POPUP_SECONDS:
			continue
		var t: float = age/POPUP_SECONDS
		var alpha: float = 1.0 if t < 0.6 else 1.0-(t-0.6)/0.4
		var anchor := arena_point(p.pos)+Vector2(0, -26-p.get("lift", 0)*11-t*22)
		var text := ""
		var color: Color = DAMAGE_COLORS.get(p.kind, TEXT)
		var size := 12.0
		match p.kind:
			"miss":
				text = "MISS"
				color = MUTED
				size = 10.0
			"heal":
				text = "+%d" % roundi(p.amount)
				color = GREEN
			_:
				text = "%d" % roundi(p.amount) if p.amount >= 0.5 else ""
				if p.crit:
					text += "!"
					color = GOLD
					size = 17.0 - 5.0*minf(t*3, 1.0)
		var font_size := popup_font_size(size)
		if not text.is_empty():
			var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string_outline(font, anchor-Vector2(width/2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0, 0, 0, 0.7*alpha))
			draw_string(font, anchor-Vector2(width/2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color, alpha))
		if p.get("absorbed", 0) >= 0.5:
			var shield_text := "(%d shield)" % roundi(p.absorbed)
			var small := popup_font_size(9)
			var width: float = font.get_string_size(shield_text, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
			draw_string(font, anchor+Vector2(-width/2, small+1), shield_text, HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color(GREEN, alpha))
