extends AcceptDialog
const Expressions = preload("res://scripts/expressions.gd")
const Catalog = preload("res://scripts/catalog.gd")
const TRIGGERS := ["Idle / preparation", "Successful theft", "Missed attack", "Takedown / victory", "Attack windup", "Low health", "HP damage", "Stunned", "Defeat", "Level / ultimate ready / camp clear", "Knocked out", "Ultimate / active special"]
var host: Node2D
var hero_choice: OptionButton
var columns: SpinBox
var rows: SpinBox
var trim: SpinBox
var low_health: SpinBox
var remove_background: CheckBox
var faces: Array = []
var mappings: Array = []
var durations := {}
var note: Label
var picker: FileDialog
var draft := {}
var preview_library := Expressions.new()
var selected_path := ""
var sheet_valid := true
var loading := false

func _ready() -> void:
	title = "Character expressions"
	min_size = Vector2i(920,690)
	get_ok_button().text = "Save expressions"
	dialog_hide_on_ok = false
	confirmed.connect(save)
	add_cancel_button("Cancel")
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",8)
	add_child(body)
	var top := HBoxContainer.new()
	body.add_child(top)
	hero_choice = OptionButton.new()
	for id in Catalog.HERO_IDS:
		hero_choice.add_item(Catalog.HEROES[id].name)
	top.add_child(hero_choice)
	hero_choice.item_selected.connect(func(_index): load_hero())
	var upload := Button.new()
	upload.text = "Upload expression sheet"
	top.add_child(upload)
	upload.pressed.connect(func(): picker.popup_centered_ratio(0.75))
	var reset := Button.new()
	reset.text = "Restore defaults"
	top.add_child(reset)
	reset.pressed.connect(func(): draft = {}; selected_path = ""; populate())
	var help := Label.new()
	help.text = "PNG, JPG or WebP · 12 faces, left to right then down · up to 4096 × 4096 / 32 MB"
	body.add_child(help)
	var layout := HBoxContainer.new()
	body.add_child(layout)
	columns = number(layout,"Columns",1,12,1)
	rows = number(layout,"Rows",1,12,1)
	trim = number(layout,"Bottom crop %",0,50,1)
	low_health = number(layout,"Low HP %",1,99,1)
	remove_background = CheckBox.new()
	remove_background.text = "Remove pale background"
	body.add_child(remove_background)
	for control in [columns,rows,trim]:
		control.value_changed.connect(func(_value): refresh_preview())
	remove_background.toggled.connect(func(_value): refresh_preview())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(880,420)
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",18)
	scroll.add_child(grid)
	for heading in ["Face preview", "When", "Use expression", "Hold (seconds)"]:
		var label := Label.new()
		label.text = heading
		grid.add_child(label)
	for i in range(12):
		var face := TextureRect.new()
		face.custom_minimum_size = Vector2(56,56)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		grid.add_child(face)
		faces.append(face)
		var label := Label.new()
		label.text = TRIGGERS[i]
		grid.add_child(label)
		var mapping := OptionButton.new()
		for name in Expressions.NAMES:
			mapping.add_item(name.capitalize())
		grid.add_child(mapping)
		mappings.append(mapping)
		mapping.item_selected.connect(func(_index): update_faces())
		var name: String = Expressions.NAMES[i]
		if Expressions.DURATIONS.has(name):
			var duration := SpinBox.new()
			duration.min_value = 0
			duration.max_value = 10
			duration.step = 0.05
			grid.add_child(duration)
			durations[name] = duration
		else:
			var continuous := Label.new()
			continuous.text = "While active"
			grid.add_child(continuous)
	note = Label.new()
	note.custom_minimum_size = Vector2(860,42)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	picker = FileDialog.new()
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Expression sheets"])
	add_child(picker)
	picker.file_selected.connect(func(path): selected_path = path; refresh_preview())

