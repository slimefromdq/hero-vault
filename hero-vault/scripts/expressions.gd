extends RefCounted
## Presentation cues use simulation timestamps so pause, speed and replay agree.
const NAMES := ["neutral", "smug", "angry", "happy", "attack", "panic", "hurt", "dazed", "upset", "excited", "knocked_out", "special"]
const SHEETS := {
	"hazmat": {"path": "res://assets/hazmat-expressions.png", "ys": [22, 342, 662], "height": 256},
	"mexai": {"path": "res://assets/mexai-expressions.png", "ys": [10, 334, 658], "height": 292}
}
var textures := {}
var profiles := {}
const PROFILE_PATH := "user://expressions.json"
const DURATIONS := {"special": 1.5, "hurt": 0.65, "happy": 1.8, "smug": 1.2, "angry": 0.9, "excited": 1.2, "attack": 0.7}

func load_profiles() -> void:
	if FileAccess.file_exists(PROFILE_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
		if data is Dictionary:
			profiles = data
	textures.clear()

func save_profile(hero: String, profile: Dictionary) -> Error:
	var next := profiles.duplicate(true)
	next[hero] = profile.duplicate(true)
	var file := FileAccess.open(PROFILE_PATH+".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(next, "\t"))
	file.close()
	var error := DirAccess.rename_absolute(PROFILE_PATH+".tmp", PROFILE_PATH)
	if error == OK:
		profiles = next
		textures.clear()
	return error

func resolve(u: Dictionary, time: float, winner: int = -1) -> String:
	var profile: Dictionary = profiles.get(u.portrait, {})
	var reaction := state(u, time, winner, profile)
	return profile.get("mapping", {}).get(reaction, reaction)

static func read_sheet(path: String) -> Image:
	if path.begins_with("res://"):
		var source: Texture2D = load(path)
		return source.get_image() if source else null
	if not FileAccess.file_exists(path) or FileAccess.get_file_as_bytes(path).size() > 32*1024*1024:
		return null
	var image := Image.load_from_file(path)
	if image == null or image.is_empty() or image.get_width() > 4096 or image.get_height() > 4096:
		return null
	return image

static func sheet_regions(image: Image, columns: int, rows: int, trim: float) -> Array:
	var regions := []
	if image == null or columns < 1 or rows < 1 or columns*rows < 12 or trim < 0 or trim > 0.5:
		return regions
	var width := image.get_width()/columns
	var height := image.get_height()/rows
	if width < 16 or height*(1-trim) < 16:
		return regions
	for i in range(12):
		regions.append(Rect2i((i%columns)*width, (i/columns)*height, width, int(height*(1-trim))))
	return regions

static func clean_portrait(source: Image, remove_background: bool) -> Image:
	var result := source.duplicate() as Image
	result.convert(Image.FORMAT_RGBA8)
	if remove_background:
		# Flood only edge-connected pale background; enclosed white eyes stay intact.
		var width := result.get_width()
		var height := result.get_height()
		var visited := PackedByteArray()
		visited.resize(width*height)
		var queue := PackedInt32Array()
		for x in range(width):
			queue.append(x)
			queue.append((height-1)*width+x)
		for y in range(height):
			queue.append(y*width)
			queue.append(y*width+width-1)
		var head := 0
		while head < queue.size():
			var index := queue[head]
			head += 1
			if visited[index]:
				continue
			visited[index] = 1
			var x := index%width
			var y := index/width
			var color := result.get_pixel(x,y)
			if color.a > 0.05 and minf(color.r, minf(color.g, color.b)) < 0.70:
				continue
			result.set_pixel(x,y,Color(0,0,0,0))
			if x > 0: queue.append(index-1)
			if x+1 < width: queue.append(index+1)
			if y > 0: queue.append(index-width)
			if y+1 < height: queue.append(index+width)
	var bounds := result.get_used_rect()
	if bounds.has_area():
		result = result.get_region(bounds)
	var size := maxi(result.get_width(), result.get_height())
	var square := Image.create(size,size,false,Image.FORMAT_RGBA8)
	square.fill(Color.TRANSPARENT)
	square.blit_rect(result, Rect2i(Vector2i.ZERO,result.get_size()), (Vector2i(size,size)-result.get_size())/2)
	return square
const STREAK_THRESHOLD := 3
const FIRE_SECONDS := 3.0

static func fire_strength(u: Dictionary, time: float) -> float:
	if u.get("hp", 0) <= 0 or u.get("portrait_streak", 0) < STREAK_THRESHOLD:
		return 0.0
	var remaining: float = u.get("portrait_fire_until", -1.0)-time
	return clampf(remaining/0.6, 0.0, 1.0) * clampf((FIRE_SECONDS-remaining)/0.15, 0.0, 1.0)

static func draw_fire(canvas: CanvasItem, rect: Rect2, u: Dictionary, time: float) -> void:
	var strength := fire_strength(u, time)
	if strength <= 0:
		return
	var size := rect.size.x
	var center := rect.get_center()
	# Deterministic tongues of flame hug the edges, leaving the face uncovered.
	for i in range(14):
		var phase := time*8.0+i*2.4
		var angle := TAU*i/14.0
		var base := center+Vector2.from_angle(angle)*rect.size*0.48
		var width := size*0.055
		var height := size*(0.12+0.1*(0.5+0.5*sin(phase)))*strength
		var sway := sin(phase*1.3)*width
		var points := PackedVector2Array([base+Vector2(-width, 2), base+Vector2(-width*0.8, -height*0.45), base+Vector2(sway, -height), base+Vector2(width, -height*0.3), base+Vector2(width, 2)])
		canvas.draw_colored_polygon(points, Color(1.0, 0.27, 0.035, 0.85*strength))
		canvas.draw_colored_polygon(PackedVector2Array([base+Vector2(-width*0.5, 1), base+Vector2(sway*0.5, -height*0.65), base+Vector2(width*0.5, 1)]), Color(1.0, 0.83, 0.2, strength))

func texture(hero: String, expression: String = "neutral") -> Texture2D:
	var key := hero + "/" + expression
	if textures.has(key):
		return textures[key]
	var profile: Dictionary = profiles.get(hero, {})
	if not SHEETS.has(hero) and profile.get("path", "").is_empty():
		var fallback: Texture2D = load("res://assets/" + hero + ".svg")
		textures[key] = fallback
		return fallback
	var data: Dictionary = SHEETS.get(hero, {})
	var index := maxi(0, NAMES.find(expression))
	var custom: bool = not profile.get("path", "").is_empty()
	var source := read_sheet(profile.path if custom else data.path)
	if source == null:
		push_warning("Missing expression sheet for " + hero)
		var fallback: Texture2D = load("res://assets/"+hero+".svg")
		textures[key] = fallback
		return fallback
	var regions := sheet_regions(source, int(profile.get("columns",4)), int(profile.get("rows",3)), float(profile.get("trim",0))) if custom else []
	if custom and regions.size() != 12:
		return load("res://assets/"+hero+".svg")
	# Build all faces once when a sheet changes; drawing never repeats pixel work.
	for i in range(12):
		var region: Rect2i = regions[i] if custom else Rect2i((i%4)*256,data.ys[i/4],256,data.height)
		textures[hero+"/"+NAMES[i]] = ImageTexture.create_from_image(clean_portrait(source.get_region(region), profile.get("remove_background",true)))
	return textures[hero+"/"+NAMES[index]]

static func state(u: Dictionary, time: float, winner: int = -1, profile: Dictionary = {}) -> String:
	if u.get("hp", 1) <= 0:
		return "knocked_out"
	if winner >= 0:
		return "happy" if u.get("team", -1) == winner else "upset"
	if u.get("stun", 0) > 0:
		return "dazed"
	if u.get("hp", 1)/float(u.get("max_hp", 1)) < float(profile.get("low_health", 0.25)):
		return "panic"
	if u.get("charge", 0) > 0 or u.get("overpressure", 0) > 0 or u.get("larceny_time", 0) > 0:
		return "special"
	var cues: Dictionary = u.get("expression_cues", {})
	for name in ["special", "hurt", "happy", "smug", "angry", "excited", "attack"]:
		var until: float = cues.get(name, -1000.0)
		var duration: float = DURATIONS[name]
		var start := until-duration
		if time >= start and start+float(profile.get("durations",{}).get(name,duration)) > time:
			return name
	return "neutral"

static func cue(u: Dictionary, name: String, until: float) -> void:
	if u.is_empty() or u.get("creep", false):
		return
	if not u.has("expression_cues"):
		u.expression_cues = {}
	u.expression_cues[name] = until

static func record(kind: String, actor: Dictionary, target: Dictionary, value: float, time: float) -> void:
	match kind:
		"melee_windup", "projectile_fired": cue(actor, "attack", time+0.7)
		"melee_miss", "projectile_miss", "dash_miss": cue(actor, "angry", time+0.9)
		"damage":
			if value > 0:
				cue(target, "hurt", time+0.65)
				if target.get("hp", 1) <= 0 and not target.get("creep", false):
					target["portrait_streak"] = 0
					target["portrait_fire_until"] = -1.0
					if not actor.is_empty() and actor.get("hp", 0) > 0 and not actor.get("creep", false) and actor.get("team", -1) != target.get("team", -1):
						actor["portrait_streak"] = actor.get("portrait_streak", 0)+1
						if actor.portrait_streak >= STREAK_THRESHOLD:
							actor["portrait_fire_until"] = time+FIRE_SECONDS
					cue(actor, "happy", time+1.8)
		"item_stolen", "health_stolen": cue(actor, "smug", time+1.2)
		"level", "ultimate_available", "jungle": cue(actor, "excited", time+1.2)
		"ultimate_cast", "encore_cast": cue(actor, "special", time+1.5)
