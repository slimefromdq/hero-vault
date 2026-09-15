extends Node2D
## Persistent navigation shell. Pages own controls; sessions own running games.
const Catalog = preload("res://scripts/catalog.gd")
const Session = preload("res://scripts/match_session.gd")
const LoadoutPanel = preload("res://scripts/loadout_panel.gd")
const BattleView = preload("res://scripts/battle_view.gd")
const ARENA_RECT := Rect2(322,214,783,410)
const RIVALS := ["The Night Shift","Copper Company","Velvet Riot"]
const INK := Color("0a1220")
const PANEL := Color("111e30")
const BORDER := Color("28394e")
const TEXT := Color("e4ebf3")
const MUTED := Color("8d9fb7")
const GOLD := Color("ffd387")
const BLUE := Color("83bbff")
const RED := Color("f49bae")
const GREEN := Color("8cddc6")
const MAX_ACTIVE_SERIES := 3
var font: Font = ThemeDB.fallback_font
var portraits := {}
var team: Array = Catalog.DEFAULT_TEAM.duplicate()
var equipment: Array = Catalog.DEFAULT_ITEMS.duplicate(true)
var lane_orders: Array = [0,0,1,1,2]
var squad_name := "The Brave Ones"
var plan := 0
var assignment := 0
var account := {"matches":0,"wins":0,"xp":0,"hero_kills":0,"hero_saves":0}
var queue_number := 0
var sessions: Array = []
var page := "home"
var active_session := -1
var selected := 0
var open_tabs: Array = []
var home_button: Button
var team_button: Button
var launch_button: Button
var pause_button: Button
var speed_button: Button
var replay_button: Button
var fullscreen_button: Button
var focus_choice: OptionButton
var home_layer: Control
var game_layer: Control
var loadout_panel: Control
var battle_view: Node2D
var tabs_scroll: ScrollContainer
var tabs_row: HBoxContainer
var home_games: VBoxContainer
var home_game_buttons: Array = []
var clip_buttons: Array = []
var status_note := "Build a team, queue a set, and follow each game in its own tab."
var refresh_clock := 0.0
var shot_path := ""
var shot_delay := 0

# Presentation-only compatibility with BattleView. No page owns a simulation.
var battles: Array:
	get:
		return sessions[active_session].battles if active_session >= 0 else []
var follow_hero: int:
	get:
		return sessions[active_session].views[selected].follow if active_session >= 0 else -1
	set(value):
		if active_session >= 0:
			sessions[active_session].views[selected].follow = value
var focus_zoom: float:
	get:
		return sessions[active_session].views[selected].zoom if active_session >= 0 else 2.3
	set(value):
		if active_session >= 0:
			sessions[active_session].views[selected].zoom = value

func _ready() -> void:
	for id in Catalog.HERO_IDS:
		portraits[id] = load("res://assets/"+id+".svg")
	load_profile()
	build_pages()
	loadout_panel = LoadoutPanel.new()
	loadout_panel.host = self
	add_child(loadout_panel)
	show_page("home")
	for arg in OS.get_cmdline_user_args():
		if arg == "--autoplay" or arg == "--showcase":
			queue_games()
		if arg == "--showcase":
			for tick in range(600):
				sessions[active_session].advance(0.05)
			sessions[active_session].running = false
		if arg == "--loadout":
			show_page("team")
		if arg == "--home":
			show_page("home")
		if arg == "--focus-first":
			set_focus(0)
		if arg.begins_with("--capture="):
			shot_path = arg.trim_prefix("--capture=")
			shot_delay = 20
	refresh_controls()

