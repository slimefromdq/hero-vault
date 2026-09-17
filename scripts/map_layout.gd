extends RefCounted
## Shared by simulation and drawing. Blue is northeast; red is southwest.
const BASES := [Vector2(745, 80), Vector2(255, 420)]
const NORTH := [Vector2(745, 80), Vector2(255, 80), Vector2(255, 420)]
const SOUTH := [Vector2(745, 80), Vector2(745, 420), Vector2(255, 420)]
const MID := [Vector2(745, 80), Vector2(500, 250), Vector2(255, 420)]
const LANE_COUNT := 3
const LANE_NAMES := ["North", "South", "Mid"]
# Assignment 2 remains roaming for compatibility with saved squads.
const ROAM_ORDER := 2
const MID_ORDER := 3
const DEFAULT_ORDERS := [0, 1, 3, 1, 2]
const JUNGLE := Rect2(388, 170, 224, 160)
const ENTRANCES := [Vector2(444, 80), Vector2(556, 420), Vector2(500, 250)]
const JUNGLE_CENTER := Vector2(500, 250)
const TOWERS := [[Vector2(535, 80), Vector2(745, 240), Vector2(615, 170)], [Vector2(255, 260), Vector2(465, 420), Vector2(385, 330)]]
const CAMPS := [Vector2(444, 190), Vector2(556, 310)]
const ROAD_HALF_WIDTH := 44.0
const BOUNDS := Rect2(180, 20, 640, 460)
const HERO_RADIUS := 17.0

static func path(lane: int) -> Array:
	return [NORTH, SOUTH, MID][lane]

static func order_lane(order: int) -> int:
	return 2 if order == MID_ORDER else 0 if order == ROAM_ORDER else order

static func nearest_lane(point: Vector2) -> int:
	var best := 0
	for lane in range(1, LANE_COUNT):
		if project(point, lane).distance < project(point, best).distance:
			best = lane
	return best

static func length(lane: int) -> float:
	var points := path(lane)
	return points[0].distance_to(points[1]) + points[1].distance_to(points[2])

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

static func on_lane(point: Vector2, lane: int) -> bool:
	return project(point, lane).distance <= ROAD_HALF_WIDTH + 7

static func constrain(point: Vector2, lane: int) -> Vector2:
	var nearest := project(point, lane)
	if nearest.distance <= ROAD_HALF_WIDTH:
		return point
	return nearest.point + (point-nearest.point).normalized()*ROAD_HALF_WIDTH

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
