extends RefCounted
## One queued best-of-three. Owns simulation and replay state independently of pages.
const Battle = preload("res://scripts/battle.gd")
const SPEEDS := [1, 2, 4, 8]
var id := 0
var squad_name := ""
var lineup: Array = []
var equipment: Array = []
var orders: Array = []
var battles: Array = []
var views: Array = []
var running := true
var rewarded := false
var accumulator := 0.0
var speed_index := 0
var clips: Array = []
var pending_clips: Array = []
var events_seen := [0, 0, 0]

func setup(number: int, name_value: String, team: Array, gear: Array, lanes: Array, plan: int, assignment: int) -> void:
	id = number
	squad_name = name_value
	lineup = team.duplicate()
	equipment = gear.duplicate(true)
	orders = lanes.duplicate()
	for i in range(3):
		var battle = Battle.new()
		battle.setup(4702+id*91+i*37,plan,assignment,i,lineup,equipment,orders)
		battles.append(battle)
		views.append({"follow":-1,"zoom":2.3,"replay":[],"time":0.0,"index":0,"name":""})

func advance(delta: float) -> void:
	if running and not finished():
		accumulator += minf(delta,0.2)*SPEEDS[speed_index]
		while accumulator >= Battle.STEP:
			for battle in battles:
				battle.step()
			accumulator -= Battle.STEP
		collect_highlights()
		if finished():
			running = false
	for view in views:
		if view.replay.is_empty():
			continue
		view.time += delta
		while view.index < view.replay.size()-1 and view.replay[view.index+1].time <= view.replay[0].time+view.time:
			view.index += 1
		if view.time > view.replay[-1].time-view.replay[0].time+2:
			view.time = 0.0
			view.index = 0

func finished() -> bool:
	return battles.size() == 3 and battles.all(func(b): return b.winner != -1)

func wins() -> int:
	return battles.filter(func(b): return b.winner == 0).size()

func frame(game: int) -> Dictionary:
	var view: Dictionary = views[game]
	return battles[game].frame() if view.replay.is_empty() else view.replay[view.index]

func collect_highlights() -> void:
	for i in range(3):
		var battle = battles[i]
		while events_seen[i] < battle.events.size():
			var event: Dictionary = battle.events[events_seen[i]]
			if event.kind in ["clutch","victory"]:
				pending_clips.append({"game":i,"time":event.time,"title":event.title})
			events_seen[i] += 1
	for pending in pending_clips.duplicate():
		var battle = battles[pending.game]
		if battle.clock < pending.time+4 and battle.winner == -1:
			continue
		var frames: Array = []
		for state in battle.history:
			if state.time >= pending.time-7 and state.time <= pending.time+4:
				frames.append(state.duplicate(true))
		if not frames.is_empty():
			clips.append({"game":pending.game,"time":pending.time,"title":pending.title,"frames":frames})
			if clips.size() > 9:
				clips.pop_front()
		pending_clips.erase(pending)

func game_clips(game: int) -> Array:
	var result := clips.filter(func(clip): return clip.game == game)
	result.reverse()
	return result

func play_clip(game: int, index: int) -> void:
	var available := game_clips(game)
	if index < 0 or index >= available.size():
		return
	var clip: Dictionary = available[index]
	views[game].replay = clip.frames.duplicate(true)
	views[game].time = 0.0
	views[game].index = 0
	views[game].name = clip.title