func build_pages() -> void:
	home_button = button("Home",Rect2(26,98,126,42),func():show_page("home"))
	team_button = button("Team Builder",Rect2(162,98,177,42),func():show_page("team"))
	fullscreen_button = button("Fullscreen / F11",Rect2(1207,26,203,32),toggle_fullscreen)
	fullscreen_button.add_theme_font_size_override("font_size",13)
	tabs_scroll = ScrollContainer.new()
	tabs_scroll.position = Vector2(350,96)
	tabs_scroll.size = Vector2(1060,54)
	tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(tabs_scroll)
	tabs_row = HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation",8)
	tabs_scroll.add_child(tabs_row)
	home_layer = Control.new()
	home_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(home_layer)
	launch_button = button("QUEUE 3 GAMES  >",Rect2(58,473,486,48),queue_games,true,home_layer)
	button("Edit team composition",Rect2(58,529,486,39),func():show_page("team"),false,home_layer)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(646,236)
	scroll.size = Vector2(732,555)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	home_layer.add_child(scroll)
	home_games = VBoxContainer.new()
	home_games.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home_games.add_theme_constant_override("separation",18)
	scroll.add_child(home_games)
	game_layer = Control.new()
	game_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(game_layer)
	var clip := Control.new()
	clip.position = ARENA_RECT.position
	clip.size = ARENA_RECT.size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_layer.add_child(clip)
	battle_view = BattleView.new()
	battle_view.host = self
	battle_view.portraits = portraits
	clip.add_child(battle_view)
	focus_choice = OptionButton.new()
	focus_choice.position = Vector2(772,174)
	focus_choice.size = Vector2(233,30)
	focus_choice.add_theme_stylebox_override("normal",panel_style(Color("1a2a40")))
	focus_choice.add_theme_font_size_override("font_size",13)
	focus_choice.item_selected.connect(func(index):set_focus(index-1))
	game_layer.add_child(focus_choice)
	pause_button = button("Pause set",Rect2(834,673,139,36),func():
		var session = sessions[active_session]
		session.running = not session.running
		refresh_controls(),false,game_layer)
	speed_button = button("1x speed",Rect2(985,673,120,36),func():
		var session = sessions[active_session]
		session.speed_index = (session.speed_index+1)%4
		refresh_controls(),false,game_layer)
	replay_button = button("Return to live",Rect2(322,673,158,36),func():
		sessions[active_session].views[selected].replay.clear()
		refresh_controls(),false,game_layer)
	for i in range(3):
		var index := i
		var control := button("",Rect2(1160,658+i*48,234,39),func():
			sessions[active_session].play_clip(selected,index)
			refresh_controls(),false,game_layer)
		control.add_theme_font_size_override("font_size",12)
		clip_buttons.append(control)

func show_page(value: String) -> void:
	if value == "game" and active_session < 0:
		value = "home"
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	page = value
	home_layer.visible = page == "home"
	game_layer.visible = page == "game"
	if loadout_panel != null:
		if page == "team":
			loadout_panel.open()
		else:
			loadout_panel.hide()
	refresh_controls()

func active_count() -> int:
	return sessions.filter(func(session):return not session.finished()).size()

func queue_games() -> void:
	if active_count() >= MAX_ACTIVE_SERIES:
		status_note = "Three sets are already active. Finish a set before queuing another."
		return
	var error := Catalog.validate(team,equipment)
	if error != "":
		status_note = error
		show_page("team")
		return
	queue_number += 1
	var session = Session.new()
	session.setup(queue_number,squad_name,team,equipment,lane_orders,plan,assignment)
	sessions.append(session)
	var index := sessions.size()-1
	for game in range(3):
		open_tabs.append({"session":index,"game":game})
	save_profile()
	rebuild_tabs()
	rebuild_home_games()
	open_game(index,0)
	status_note = "Set #%d queued with %s. Your next team can be edited at any time." % [session.id,session.squad_name]

