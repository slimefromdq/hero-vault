extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: "+message)
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var fixture := FileAccess.open("user://squad.json",FileAccess.WRITE)
	fixture.store_string(JSON.stringify({"team":["rally","bastion","lucy","colony","volt"],"account":{"xp":41,"matches":3}}))
	fixture.close()
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	check(scene.page == "home" and scene.sessions.is_empty(),"Startup is Home without simulated preview games")
	check(scene.team == scene.Catalog.DEFAULT_TEAM and scene.account.xp == 41,"Legacy save keeps progression and migrates removed roster")
	check(scene.home_layer.visible and not scene.game_layer.visible and not scene.loadout_panel.visible,"Home has no game or team controls overlaid")
	scene.team_button.pressed.emit()
	var builder = scene.loadout_panel
	check(scene.page == "team" and builder.visible and not scene.home_layer.visible,"Team Builder is a dedicated page")
	builder.draft_name.text = "Tab Test Squad"
	builder.update_view()
	check(builder.is_dirty(),"Draft changes are marked unsaved")
	scene.show_page("home")
	scene.show_page("team")
	check(builder.draft_name.text == "Tab Test Squad","Draft survives tab switches")
	builder.gear = scene.Catalog.DEFAULT_ITEMS.duplicate(true)
	builder.team = scene.Catalog.DEFAULT_TEAM.duplicate()
	builder.orders = [0,0,3,1,2]
	builder.apply()
	check(scene.lane_orders[2] == 3 and builder.order_choices[2].selected == 3, "Mid assignment is selectable and saved")
	check(scene.page == "team" and not builder.is_dirty(),"Saving stays on Team Builder")
	scene.show_page("home")
	scene.launch_button.pressed.emit()
	check(scene.sessions.size() == 1 and scene.open_tabs.size() == 3,"Queue opens three dedicated game tabs")
	check(scene.page == "game" and scene.game_layer.visible and not builder.visible and not scene.home_layer.visible,"Game view excludes editing and queue controls")
	var first = scene.sessions[0]
	check(first.battles[0].units[2].lane == 2 and not first.battles[0].units[2].roamer, "Queued game honors mid assignment")
	var frozen_lineup: Array = first.lineup.duplicate()
	var frozen_equipment: Array = first.equipment.duplicate(true)
	scene.set_focus(1)
	scene.focus_zoom = 2.8
	scene.battle_view.update_camera(0,true)
	check(scene.battle_view.project_point(first.battles[0].units[1].pos).distance_to(Vector2(391.5,205)) < 0.01,"Camera follows within game tab")
	scene.open_game(0,1)
	check(scene.follow_hero == -1,"New game has independent overview camera")
	scene.open_game(0,0)
	check(scene.follow_hero == 1 and scene.focus_zoom == 2.8,"Game tab restores camera state")
	scene.show_page("team")
	var key := InputEventKey.new()
	key.keycode = KEY_3
	key.pressed = true
	var old_focus: int = scene.follow_hero
	scene._input(key)
	check(scene.follow_hero == old_focus,"Team-page typing does not trigger game shortcuts")
	builder.team[2] = "oddity"
	builder.gear[0] = ["last_stand","coin"]
	builder.orders[2] = 0
	builder.plan_choice.select(1)
	builder.draft_name.text = "Next Squad"
	builder.apply()
	check(first.lineup == frozen_lineup and first.equipment == frozen_equipment,"Editing next team cannot mutate queued lineup or items")
	check(first.battles[0].units[2].portrait == "eleanor" and first.battles[0].plan == 0,"Already queued game keeps its heroes and strategy")
	var before: float = first.battles[0].clock
	scene._process(0.1)
	check(first.battles[0].clock > before,"Simulation continues while Team Builder is selected")
	scene.show_page("home")
	scene.queue_games()
	check(scene.sessions.size() == 2 and scene.open_tabs.size() == 6,"Another queue creates new games without replacing old ones")
	var second = scene.sessions[1]
	check(second.lineup[2] == "oddity" and second.battles[0].plan == 1,"New queue uses saved edited composition and strategy")
	before = first.battles[0].clock
	scene._process(0.1)
	check(first.battles[0].clock > before and second.battles[0].clock > 0,"Both queued sets advance independently")
	scene.close_game(1,0)
	check(scene.page == "home" and scene.open_tabs.size() == 5,"Closing selected game returns Home")
	before = second.battles[0].clock
	scene._process(0.1)
	check(second.battles[0].clock > before,"Closing a tab does not stop its game")
	scene.open_game(1,0)
	check(scene.open_tabs.size() == 6 and second.battles[0].clock > 0,"Home can reopen existing game without restarting it")
	scene.pause_button.pressed.emit()
	before = second.battles[0].clock
	var other_time: float = first.battles[0].clock
	scene._process(0.1)
	check(second.battles[0].clock == before and first.battles[0].clock > other_time,"Pause affects selected set only")
	scene.pause_button.pressed.emit()
	# Replay is isolated per game; switching views never rewinds the live simulation.
	first.battles[0].snapshot()
	first.clips.append({"game":0,"time":first.battles[0].clock,"title":"Test replay","frames":first.battles[0].history.duplicate(true)})
	first.play_clip(0,0)
	scene.open_game(0,0)
	check(not first.views[0].replay.is_empty() and first.views[1].replay.is_empty(),"Replay belongs only to its game tab")
	first.views[0].replay[0].units[0].hp = -123
	check(first.battles[0].units[0].hp != -123,"Replay cannot alter live state")
	scene.open_game(1,0)
	scene.open_game(0,0)
	check(not first.views[0].replay.is_empty(),"Replay survives tab navigation")
	scene.replay_button.pressed.emit()
	check(first.views[0].replay.is_empty(),"Return to live exits only current replay")
	var matches: int = scene.account.matches
	var xp: int = scene.account.xp
	for i in range(3):
		first.battles[i].winner = 0 if i < 2 else 1
		first.battles[i].vaults[1 if i < 2 else 0] = 0
	scene.show_page("team")
	scene._process(0.1)
	check(scene.account.matches == matches+1 and scene.account.xp == xp+150,"Background completion awards results")
	scene._process(0.1)
	check(scene.account.matches == matches+1 and scene.account.xp == xp+150,"Rewards cannot duplicate after page switches")
	check(scene.game_status(first,0) == "WIN" and scene.game_status(first,2) == "LOSS","Finished tabs retain results")
	scene.save_profile()
	var stored = JSON.parse_string(FileAccess.get_file_as_string("user://squad.json"))
	check(stored.team[2] == "oddity" and stored.squad_name == "Next Squad" and stored.queue_number >= 2,"Saved team and queue counter persist")
	# Invalid drafts cannot be saved and never poison the saved queue configuration.
	builder.gear[0] = ["execution","execution"]
	builder.update_view()
	check(builder.apply_button.disabled,"Invalid team draft is rejected")
	builder.apply()
	check(scene.equipment[0] == ["last_stand","coin"],"Invalid save leaves valid saved composition intact")
	# Completed sets release capacity; paused sets still count toward the cap.
	scene.show_page("home")
	scene.queue_games()
	scene.queue_games()
	var count: int = scene.sessions.size()
	scene.queue_games()
	check(scene.active_count() == 3 and scene.sessions.size() == count,"Queue cap prevents unbounded concurrent simulations")
	var restored = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	check(restored.team[2] == "oddity" and restored.account.xp == scene.account.xp,"New app session restores saved team and progression")
	restored.queue_free()
	print("NAVIGATION PASS" if failures == 0 else "NAVIGATION FAIL: %d" % failures)
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
