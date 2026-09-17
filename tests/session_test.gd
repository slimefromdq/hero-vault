extends SceneTree
const Session = preload("res://scripts/match_session.gd")
const Catalog = preload("res://scripts/catalog.gd")
func _init() -> void:
	var session = Session.new()
	session.setup(1,"Session smoke test",Catalog.DEFAULT_TEAM,[0,0,1,1,2],0,0)
	for tick in range(24000):
		session.advance(0.05)
		if session.finished():
			break
	assert(session.finished(),"Queued set completes all three games")
	assert(not session.running,"Finished set stops its simulation")
	assert(not session.clips.is_empty(),"Queued games collect real combat highlights")
	for battle in session.battles:
		assert(battle.vaults[0] == 0 or battle.vaults[1] == 0,"Every game finishes by vault destruction")
		assert(battle.history.size() <= 210,"Each game replay buffer remains bounded")
	var times: Array = session.battles.map(func(battle):return battle.clock)
	session.advance(0.1)
	assert(times == session.battles.map(func(battle):return battle.clock),"Completion cannot resume the simulation")
	print("SESSION PASS / wins=",session.wins()," / game times=",times)
	quit()
