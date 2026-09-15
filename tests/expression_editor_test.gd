extends SceneTree
const Expressions = preload("res://scripts/expressions.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: "+message)
func _init() -> void:
	call_deferred("run")
func run() -> void:
	# A closed black border around a white center models enclosed eyes.
	var source := Image.create(20,20,false,Image.FORMAT_RGBA8)
	source.fill(Color.WHITE)
	source.fill_rect(Rect2i(4,4,12,12),Color.BLACK)
	source.fill_rect(Rect2i(6,6,8,8),Color.WHITE)
	var clean := Expressions.clean_portrait(source,true)
	check(clean.get_width() == 12,"Outer whitespace is tightly trimmed")
	check(clean.get_pixel(5,5) == Color.WHITE,"Enclosed white detail survives cleanup")
	check(Expressions.sheet_regions(source,1,1,0).is_empty(),"Too few cells rejected")
	check(Expressions.sheet_regions(null,4,3,0).is_empty(),"Invalid image rejected")
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.show_page("team")
	var editor = scene.expression_editor
	await editor.open()
	check(editor.size.y <= 700, "Editor fits its viewport")
	editor.hero_choice.select(scene.Catalog.HERO_IDS.find("eleanor"))
	editor.load_hero()
	var original: Texture2D = scene.portraits.eleanor
	var sheet := Expressions.read_sheet("res://assets/hazmat-expressions.png")
	check(sheet.save_png("user://test-sheet.png") == OK,"Import fixture saved")
	editor.selected_path = "user://test-sheet.png"
	editor.trim.value = 18
	editor.refresh_preview()
	check(editor.sheet_valid,"Uploaded sheet validates")
	check(editor.faces[0].texture != null,"Upload previews before save")
	check(scene.portraits.eleanor == original,"Preview does not replace saved portrait")
	editor.mappings[Expressions.NAMES.find("hurt")].select(Expressions.NAMES.find("smug"))
	editor.low_health.value = 40
	editor.durations.hurt.value = 2.0
	editor.save()
	check(not editor.visible,"Save closes editor")
	check(scene.portraits.eleanor != original,"Save updates the visible portrait")
	var library := Expressions.new()
	library.load_profiles()
	check(library.profiles.has("eleanor"),"Profile persists across reload")
	check(library.profiles.eleanor.path.begins_with("user://expression_sheets/"),"Upload copied into owned storage")
	check(library.texture("eleanor") != null,"Copied sheet loads after restart")
	var unit := {"portrait":"eleanor","hp":80.0,"max_hp":100.0,"team":0,"expression_cues":{"hurt":10.65}}
	check(library.resolve(unit,11.5) == "smug","Custom face and duration apply to damage")
	check(library.resolve(unit,12.1) == "neutral","Custom duration expires")
	unit.hp = 35.0
	check(library.resolve(unit,12.1) == "panic","Custom low-health threshold applies")
	await editor.open()
	check(editor.size.y <= 700, "Editor fits its viewport")
	editor.low_health.value = 75
	editor.hide()
	check(scene.expressions.profiles.eleanor.low_health == 0.4,"Cancel leaves settings intact")
	await editor.open()
	check(editor.size.y <= 700, "Editor fits its viewport")
	editor.draft = {}
	editor.selected_path = ""
	editor.populate()
	editor.save()
	check(scene.portraits.eleanor.resource_path.ends_with("eleanor.svg"),"Restore defaults returns original art")
	if "--capture-editor" in OS.get_cmdline_user_args():
		editor.hero_choice.select(scene.Catalog.HERO_IDS.find("mexai"))
		await editor.open()
		check(editor.size.y <= 700, "Editor fits its viewport")
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.local-data/expression-editor.png")
	scene.queue_free()
	await process_frame
	print("EXPRESSION EDITOR PASS" if failures == 0 else "EXPRESSION EDITOR FAIL: %d" % failures)
	quit(failures)
