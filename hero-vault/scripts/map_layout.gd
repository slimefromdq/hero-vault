extends RefCounted
## Shared by simulation and drawing. Blue is northeast; red is southwest.
## Top (0): long isolated 1v1. Mid (1): short diagonal with river cuts. Bottom (2): wide cover fights.
const TOP := 0
const MID := 1
const BOT := 2
const LANE_COUNT := 3
const BASES := [Vector2(745, 80), Vector2(255, 420)]
const PATHS := [
	[Vector2(745, 80), Vector2(255, 80), Vector2(255, 420)],
	[Vector2(745, 80), Vector2(255, 420)],
	[Vector2(745, 80), Vector2(745, 420), Vector2(255, 420)],
]
const HALF_WIDTH := [32.0, 38.0, 54.0]
const ROAD_HALF_WIDTH := 44.0
const NAMES := ["top", "mid", "bottom"]
const LABELS := ["Top", "Mid", "Bot"]
const JUNGLE_PATCHES := [Rect2(300, 125, 155, 115), Rect2(545, 255, 155, 95)]
const JUNGLE := Rect2(300, 125, 155, 115)
const ENTRANCES := [Vector2(430, 80), Vector2(500, 250), Vector2(580, 420)]
const JUNGLE_WAYPOINTS := [Vector2(380, 180), Vector2(620, 305)]
const JUNGLE_CENTER := Vector2(380, 190)
const TOWERS := [
	[Vector2(545, 80), Vector2(588, 189), Vector2(745, 280)],
	[Vector2(255, 220), Vector2(412, 311), Vector2(455, 420)],
]
const CAMPS := [Vector2(365, 180), Vector2(630, 305)]
const COVER := [Rect2(702, 168, 50, 52), Rect2(702, 278, 50, 52), Rect2(548, 396, 78, 46), Rect2(372, 396, 78, 46)]
const BOUNDS := Rect2(180, 20, 640, 460)
const HERO_RADIUS := 17.0

static func path(lane: int) -> Array:
	return PATHS[clampi(lane, 0, LANE_COUNT-1)]

static func half_width(lane: int) -> float:
	return HALF_WIDTH[clampi(lane, 0, LANE_COUNT-1)]

static func lane_name(lane: int) -> String:
	return NAMES[clampi(lane, 0, LANE_COUNT-1)]

static func length(lane: int) -> float:
	var points := path(lane)
	var total := 0.0
	for i in range(points.size()-1):
		total += points[i].distance_to(points[i+1])
	return total

static func point_at(lane: int, progress: float) -> Vector2:
	var points := path(lane)
	var remaining := clampf(progress, 0, length(lane))
	for i in range(points.size()-1):
		var segment: float = points[i].distance_to(points[i+1])
		if remaining <= segment:
			return points[i].lerp(points[i+1], remaining/segment)
		remaining -= segment
	return points[-1]

static func project(point: Vector2, lane: int) -> Dictionary:
	var points := path(lane)
	var best := {"point": points[0], "distance": INF, "progress": 0.0}
	var walked := 0.0
	for i in range(points.size()-1):
		var nearest := Geometry2D.get_closest_point_to_segment(point, points[i], points[i+1])
		var distance := point.distance_to(nearest)
		if distance < best.distance:
			best = {"point": nearest, "distance": distance, "progress": walked + points[i].distance_to(nearest)}
		walked += points[i].distance_to(points[i+1])
	return best

static func closest_lane(point: Vector2) -> int:
	var best := 0
	var distance := INF
	for lane in range(LANE_COUNT):
		var gap: float = project(point, lane).distance
		if gap < distance:
			distance = gap
			best = lane
	return best

static func on_lane(point: Vector2, lane: int) -> bool:
	return project(point, lane).distance <= half_width(lane) + 7

static func constrain(point: Vector2, lane: int) -> Vector2:
	var nearest := project(point, lane)
	var width := half_width(lane)
	if nearest.distance <= width:
		return point
	return nearest.point + (point-nearest.point).normalized()*width

static func move_on_lane(point: Vector2, destination: Vector2, lane: int, distance: float) -> Vector2:
	var start := project(point, lane)
	var finish := project(destination, lane)
	var progress := move_toward(float(start.progress), float(finish.progress), distance)
	var lateral: Vector2 = point-start.point
	var target_lateral: Vector2 = destination-finish.point
	lateral = lateral.move_toward(target_lateral, distance*0.5)
	return constrain(point_at(lane, progress)+lateral, lane)

static func forward(point: Vector2, lane: int, team: int) -> Vector2:
	var progress: float = project(point, lane).progress
	var direction := 1.0 if team == 0 else -1.0
	var a := point_at(lane, clampf(progress-direction, 0, length(lane)))
	var b := point_at(lane, clampf(progress+direction, 0, length(lane)))
	return a.direction_to(b)

static func in_jungle(point: Vector2) -> bool:
	for patch in JUNGLE_PATCHES:
		if patch.has_point(point):
			return true
	return false

static func cover_at(point: Vector2) -> int:
	for i in range(COVER.size()):
		if COVER[i].has_point(point):
			return i
	return -1

static func in_cover(point: Vector2) -> bool:
	return cover_at(point) >= 0

static func segment_hits_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	var corners := [rect.position, rect.position+Vector2(rect.size.x, 0), rect.end, rect.position+Vector2(0, rect.size.y)]
	for i in range(4):
		if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i+1)%4]) != null:
			return true
	return false

## Shots can enter a bush or leave one, but cannot pass through to someone on the far side.
static func cover_blocks(from: Vector2, to: Vector2, target_pos: Vector2) -> bool:
	for rect in COVER:
		if rect.has_point(from):
			continue
		if is_finite(target_pos.x) and rect.has_point(target_pos):
			continue
		if segment_hits_rect(from, to, rect):
			return true
	return false

static func rotation_waypoints(from_lane: int, to_lane: int) -> Array:
	from_lane = clampi(from_lane, 0, LANE_COUNT-1)
	to_lane = clampi(to_lane, 0, LANE_COUNT-1)
	var via: Vector2 = JUNGLE_WAYPOINTS[0]
	if from_lane == MID:
		via = JUNGLE_WAYPOINTS[0] if to_lane == TOP else JUNGLE_WAYPOINTS[1]
	elif to_lane == MID:
		via = JUNGLE_WAYPOINTS[0] if from_lane == TOP else JUNGLE_WAYPOINTS[1]
	elif from_lane == TOP or to_lane == TOP:
		via = JUNGLE_WAYPOINTS[0]
	else:
		via = JUNGLE_WAYPOINTS[1]
	return [ENTRANCES[from_lane], via, ENTRANCES[to_lane]]
