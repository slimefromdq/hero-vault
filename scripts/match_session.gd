extends RefCounted
## One queued best-of-three. Owns simulation and replay state independently of pages.
const Battle = preload("res://scripts/battle.gd")
const SPEEDS := [1, 2, 4, 8]
var id := 0
var squad_name := ""
var lineup: Array = []
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

func setup(number: int, name_value: String, team: Array, lanes: Array, plan: int, assignment: int) -> void:
	id = number
	squad_name = name_value
	lineup = team.duplicate()
	orders = lanes.duplicate()
	for i in range(3):
		var battle = Battle.new()
		battle.setup(4702+id*91+i*37,plan,assignment,i,lineup,orders)
		battles.append(battle)
		views.append({"follow":-1,"zoom":2.3,"replay":[],"time":0.0,"index":0,"name":"","shop_note":"","shop_ok":true,"shop_order":-1})

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

## Player purchases always go to the live game, never a replay frame.
func purchase(game: int, hero_index: int, item: String) -> Dictionary:
	var view: Dictionary = views[game]
	var battle = battles[game]
	var result: Dictionary
	if not view.replay.is_empty():
		result = {"ok": false, "message": "Return to live to shop.", "order": {}, "eta": -1.0}
	elif hero_index < 0 or hero_index >= 5:
		result = {"ok": false, "message": "Select one of your heroes first.", "order": {}, "eta": -1.0}
	else:
		result = battle.request_purchase(0, battle.units[hero_index].id, item)
	view.shop_note = result.message
	view.shop_ok = result.ok
	view.shop_order = result.order.get("id", -1)
	return result

## Live feedback for the view's most recent order.
func order_note(game: int) -> String:
	var view: Dictionary = views[game]
	if view.shop_order < 0:
		return view.shop_note
	var battle = battles[game]
	var shop = battle.shops[0]
	var order: Dictionary = shop.find(view.shop_order)
	if order.is_empty():
		for done in shop.delivered:
			if done.id == view.shop_order:
				return "Delivered %s to %s" % [shop.item_name(done.item), done.hero_name]
		return view.shop_note
	var eta: float = battle.couriers[0].estimate_eta(battle, shop, order.id)
	var status := "Delivering to %s" % order.hero_name
	if order.status == shop.PENDING and order.attempts > 0:
		status = "Waiting for %s to return" % order.hero_name
	return "Purchased %s / %s / Drone ETA: %s" % [shop.item_name(order.item), status, ("%ds" % int(ceil(eta))) if eta >= 0 else "--"]

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