func number(parent: Control, label_text: String, minimum: float, maximum: float, step_value: float) -> SpinBox:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var control := SpinBox.new()
	control.min_value = minimum
	control.max_value = maximum
	control.step = step_value
	parent.add_child(control)
	return control

func hero_id() -> String:
	return Catalog.HERO_IDS[hero_choice.selected]

func open() -> void:
	load_hero()
	popup_centered(Vector2i(920,690))
	await get_tree().process_frame
	await get_tree().process_frame
	# Child construction can grow an AcceptDialog before the scroll container lays out.
	popup_centered(Vector2i(920,690))

func load_hero() -> void:
	draft = host.expressions.profiles.get(hero_id(),{}).duplicate(true)
	selected_path = draft.get("path", "")
	populate()

func populate() -> void:
	loading = true
	columns.value = draft.get("columns",4)
	rows.value = draft.get("rows",3)
	trim.value = float(draft.get("trim",0))*100
	low_health.value = float(draft.get("low_health",0.25))*100
	remove_background.button_pressed = draft.get("remove_background",true)
	for i in range(12):
		var name: String = Expressions.NAMES[i]
		mappings[i].select(maxi(0,Expressions.NAMES.find(draft.get("mapping",{}).get(name,name))))
	for name in durations:
		durations[name].value = draft.get("durations",{}).get(name,Expressions.DURATIONS[name])
	loading = false
	refresh_preview()

func settings() -> Dictionary:
	var result := {"path":selected_path,"columns":int(columns.value),"rows":int(rows.value),"trim":trim.value/100.0,"low_health":low_health.value/100.0,"remove_background":remove_background.button_pressed,"mapping":{},"durations":{}}
	for i in range(12):
		result.mapping[Expressions.NAMES[i]] = Expressions.NAMES[mappings[i].selected]
	for name in durations:
		result.durations[name] = durations[name].value
	return result

func refresh_preview() -> void:
	if loading:
		return
	sheet_valid = true
	if not selected_path.is_empty():
		var image := Expressions.read_sheet(selected_path)
		sheet_valid = Expressions.sheet_regions(image,int(columns.value),int(rows.value),trim.value/100.0).size() == 12
	get_ok_button().disabled = not sheet_valid
	if not sheet_valid:
		note.text = "Cannot use this sheet. Check file type, size, and a grid containing at least 12 cells."
		for face in faces: face.texture = null
		return
	preview_library.profiles[hero_id()] = settings()
	preview_library.textures.clear()
	update_faces()
	note.text = "Preview only. Save applies to this hero across the game, including replays. Cancel keeps your saved settings."

func update_faces() -> void:
	if loading or not sheet_valid:
		return
	for i in range(12):
		faces[i].texture = preview_library.texture(hero_id(), Expressions.NAMES[mappings[i].selected])

func save() -> void:
	if not sheet_valid:
		return
	var profile := settings()
	if not selected_path.is_empty():
		var image := Expressions.read_sheet(selected_path)
		if image == null:
			note.text = "The sheet is no longer available. Choose the file again."
			return
		var folder := "user://expression_sheets"
		var error := DirAccess.make_dir_recursive_absolute(folder)
		if error != OK:
			note.text = "Could not create the expression folder: " + error_string(error)
			return
		var path := folder+"/"+hero_id()+"-"+str(Time.get_ticks_usec())+".png"
		error = image.save_png(path)
		if error != OK:
			note.text = "Could not copy the sheet: " + error_string(error)
			return
		profile.path = path
	var error: Error = host.expressions.save_profile(hero_id(),profile)
	if error != OK:
		note.text = "Could not save expressions: " + error_string(error)
		return
	for id in Catalog.HERO_IDS:
		host.portraits[id] = host.expressions.texture(id,host.expressions.profiles.get(id,{}).get("mapping",{}).get("neutral","neutral"))
	host.loadout_panel.update_view()
	host.queue_redraw()
	hide()
