extends Control
const MapLayout = preload("res://scripts/map_layout.gd")
const Catalog = preload("res://scripts/catalog.gd")
var host: Node2D
var team: Array = []
var orders: Array = []
var hero_choices: Array = []
var order_choices: Array = []
var role_labels: Array = []
var portrait_views: Array = []
var status_label: Label
var detail_label: Label
var apply_button: Button
var draft_name: LineEdit
var plan_choice: OptionButton
var assignment_choice: OptionButton
var initialized := false

func _ready() -> void:
	position = Vector2(0,150)
	size = Vector2(1440,750)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var panel := Panel.new()
	panel.position = Vector2(26,10)
	panel.size = Vector2(1388,705)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",host.panel_style(Color("111e30")))
	add_child(panel)
	text("TEAM BUILDER",Vector2(54,25),Vector2(500,36),26)
	make_button("Character expressions",Vector2(1110,25),Vector2(260,36),func():host.expression_editor.open())
	text("Build your next lineup. Games already queued keep their original squad.",Vector2(54,62),Vector2(1050,24),14)
	text("TEAM NAME",Vector2(54,99),Vector2(260,20),11)
	draft_name = LineEdit.new()
	draft_name.position = Vector2(54,123)
	draft_name.size = Vector2(340,36)
	draft_name.max_length = 26
	draft_name.add_theme_stylebox_override("normal",host.panel_style(Color("24344a")))
	add_child(draft_name)
	draft_name.text_changed.connect(func(_value): update_view())
	text("SQUAD PLAN",Vector2(435,99),Vector2(250,20),11)
	plan_choice = choice(Vector2(435,123),280)
	for value in ["Balanced","Pressure","Protect and Scale"]:
		plan_choice.add_item(value)
	plan_choice.item_selected.connect(func(_value): update_view())
	text("HERO ASSIGNMENT",Vector2(755,99),Vector2(300,20),11)
	assignment_choice = choice(Vector2(755,123),340)
	for value in ["Protect allies","Hold the front","Hold ultimates for a finish"]:
		assignment_choice.add_item(value)
	assignment_choice.item_selected.connect(func(_value): update_view())
	for heading in [["HERO", 150], ["LANE / ASSIGNMENT", 409]]:
		text(heading[0], Vector2(heading[1], 182), Vector2(220, 25), 11)
	for row in range(5):
		var y := 212 + row*78
		var slot := row
		var portrait := TextureRect.new()
		portrait.position = Vector2(54, y)
		portrait.size = Vector2(54, 54)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		add_child(portrait)
		portrait_views.append(portrait)
		var hero := choice(Vector2(150, y), 235)
		for id in Catalog.HERO_IDS:
			hero.add_item(Catalog.HEROES[id].name)
			hero.get_popup().set_item_tooltip(hero.item_count-1, Catalog.HEROES[id].description)
		hero.item_selected.connect(func(index):
			team[slot] = Catalog.HERO_IDS[index]
			detail_label.text = Catalog.HEROES[team[slot]].description
			update_view())
		hero_choices.append(hero)
		var order := choice(Vector2(409, y), 205)
		for label in ["North lane", "South lane", "Jungle / roam", "Mid lane"]:
			order.add_item(label)
		order.get_popup().set_item_tooltip(2, "Clear neutral camps for XP and temporary boosts while rotating between lanes. Wounded heroes abandon camps.")
		order.get_popup().set_item_tooltip(3, "The shorter diagonal route between vaults. Earlier wave contact, with a tower guarding each end.")
		order.item_selected.connect(func(index): orders[slot] = index; update_view())
		order_choices.append(order)
		role_labels.append(text("", Vector2(639, y+8), Vector2(700, 50), 12))
	status_label = text("", Vector2(54, 610), Vector2(1200, 27), 19)
	detail_label = text("Hover a hero in its menu for details. Items are bought during a match from the remote shop and flown to heroes by your courier drone.", Vector2(54, 652), Vector2(720, 55), 13)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	apply_button = make_button("SAVE TEAM", Vector2(1170, 656), Vector2(200, 42), apply)
	make_button("Discard edits",Vector2(1170,123),Vector2(200,36),reload_saved)
	make_button("Restore starter squad", Vector2(942, 656), Vector2(210, 42), func():
		team = Catalog.DEFAULT_TEAM.duplicate()
		orders = MapLayout.DEFAULT_ORDERS.duplicate()
		update_view())
	hide()

func text(value: String, pos: Vector2, extent: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = value
	label.position = pos
	label.size = extent
	label.add_theme_color_override("font_color", Color("c6d5e7"))
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	return label

func choice(pos: Vector2, width: float) -> OptionButton:
	var control := OptionButton.new()
	control.position = pos
	control.size = Vector2(width, 35)
	control.add_theme_stylebox_override("normal", host.panel_style(Color("24344a")))
	control.add_theme_font_size_override("font_size", 14)
	add_child(control)
	return control

func make_button(value: String, pos: Vector2, extent: Vector2, action: Callable) -> Button:
	var control := Button.new()
	control.text = value
	control.position = pos
	control.size = extent
	control.add_theme_stylebox_override("normal", host.panel_style(Color("344660")))
	control.pressed.connect(action)
	add_child(control)
	return control

func open() -> void:
	if not initialized:
		reload_saved()
	show()

func reload_saved() -> void:
	team = host.team.duplicate()
	orders = host.lane_orders.duplicate()
	draft_name.text = host.squad_name
	plan_choice.select(host.plan)
	assignment_choice.select(host.assignment)
	initialized = true
	update_view()

func is_dirty() -> bool:
	return initialized and (team != host.team or orders != host.lane_orders or draft_name.text != host.squad_name or plan_choice.selected != host.plan or assignment_choice.selected != host.assignment)

func update_view() -> void:
	if team.size() != 5:
		return
	for row in range(5):
		hero_choices[row].select(Catalog.HERO_IDS.find(team[row]))
		order_choices[row].select(orders[row])
		portrait_views[row].texture = host.portraits[team[row]]
		var data: Dictionary = Catalog.HEROES[team[row]]
		role_labels[row].text = "%s  ·  %s  |  %s" % [data.role, data.personality, data.kit]
		role_labels[row].tooltip_text = data.description
	var error := Catalog.validate(team)
	status_label.text = ("Unsaved changes" if is_dirty() else "Saved / ready to queue") if error.is_empty() else error
	status_label.add_theme_color_override("font_color", Color("8cddc6") if error.is_empty() else Color("f49bae"))
	apply_button.disabled = not error.is_empty() or draft_name.text.strip_edges().is_empty()
	host.queue_redraw()

func apply() -> void:
	if Catalog.validate(team) != "" or draft_name.text.strip_edges().is_empty():
		return
	host.team = team.duplicate()
	host.lane_orders = orders.duplicate()
	host.squad_name = draft_name.text.strip_edges()
	draft_name.text = host.squad_name
	host.plan = plan_choice.selected
	host.assignment = assignment_choice.selected
	host.save_profile()
	host.status_note = "Team saved. Queue from Home when you are ready."
	update_view()
	host.refresh_controls()