func open_game(session_index: int, game: int) -> void:
	if session_index < 0 or session_index >= sessions.size() or game < 0 or game >= 3:
		return
	if not open_tabs.any(func(tab):return tab.session == session_index and tab.game == game):
		open_tabs.append({"session":session_index,"game":game})
		rebuild_tabs()
	active_session = session_index
	selected = game
	focus_choice.clear()
	focus_choice.add_item("Overview [0]")
	for u in sessions[active_session].frame(selected).units.slice(0,10):
		focus_choice.add_item(("Ally / " if u.team == 0 else "Enemy / ")+u.name)
	focus_choice.select(follow_hero+1)
	show_page("game")
	battle_view.update_camera(0,true)
	for tab in open_tabs:
		if tab.session == active_session and tab.game == selected and tab.has("button"):
			tabs_scroll.ensure_control_visible(tab.button)

func close_game(session_index: int, game: int) -> void:
	# Closing a spectator tab never cancels or resets the game behind it.
	open_tabs = open_tabs.filter(func(tab):return tab.session != session_index or tab.game != game)
	if page == "game" and active_session == session_index and selected == game:
		show_page("home")
	rebuild_tabs()
	status_note = "Tab closed. Reopen the game from Home; it continues in the background."

func rebuild_tabs() -> void:
	for child in tabs_row.get_children():
		tabs_row.remove_child(child)
		child.queue_free()
	for tab in open_tabs:
		var series: int = tab.session
		var game: int = tab.game
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation",0)
		tabs_row.add_child(pair)
		var control := button("",Rect2(),func():open_game(series,game),false,pair)
		control.custom_minimum_size = Vector2(222,42)
		control.add_theme_font_size_override("font_size",12)
		var close := button("×",Rect2(),func():close_game(series,game),false,pair)
		close.custom_minimum_size = Vector2(32,42)
		close.tooltip_text = "Close this view. The game keeps running and can be reopened from Home."
		tab.button = control
	refresh_controls()

func rebuild_home_games() -> void:
	for child in home_games.get_children():
		home_games.remove_child(child)
		child.queue_free()
	home_game_buttons.clear()
	for offset in range(sessions.size()):
		var index := sessions.size()-1-offset
		var session = sessions[index]
		var title := Label.new()
		title.text = "SET #%d  /  %s" % [session.id,session.squad_name]
		title.add_theme_color_override("font_color",GOLD)
		title.add_theme_font_size_override("font_size",16)
		home_games.add_child(title)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",8)
		home_games.add_child(row)
		for game in range(3):
			var slot := game
			var control := button("",Rect2(),func():open_game(index,slot),false,row)
			control.custom_minimum_size = Vector2(230,72)
			control.add_theme_font_size_override("font_size",12)
			home_game_buttons.append({"button":control,"session":index,"game":game})
	refresh_controls()

func game_status(session, game: int) -> String:
	var winner: int = session.battles[game].winner
	return "WIN" if winner == 0 else "LOSS" if winner == 1 else "LIVE" if session.running else "PAUSED"

func refresh_controls() -> void:
	if home_button == null:
		return
	home_button.add_theme_stylebox_override("normal",panel_style(Color("30445a") if page == "home" else PANEL))
	team_button.add_theme_stylebox_override("normal",panel_style(Color("30445a") if page == "team" else PANEL))
	if loadout_panel != null:
		team_button.text = "Team Builder *" if loadout_panel.is_dirty() else "Team Builder"
	launch_button.disabled = active_count() >= MAX_ACTIVE_SERIES
	for tab in open_tabs:
		if not tab.has("button"):
			continue
		var session = sessions[tab.session]
		tab.button.text = "#%d.%d  %s  /  %s" % [session.id,tab.game+1,RIVALS[tab.game],game_status(session,tab.game)]
		tab.button.add_theme_stylebox_override("normal",panel_style(Color("30445a") if page == "game" and tab.session == active_session and tab.game == selected else PANEL))
	for entry in home_game_buttons:
		var session = sessions[entry.session]
		entry.button.text = "%s\n%s  /  %s" % [RIVALS[entry.game],game_status(session,entry.game),format_time(session.battles[entry.game].clock)]
	if active_session >= 0:
		var session = sessions[active_session]
		pause_button.disabled = session.finished()
		pause_button.text = "Pause set" if session.running else "Resume set"
		speed_button.text = "%dx speed" % Session.SPEEDS[session.speed_index]
		replay_button.visible = not session.views[selected].replay.is_empty()
		var clips: Array = session.game_clips(selected)
		for i in range(3):
			clip_buttons[i].visible = i < clips.size()
			if i < clips.size():
				clip_buttons[i].text = "%s / %s" % [format_time(clips[i].time),clips[i].title.left(23)]
	queue_redraw()

