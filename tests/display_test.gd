extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.3).timeout
	assert(root.mode == Window.MODE_FULLSCREEN, "Launch should be fullscreen")
	print("Fullscreen window: ", root.size, " | Monitor: ", DisplayServer.screen_get_size(root.current_screen))
	assert(root.size == DisplayServer.screen_get_size(root.current_screen), "Fullscreen should match the monitor")
	var key := InputEventKey.new()
	key.keycode = KEY_F11
	key.pressed = true
	scene._input(key)
	await create_timer(0.3).timeout
	assert(root.mode == Window.MODE_WINDOWED, "F11 should exit fullscreen")
	scene._input(key)
	await create_timer(0.3).timeout
	assert(root.mode == Window.MODE_FULLSCREEN, "F11 should restore fullscreen")
	scene.queue_games()
	key.keycode = KEY_1
	scene._input(key)
	assert(scene.follow_hero == 0, "1 should follow Rally")
	key.keycode = KEY_ESCAPE
	scene._input(key)
	assert(scene.follow_hero == -1 and root.mode == Window.MODE_FULLSCREEN, "First Escape restores overview")
	scene._input(key)
	await create_timer(0.2).timeout
	assert(root.mode == Window.MODE_WINDOWED, "Second Escape exits fullscreen")
	print("DISPLAY PASS")
	scene.queue_free()
	await process_frame
	quit()