func display_frame() -> Dictionary:
	return sessions[active_session].frame(selected) if active_session >= 0 else {}

func set_focus(index: int) -> void:
	if page != "game":
		return
	follow_hero = clampi(index,-1,9)
	focus_choice.select(follow_hero+1)
	queue_redraw()

func arena_point(pos: Vector2) -> Vector2:
	return ARENA_RECT.position+battle_view.project_point(pos)

func focus_at(point: Vector2) -> void:
	var frame := display_frame()
	var nearest := -1
	var distance := INF
	for i in range(10):
		var u: Dictionary = frame.units[i]
		if u.hp <= 0:
			continue
		var gap := point.distance_to(arena_point(u.pos))
		if gap <= (u.radius*0.82+5)*battle_view.camera_zoom and gap < distance:
			nearest = i
			distance = gap
	if nearest >= 0:
		set_focus(nearest)

func toggle_fullscreen() -> void:
	get_window().mode = Window.MODE_WINDOWED if get_window().mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			toggle_fullscreen()
			get_viewport().set_input_as_handled()
		elif page == "game":
			if event.keycode == KEY_ESCAPE:
				if follow_hero >= 0:
					set_focus(-1)
				elif get_window().mode == Window.MODE_FULLSCREEN:
					get_window().mode = Window.MODE_WINDOWED
				get_viewport().set_input_as_handled()
			elif event.keycode >= KEY_0 and event.keycode <= KEY_5:
				set_focus(event.keycode-KEY_1)
				get_viewport().set_input_as_handled()
	if page != "game":
		return
	if event is InputEventMouseButton and event.pressed:
		var point := get_local_mouse_position()
		if event.button_index == MOUSE_BUTTON_LEFT and Rect2(42,232,224,335).has_point(point):
			set_focus(clampi(int((point.y-232)/65),0,4))
		if ARENA_RECT.has_point(point):
			if event.button_index == MOUSE_BUTTON_LEFT:
				focus_at(point)
			elif follow_hero >= 0 and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
				focus_zoom = clampf(focus_zoom+(0.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.2),1.5,3.5)

func _process(delta: float) -> void:
	# All queued sets advance, regardless of the selected page or open tabs.
	for session in sessions:
		session.advance(delta)
		if session.finished() and not session.rewarded:
			finish_session(session)
	if page == "game":
		battle_view.update_camera(delta)
	refresh_clock -= delta
	if refresh_clock <= 0:
		refresh_controls()
		refresh_clock = 0.25
	queue_redraw()
	if shot_delay > 0:
		shot_delay -= 1
		if shot_delay == 0:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(shot_path)
			get_tree().quit()

func finish_session(session) -> void:
	if session.rewarded:
		return
	session.rewarded = true
	session.running = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://match_exports"))
	var stamp := str(Time.get_unix_time_from_system()).replace(".","-")
	for battle in session.battles:
		var error: Error = battle.export_csv("user://match_exports/%s-%s.csv" % [stamp,battle.match_id])
		if error != OK:
			push_warning("Could not export completed game: "+error_string(error))
		for u in battle.units:
			if u.team == 0 and not u.creep:
				account.hero_kills += u.kills
				account.hero_saves += u.saves
	account.matches += 1
	account.wins += int(session.wins() >= 2)
	account.xp += 100+session.wins()*25
	status_note = "Set #%d complete / %d of 3 wins / +%d XP. Results remain in their game tabs." % [session.id,session.wins(),100+session.wins()*25]
	save_profile()
	refresh_controls()

func panel_style(color: Color, radius: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	return style

func button(value: String, rect: Rect2, action: Callable, accent: bool = false, parent: Node = null) -> Button:
	var control := Button.new()
	control.text = value
	control.position = rect.position
	control.size = rect.size
	control.add_theme_font_size_override("font_size",15)
	control.add_theme_color_override("font_color",INK if accent else TEXT)
	control.add_theme_stylebox_override("normal",panel_style(GOLD if accent else PANEL))
	control.add_theme_stylebox_override("hover",panel_style(Color("f7dfa9") if accent else Color("263954")))
	control.add_theme_stylebox_override("pressed",panel_style(Color("d3ad6e") if accent else Color("344760")))
	control.add_theme_stylebox_override("disabled",panel_style(Color("152033")))
	control.pressed.connect(action)
	(parent if parent != null else self).add_child(control)
	return control

func label_at(value: String, pos: Vector2, size: int = 16, color: Color = TEXT) -> void:
	draw_string(font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func box(rect: Rect2, color: Color = PANEL) -> void:
	draw_style_box(panel_style(color),rect)

func bar(rect: Rect2, fraction: float, color: Color) -> void:
	draw_style_box(panel_style(Color("263345"),3),rect)
	if fraction > 0:
		draw_style_box(panel_style(color,3),Rect2(rect.position,Vector2(rect.size.x*clampf(fraction,0,1),rect.size.y)))

func format_time(value: float) -> String:
	return "%02d:%02d" % [int(value)/60,int(value)%60]

func _draw() -> void:
	draw_rect(Rect2(0,0,1440,900),INK)
	draw_rect(Rect2(0,0,1440,82),Color("101b2b"))
	label_at("hero",Vector2(32,53),34)
	label_at("//",Vector2(108,53),34,GOLD)
	label_at("vault",Vector2(139,53),34)
	label_at("BUILD. QUEUE. WATCH.",Vector2(295,48),13,MUTED)
	label_at("%d ACTIVE SETS  /  %d XP" % [active_count(),account.xp],Vector2(911,47),12,GREEN)
	draw_line(Vector2(26,150),Vector2(1410,150),BORDER,1)
	if page == "home":
		draw_home()
	elif page == "game":
		draw_game()
	label_at(status_note.left(165),Vector2(32,883),12,MUTED)

func draw_home() -> void:
	box(Rect2(26,170,554,455))
	label_at("YOUR NEXT TEAM",Vector2(58,205),12,GOLD)
	label_at(squad_name.left(25),Vector2(58,246),27)
	label_at("%d / 18 item points  /  5 heroes" % Catalog.budget(equipment),Vector2(58,274),14,MUTED)
	for i in range(5):
		var x := 62+i*98
		draw_texture_rect(portraits[team[i]],Rect2(x,310,64,64),false)
		label_at(Catalog.HEROES[team[i]].name.split(" ")[0],Vector2(x,398),12)
		label_at(["North","South","Roam"][lane_orders[i]],Vector2(x,419),11,MUTED)
	label_at("LOCAL RIVALS / BEST OF THREE",Vector2(58,456),12,GREEN)
	label_at("Queue the saved team. Each game opens in its own tab.",Vector2(58,596),13,MUTED)
	box(Rect2(26,641,554,204))
	label_at("ROOM TO EXPERIMENT",Vector2(58,675),12,GOLD)
	label_at("Change your next team while games play.",Vector2(58,710),18)
	label_at("Your queued lineup stays intact. Tabs are just views.",Vector2(58,742),14,MUTED)
	var dirty: bool = loadout_panel != null and loadout_panel.is_dirty()
	label_at("Unsaved team edits / queue uses your last save." if dirty else "Your saved team is ready to queue.",Vector2(58,795),13,GOLD if dirty else GREEN)
	box(Rect2(612,170,798,675))
	label_at("YOUR GAMES",Vector2(646,209),20)
	label_at("%d SETS THIS SESSION" % sessions.size(),Vector2(1180,207),11,MUTED)
	if sessions.is_empty():
		draw_arc(Vector2(1010,385),48,0,TAU,6,Color("4d697f"),2,true)
		label_at("+",Vector2(994,400),45,GOLD)
		label_at("Your first story starts here.",Vector2(825,488),25)
		label_at("Choose a lineup in Team Builder, then queue from Home.",Vector2(730,533),16,MUTED)
		label_at("Three local opponents. Three game tabs. One team to test.",Vector2(730,568),16,MUTED)
	label_at("Closed a tab? Reopen any game here. Live games keep running.",Vector2(646,823),13,MUTED)

func draw_game() -> void:
	var session = sessions[active_session]
	var frame := display_frame()
	var view: Dictionary = session.views[selected]
	box(Rect2(26,168,256,692))
	label_at("QUEUED LINEUP / #%d" % session.id,Vector2(42,200),12,GOLD)
	label_at(session.squad_name.left(25),Vector2(42,224),16)
	for i in range(5):
		var u: Dictionary = frame.units[i]
		var y := 237+i*65
		if follow_hero == i:
			box(Rect2(37,y-4,232,61),Color("23364c"))
		draw_texture_rect(portraits[u.portrait],Rect2(42,y,45,45),false)
		label_at(u.name.left(21),Vector2(98,y+16),14)
		label_at("L%d / %s" % [u.level,"KO" if u.hp <= 0 else "North" if u.lane == 0 else "South"],Vector2(98,y+34),11,MUTED)
		bar(Rect2(98,y+44,153,4),u.hp/u.max_hp,BLUE)
	var hero: Dictionary = frame.units[maxi(0,follow_hero)]
	label_at(hero.name.to_upper().left(22),Vector2(42,610),19,GOLD)
	label_at(Catalog.HEROES[hero.portrait].role.left(28),Vector2(42,637),12,MUTED)
	label_at("ULT / %ds" % int(ceil(hero.ultimate)) if hero.ultimate > 0 else "ULT / READY",Vector2(42,666),13,GOLD)
	label_at("MATCH EQUIPMENT",Vector2(42,701),11,MUTED)
	for i in range(hero.items.size()):
		var title: String = Catalog.ITEMS[hero.items[i]].name
		var stolen := false
		for loan in frame.get("thefts",[]):
			stolen = stolen or (loan.owner == hero.id and loan.slot == i)
		label_at(title+(" [STOLEN]" if stolen else ""),Vector2(42,731+i*25),12,RED if stolen else TEXT)
	label_at("%d kills / %d deaths" % [hero.kills,hero.deaths],Vector2(42,801),14)
	label_at("Saved-team edits apply to new games.",Vector2(42,838),10,MUTED)
	box(Rect2(306,168,816,555),Color("101c2a"))
	var mode := "REPLAY" if not view.replay.is_empty() else game_status(session,selected)
	label_at("%s / %s" % [RIVALS[selected].to_upper(),mode],Vector2(326,195),12,GREEN)
	label_at(format_time(frame.time),Vector2(1030,197),22)
	label_at("%d TAKEDOWNS" % frame.kills[0],Vector2(325,649),11,BLUE)
	label_at("%d TAKEDOWNS" % frame.kills[1],Vector2(997,649),11,RED)
	label_at("Click a hero / 1–5 follow / Scroll zoom / Esc overview",Vector2(500,649),11,MUTED)
	if view.replay.is_empty():
		label_at("Pause and speed apply to this three-game set.",Vector2(322,696),12,MUTED)
	else:
		label_at("Live games continue",Vector2(500,696),12,GOLD)
	box(Rect2(306,738,816,122))
	label_at("HERO IN FOCUS / "+hero.name.to_upper(),Vector2(325,767),12,GOLD)
	label_at(Catalog.HEROES[hero.portrait].kit,Vector2(325,795),17)
	label_at("Damage: %d  /  Healing: %d  /  Item triggers: %d" % [hero.damage_done,hero.healing_done,hero.item_procs],Vector2(325,827),13,MUTED)
	draw_story(session,frame,hero)

func draw_story(session, frame: Dictionary, hero: Dictionary) -> void:
	box(Rect2(1144,168,266,692))
	label_at("SET #%d / %d OF 3 WINS" % [session.id,session.wins()],Vector2(1160,201),12,GOLD)
	label_at("Win two games to take the set.",Vector2(1160,226),12,MUTED)
	for i in range(3):
		label_at(RIVALS[i],Vector2(1160,253+i*24),12)
		label_at(game_status(session,i),Vector2(1340,253+i*24),10,GREEN if session.battles[i].winner == 0 else MUTED)
	draw_line(Vector2(1160,320),Vector2(1393,320),BORDER)
	label_at("FIGHT STORY",Vector2(1160,348),12,GOLD)
	var events: Array = session.battles[selected].events.filter(func(event):return event.time <= frame.time and event.kind not in ["hop","level","info","deploy"])
	var start := maxi(0,events.size()-5)
	for i in range(start,events.size()):
		var event: Dictionary = events[i]
		var y := 379+(i-start)*45
		label_at(format_time(event.time),Vector2(1160,y),10,MUTED)
		label_at(event.title.left(25),Vector2(1200,y),11)
		label_at(event.detail.left(35),Vector2(1160,y+17),11,MUTED)
	label_at("SAVED MOMENTS / THIS GAME",Vector2(1160,640),11,GOLD)
	if session.game_clips(selected).is_empty():
		label_at("Clutches appear here as you play.",Vector2(1160,684),11,MUTED)
	label_at("OBSERVED INTENT",Vector2(1160,817),10,MUTED)
	label_at(hero.intent.left(32),Vector2(1160,841),12,BLUE)

func save_profile() -> void:
	var file := FileAccess.open("user://squad.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"squad_name": squad_name, "plan": plan, "assignment": assignment, "account": account, "team": team, "equipment": equipment, "lane_orders": lane_orders, "queue_number": queue_number}))

func load_profile() -> void:
	if not FileAccess.file_exists("user://squad.json"):
		return
	var value = JSON.parse_string(FileAccess.get_file_as_string("user://squad.json"))
	if value is Dictionary:
		queue_number = maxi(account.matches, int(value.get("queue_number", 0)))
		var saved_team = value.get("team", Catalog.DEFAULT_TEAM)
		var saved_items = value.get("equipment", Catalog.DEFAULT_ITEMS)
		# Retain the user's roster while replacing retired equipment with empty slots.
		if saved_items is Array:
			for row in saved_items:
				if row is Array:
					for i in range(row.size()):
						if not Catalog.ITEMS.has(row[i]):
							row[i] = "none"
		if saved_team is Array and saved_items is Array and Catalog.validate(saved_team, saved_items) == "":
			team = saved_team.duplicate()
			equipment = saved_items.duplicate(true)
		var saved_orders = value.get("lane_orders", [0, 0, 1, 1, 2])
		if saved_orders is Array and saved_orders.size() == 5:
			for i in range(5):
				lane_orders[i] = clampi(int(saved_orders[i]), 0, 2)
		squad_name = str(value.get("squad_name", squad_name)).left(26)
		plan = clampi(int(value.get("plan", 0)), 0, 2)
		assignment = clampi(int(value.get("assignment", 0)), 0, 2)
		if value.get("account") is Dictionary:
			for key in account:
				account[key] = maxi(0, int(value.account.get(key, 0)))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_profile()
