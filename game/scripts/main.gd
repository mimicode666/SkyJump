extends Node3D

const Rules = preload("res://scripts/jump_rules.gd")
const Characters = preload("res://scripts/characters.gd")
const JumpPlatform = preload("res://scripts/jump_platform.gd")
const Catalog = preload("res://scripts/catalog.gd")
const TouchDirection = preload("res://scripts/touch_direction.gd")
const COLORS = [Color("65b333"), Color("efaa25"), Color("935aca")]
var characters = Characters.new()
var selected: String = "emil"
var mode: String = "menu"
var player: Node3D
var visual: Node3D
var camera: Camera3D
var world: Node3D
var clouds: Node3D
var platform_nodes: Array[Node3D] = []
var platforms: Array[Vector3] = []
var velocity := Vector2.ZERO
var highest: float = 0.0
var camera_height: float = 2.3
var rng := RandomNumberGenerator.new()
var menu: Control
var hud: Control
var overlay: Control
var overlay_title: Label
var overlay_text: Label
var resume_button: Button
var score_label: Label
var record_label: Label
var model_label: Label
var play_button: Button
var touch_left: bool = false
var touch_right: bool = false
var bounce_flash: float = 0.0
var session_best: int = 0
var landings: int = 0
var last_landing_y: float = 0.0
var generated_count: int = 0
var last_generated: Vector3 = Vector3.ZERO
var before_last_generated: Vector3 = Vector3.INF
var last_was_stone: bool = false
var broken_platforms: Array[Node3D] = []
var automated: bool = false
var ui: Dictionary = {}
var portrait := false
var compact := false
var touch_controls := false
var layout_pending := false
var menu_page := "home"
var selected_map := "clouds"
var sky_material: ProceduralSkyMaterial
var cloud_material: StandardMaterial3D
var last_was_moving := false

func _ready() -> void:
	Engine.max_fps = 60
	_rng_setup()
	_setup_world()
	_setup_ui()
	select_character("emil")
	get_window().size_changed.connect(_queue_layout)
	_resize_ui()
	if "--self-test" in OS.get_cmdline_user_args():
		automated = true
		call_deferred("_run_self_test")

func _rng_setup() -> void:
	rng.randomize()
	for action in ["move_left", "move_right"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	for code in [KEY_A, KEY_LEFT]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		InputMap.action_add_event("move_left", event)
	for code in [KEY_D, KEY_RIGHT]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		InputMap.action_add_event("move_right", event)

func material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _setup_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("64c9f0")
	sky_material.sky_horizon_color = Color("e6f5f9")
	sky_material.ground_horizon_color = Color("e6f5f9")
	sky_material.ground_bottom_color = Color("d6edfc")
	sky_material.sky_curve = 0.3
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff7eb")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.8
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	sun.light_energy = 0.85
	sun.shadow_enabled = false
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 145, 0)
	fill.light_color = Color("dbeeff")
	fill.light_energy = 0.25
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.5
	camera.current = true
	add_child(camera)
	world = Node3D.new()
	add_child(world)
	clouds = Node3D.new()
	add_child(clouds)
	cloud_material = material(Color("f5fcff"), true)
	for i in range(10):
		var cloud := Node3D.new()
		cloud.position = Vector3((-1.0 if i % 2 == 0 else 1.0) * rng.randf_range(6.0, 9.0), i * 2.4 - 5.0, -5.0 - rng.randf_range(0, 5))
		for j in range(3):
			var puff := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radial_segments = 12
			sphere.rings = 6
			puff.mesh = sphere
			puff.material_override = cloud_material
			puff.scale = Vector3(2.4, 0.85 + (0.4 if j == 1 else 0.0), 1.1)
			puff.position.x = (j - 1) * 1.1
			cloud.add_child(puff)
		clouds.add_child(cloud)
	player = Node3D.new()
	add_child(player)
	_update_camera(1.0)
	_add_platform(Vector3(1.5, 0, 0), 0)

func _add_platform(pos: Vector3, index: int, stone: bool = false, kind: String = "normal") -> void:
	var node := JumpPlatform.new()
	node.position = pos
	node.configure(COLORS[index % COLORS.size()], stone, kind)
	world.add_child(node)
	platforms.append(pos)
	platform_nodes.append(node)

func _generate_platform() -> void:
	var next: Vector3 = Rules.next_platform(last_generated, rng, before_last_generated)
	var kind := "normal"
	if generated_count >= 4:
		var roll := rng.randf()
		if roll < 0.18 and not last_was_stone:
			kind = "stone"
		elif roll < 0.40 and not last_was_moving and absf(next.x) < 2.85:
			kind = "moving"
		elif roll > 0.85:
			kind = "boost"
	_add_platform(next, generated_count, kind == "stone", kind)
	# Hazards are optional side platforms; the main route always remains safe.
	if generated_count >= 6 and rng.randf() < 0.20:
		var hazard_x: float = -3.45 if next.x >= 0 else 3.45
		if absf(hazard_x - next.x) > 3.0:
			_add_platform(Vector3(hazard_x, next.y, 0), generated_count, false, "spikes")
	before_last_generated = last_generated
	last_generated = next
	last_was_stone = kind == "stone"
	last_was_moving = kind == "moving"
	generated_count += 1

func _clear_platforms() -> void:
	for node in world.get_children():
		world.remove_child(node)
		node.queue_free()
	platforms.clear()
	platform_nodes.clear()
	broken_platforms.clear()

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 20
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ffffff")
	style.set_corner_radius_all(18)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 13
	style.content_margin_bottom = 13
	style.shadow_color = Color(0.23, 0.46, 0.58, 0.15)
	style.shadow_size = 7
	theme.set_stylebox("normal", "Button", style)
	var hover := style.duplicate()
	hover.bg_color = Color("e8f6ff")
	theme.set_stylebox("hover", "Button", hover)
	var pressed := style.duplicate()
	pressed.bg_color = Color("d6edc0")
	pressed.border_color = Color("7bb450")
	pressed.set_border_width_all(3)
	theme.set_stylebox("pressed", "Button", pressed)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("457599")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(18)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", Color("315470"))
	theme.set_color("font_hover_color", "Button", Color("315470"))
	theme.set_color("font_pressed_color", "Button", Color("315470"))
	theme.set_color("font_focus_color", "Button", Color("315470"))
	theme.set_color("font_hover_pressed_color", "Button", Color("315470"))
	theme.set_color("font_color", "Label", Color("315470"))
	root.theme = theme
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(menu)
	var title := _label("ПРЫЖОК В ОБЛАКА", 16)
	title.position = Vector2(46, 28)
	menu.add_child(title)
	var heading := _label("SkyJump", 44)
	heading.position = Vector2(46, 56)
	menu.add_child(heading)
	var subtitle := _label("Выберите, кто сегодня прыгнет выше", 20)
	subtitle.position = Vector2(48, 117)
	menu.add_child(subtitle)
	var pickers := VBoxContainer.new()
	pickers.position = Vector2(48, 195)
	pickers.add_theme_constant_override("separation", 12)
	menu.add_child(pickers)
	var character_choice := _button("", func(): _open_menu_page("characters"))
	var map_choice := _button("", func(): _open_menu_page("maps"))
	pickers.add_child(character_choice)
	pickers.add_child(map_choice)
	var options := ScrollContainer.new()
	options.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(options)
	var option_list := VBoxContainer.new()
	option_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_list.add_theme_constant_override("separation", 10)
	options.add_child(option_list)
	model_label = _label("", 16)
	model_label.position = Vector2(48, 265)
	menu.add_child(model_label)
	var menu_bottom := VBoxContainer.new()
	menu_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	menu_bottom.position = Vector2(48, -160)
	menu_bottom.add_theme_constant_override("separation", 15)
	menu.add_child(menu_bottom)
	play_button = _button("Прыгать!", func():
		if menu_page == "home": start_game()
		else: _open_menu_page("home"))
	play_button.custom_minimum_size = Vector2(240, 60)
	menu_bottom.add_child(play_button)
	var menu_hint := _label("", 16)
	menu_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_bottom.add_child(menu_hint)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	score_label = _label("0 м", 42)
	score_label.position = Vector2(38, 24)
	hud.add_child(score_label)
	record_label = _label("", 16)
	record_label.position = Vector2(40, 78)
	hud.add_child(record_label)
	var pause_button := _button("Пауза", pause_game)
	pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause_button.position = Vector2(-195, 28)
	hud.add_child(pause_button)
	var hint := _label("Стрелки или A / D       ·       Esc — пауза", 16)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(40, -44)
	hud.add_child(hint)
	var touch_pads: Array[Control] = []
	for side in [-1, 1]:
		var touch := TouchDirection.new()
		touch.direction = side
		touch.held_changed.connect(func(pressed: bool): _set_touch(side, pressed))
		hud.add_child(touch)
		touch_pads.append(touch)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.8, 0.92, 1.0, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 330
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)
	overlay_title = _label("", 40)
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(overlay_title)
	overlay_text = _label("", 22)
	overlay_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(overlay_text)
	resume_button = _button("Продолжить", resume_game)
	column.add_child(resume_button)
	column.add_child(_button("Ещё раз", start_game))
	column.add_child(_button("Главное меню", show_menu))
	ui = {"title": title, "heading": heading, "subtitle": subtitle, "pickers": pickers,
		"bottom": menu_bottom, "menu_hint": menu_hint, "pause": pause_button,
		"hint": hint, "column": column, "pads": touch_pads,
		"character_choice": character_choice, "map_choice": map_choice, "options": options, "option_list": option_list}
	hud.hide()
	overlay.hide()
	_open_menu_page("home")

func _queue_layout() -> void:
	if not layout_pending:
		layout_pending = true
		call_deferred("_resize_ui")

func _place(control: Control, position: Vector2, dimensions: Vector2) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = position
	control.size = dimensions

func _resize_ui() -> void:
	layout_pending = false
	if ui.is_empty():
		return
	var pixels := Vector2(get_window().size)
	var scale_factor: float = clampf(minf(pixels.x, pixels.y) / 390.0, 0.65, 1.25)
	var logical := Vector2i((pixels / scale_factor).round())
	if get_window().content_scale_size != logical:
		get_window().content_scale_size = logical
	var area := Vector2(logical)
	portrait = area.x < area.y * 0.85
	compact = portrait or area.y < 560 or area.x < 760
	touch_controls = compact or DisplayServer.is_touchscreen_available()
	var margin: float = 22.0 if compact else 46.0
	var menu_width: float = area.x - margin * 2 if portrait else minf(440, area.x * 0.52 - margin)
	_place(ui.title, Vector2(margin, 24), Vector2(menu_width, 24))
	ui.heading.add_theme_font_size_override("font_size", 30 if compact else 44)
	_place(ui.heading, Vector2(margin, 53), Vector2(menu_width, 52))
	ui.subtitle.text = "Выберите героя и отправляйтесь в небо" if menu_page == "home" else ("Нажмите, чтобы выбрать героя" if menu_page == "characters" else "Нажмите, чтобы сменить фон")
	ui.subtitle.add_theme_font_size_override("font_size", 16 if compact else 20)
	ui.subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(ui.subtitle, Vector2(margin, 98 if compact else 117), Vector2(menu_width, 42))
	_place(ui.pickers, Vector2(margin, 145 if compact else 195), Vector2(menu_width, 120))
	for button in [ui.character_choice, ui.map_choice]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 54)
	_place(model_label, Vector2(margin, 272 if compact else 330), Vector2(menu_width, 46))
	model_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bottom_height: float = 132 if portrait else (115 if compact else 155)
	_place(ui.bottom, Vector2(margin, area.y - bottom_height), Vector2(menu_width, 0))
	play_button.custom_minimum_size = Vector2(0, 58)
	ui.bottom.add_theme_constant_override("separation", 10 if compact else 15)
	ui.menu_hint.text = ("Удерживайте кнопки внизу экрана\nПрыжки — автоматически" if touch_controls else "A / D или стрелки — движение\nПрыжки — автоматически") if menu_page == "home" else "Выбор сохранён для следующего прыжка"
	ui.pickers.visible = menu_page == "home"
	ui.options.visible = menu_page != "home"
	var options_y: float = area.y - bottom_height - 150 if portrait else 160.0
	_place(ui.options, Vector2(margin, options_y), Vector2(menu_width, 132 if portrait else maxf(100, area.y - bottom_height - options_y - 18)))
	_place(score_label, Vector2(margin, 20), Vector2(180, 48))
	score_label.add_theme_font_size_override("font_size", 34 if compact else 42)
	_place(record_label, Vector2(margin, 65 if compact else 78), Vector2(180, 24))
	_place(ui.pause, Vector2(area.x - margin - 112, 24), Vector2(112, 52))
	ui.hint.visible = not touch_controls
	_place(ui.hint, Vector2(margin, area.y - 40), Vector2(area.x - margin * 2, 24))
	var pad_width: float = minf(132, (area.x - margin * 3) * 0.5)
	var pad_height: float = 76 if portrait else 64
	for i in range(2):
		var pad: Control = ui.pads[i]
		pad.visible = touch_controls and mode not in ["paused", "gameover"]
		_place(pad, Vector2(margin if i == 0 else area.x - margin - pad_width, area.y - pad_height - 28), Vector2(pad_width, pad_height))
	ui.column.custom_minimum_size.x = minf(380, area.x - margin * 2)
	ui.column.size.x = ui.column.custom_minimum_size.x
	ui.column.add_theme_constant_override("separation", 12 if compact else 18)
	overlay_title.add_theme_font_size_override("font_size", 28 if compact else 40)
	overlay_text.add_theme_font_size_override("font_size", 20 if compact else 22)
	for child in ui.column.get_children():
		if child is Button:
			child.custom_minimum_size.y = 52
	_reset_touch()
	_update_camera(1.0)

func _reset_touch() -> void:
	touch_left = false
	touch_right = false
	for pad in ui.get("pads", []):
		pad.reset()

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	return button

func _set_touch(side: int, pressed: bool) -> void:
	if side == -1:
		touch_left = pressed
	else:
		touch_right = pressed

func select_character(id: String) -> void:
	selected = id
	if visual != null:
		player.remove_child(visual)
		visual.queue_free()
	visual = characters.create_character(id, 3.3 if mode == "menu" else 1.6)
	if visual == null:
		model_label.text = "Не удалось открыть модель. Проверьте папку assets/models."
		play_button.disabled = true
		return
	play_button.disabled = false
	player.add_child(visual)
	player.position = Vector3(1.5, 0, 0) if mode == "menu" else Vector3.ZERO
	visual.rotation.y = -0.13
	_update_choice_labels()
	model_label.text = ""

func _update_choice_labels() -> void:
	for entry in Catalog.CHARACTERS:
		if entry.id == selected:
			ui.character_choice.text = "Персонаж: " + entry.name
	for entry in Catalog.MAPS:
		if entry.id == selected_map:
			ui.map_choice.text = "Карта: " + entry.name
	for button in ui.option_list.get_children():
		button.set_pressed_no_signal(button.get_meta("choice") == (selected if menu_page == "characters" else selected_map))

func _open_menu_page(page: String) -> void:
	menu_page = page
	ui.title.text = "ПРЫЖОК В ОБЛАКА" if page == "home" else "SkyJump"
	ui.heading.text = "SkyJump" if page == "home" else ("Персонажи" if page == "characters" else "Карты")
	play_button.text = "Прыгать!" if page == "home" else "Готово"
	for child in ui.option_list.get_children():
		ui.option_list.remove_child(child)
		child.queue_free()
	if page != "home":
		for entry in (Catalog.CHARACTERS if page == "characters" else Catalog.MAPS):
			var id: String = entry.id
			var button := _button(entry.name, func():
				if page == "characters": select_character(id)
				else: select_map(id)
				_update_choice_labels())
			button.toggle_mode = true
			button.custom_minimum_size.y = 54
			button.set_meta("choice", id)
			ui.option_list.add_child(button)
	_update_choice_labels()
	_resize_ui()

func select_map(id: String) -> void:
	for entry in Catalog.MAPS:
		if entry.id != id: continue
		selected_map = id
		sky_material.sky_top_color = entry.top
		sky_material.sky_horizon_color = entry.horizon
		sky_material.ground_horizon_color = entry.horizon
		sky_material.ground_bottom_color = entry.bottom
		cloud_material.albedo_color = entry.cloud
	_update_choice_labels()

func start_game() -> void:
	mode = "playing"
	_reset_touch()
	_clear_platforms()
	generated_count = 1
	last_generated = Vector3.ZERO
	before_last_generated = Vector3.INF
	last_was_stone = false
	last_was_moving = false
	highest = 0
	landings = 0
	last_landing_y = 0.0
	player.scale = Vector3.ONE
	camera_height = 2.3
	select_character(selected)
	velocity = Vector2(0, Rules.JUMP_SPEED)
	_add_platform(Vector3.ZERO, 0)
	while last_generated.y < 18:
		_generate_platform()
	menu.hide()
	overlay.hide()
	hud.show()
	for pad in ui.pads: pad.visible = touch_controls
	_update_camera(1.0)
	score_label.text = "0 м"
	record_label.text = "Рекорд: %d м" % session_best

func _physics_process(delta: float) -> void:
	if mode != "playing":
		return
	for i in range(platform_nodes.size()):
		platform_nodes[i].advance_motion(delta)
		platforms[i] = platform_nodes[i].position
	var direction: float = Input.get_axis("move_left", "move_right")
	if touch_left or touch_right:
		direction = float(touch_right) - float(touch_left)
	velocity.x = move_toward(velocity.x, direction * Rules.MOVE_SPEED, Rules.ACCELERATION * delta)
	var previous_y: float = player.position.y
	velocity.y -= Rules.GRAVITY * delta
	player.position.x = Rules.wrap_x(player.position.x + velocity.x * delta, _wrap_half_width())
	player.position.y += velocity.y * delta
	for i in range(platforms.size()):
		if Rules.lands(previous_y, player.position.y, velocity.y, player.position.x, platforms[i] + Vector3(0, 0.42 if platform_nodes[i].kind == "spikes" else 0.0, 0)):
			if platform_nodes[i].kind == "spikes":
				finish_game()
				return
			player.position.y = platforms[i].y
			velocity.y = Rules.BOOST_SPEED if platform_nodes[i].kind == "boost" else Rules.JUMP_SPEED
			bounce_flash = 1.0
			landings += 1
			last_landing_y = platforms[i].y
			if platform_nodes[i].register_landing():
				var broken: Node3D = platform_nodes[i]
				platforms.remove_at(i)
				platform_nodes.remove_at(i)
				broken.break_apart()
				broken_platforms.append(broken)
			break
	highest = maxf(highest, player.position.y)
	camera_height = maxf(camera_height, highest + 1.0)
	score_label.text = "%d м" % int(highest * 10.0)
	while last_generated.y < camera_height + 12.0:
		_generate_platform()
	while platforms.size() > 0 and platforms[0].y < camera_height - 10:
		platforms.pop_front()
		platform_nodes.pop_front().queue_free()
	if player.position.y < camera_height - 7.0:
		finish_game()

func _process(delta: float) -> void:
	if mode == "menu" and visual != null:
		visual.rotation.y = sin(Time.get_ticks_msec() * 0.00045) * 0.22
	if mode == "playing" and visual != null:
		visual.rotation.z = lerpf(visual.rotation.z, -velocity.x * 0.035, delta * 10.0)
		bounce_flash = maxf(0, bounce_flash - delta * 5)
		player.scale = Vector3(1.0 + bounce_flash * 0.08, 1.0 - bounce_flash * 0.1, 1.0 + bounce_flash * 0.08)
		for i in range(platforms.size()):
			var p: Vector3 = platforms[i]
			var overlaps: bool = player.position.y < p.y - 0.05 and player.position.y + 1.6 > p.y and absf(player.position.x - p.x) < 1.4
			platform_nodes[i].set_obscured(overlaps)
		for i in range(broken_platforms.size() - 1, -1, -1):
			if not is_instance_valid(broken_platforms[i]):
				broken_platforms.remove_at(i)
			else:
				broken_platforms[i].animate_break(delta)
	_update_camera(delta)
	for cloud in clouds.get_children():
		if cloud.position.y < camera_height - 9:
			cloud.position.y += 25
		while cloud.position.y > camera_height + 16:
			cloud.position.y -= 25

func _update_camera(delta: float) -> void:
	var target_y: float = 1.5 if mode == "menu" else camera_height
	if mode == "menu" and portrait and not ui.is_empty():
		var area := Vector2(get_window().content_scale_size)
		var model_center: float = (270.0 + ui.bottom.position.y) * 0.5 if menu_page == "home" else (140.0 + ui.options.position.y) * 0.5
		target_y = 1.65 + (model_center - area.y * 0.5) * 7.2 / area.x
	var target_x: float = (1.5 if portrait else -0.7) if mode == "menu" else 0.0
	var desired := Vector3(target_x, target_y + 4.0, 13)
	camera.position = camera.position.lerp(desired, minf(delta * 7.0, 1.0))
	camera.look_at(Vector3(target_x, camera.position.y - 4.0, 0), Vector3.UP)
	camera.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
	camera.size = (7.2 if portrait else 8.7) if mode == "menu" else (10.6 if portrait else 10.0)

func _wrap_half_width() -> float:
	var area := get_viewport().get_visible_rect().size
	return camera.size * 0.5 if camera.keep_aspect == Camera3D.KEEP_WIDTH else camera.size * area.x / maxf(area.y, 1.0) * 0.5

func pause_game() -> void:
	if mode != "playing":
		return
	_reset_touch()
	for pad in ui.pads: pad.hide()
	mode = "paused"
	overlay_title.text = "Передохнём?"
	overlay_text.text = "Высота: %d м" % int(highest * 10)
	resume_button.show()
	overlay.show()
	resume_button.grab_focus()

func resume_game() -> void:
	mode = "playing"
	for pad in ui.pads: pad.visible = touch_controls
	overlay.hide()

func finish_game() -> void:
	_reset_touch()
	for pad in ui.pads: pad.hide()
	mode = "gameover"
	session_best = maxi(session_best, int(highest * 10))
	overlay_title.text = "Ещё один прыжок?"
	overlay_text.text = "Высота: %d м\nРекорд: %d м" % [int(highest * 10), session_best]
	resume_button.hide()
	overlay.show()

func show_menu() -> void:
	_reset_touch()
	mode = "menu"
	_clear_platforms()
	_add_platform(Vector3(1.5, 0, 0), 0)
	player.scale = Vector3.ONE
	camera_height = 2.3
	select_character(selected)
	_open_menu_page("home")
	menu.show()
	hud.hide()
	overlay.hide()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if mode == "playing":
				pause_game()
			elif mode == "paused":
				resume_game()
			elif mode == "menu" and menu_page != "home":
				_open_menu_page("home")
		elif event.keycode == KEY_R and mode == "gameover":
			start_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == "playing" and not automated:
		pause_game()

func _run_mechanics_tests() -> void:
	_open_menu_page("characters")
	assert(ui.option_list.get_child_count() == Catalog.CHARACTERS.size())
	select_character("sveta")
	_open_menu_page("maps")
	select_map("sunset")
	assert(selected_map == "sunset" and sky_material.sky_top_color == Catalog.MAPS[1].top)
	select_map("clouds")
	_open_menu_page("home")
	start_game()
	_clear_platforms()
	last_generated.y = 1000
	_add_platform(Vector3.ZERO, 0, false, "boost")
	player.position = Vector3(0, 2, 0)
	velocity = Vector2(0, -1)
	for frame in range(60):
		await get_tree().physics_frame
		if landings > 0: break
	assert(velocity.y > Rules.JUMP_SPEED + 3, "Boost did not increase bounce")
	# Dynamic platform positions must match collision positions, including after pausing.
	_clear_platforms()
	_add_platform(Vector3(0, 2, 0), 0, false, "moving")
	var moving = platform_nodes[0]
	var initial_x: float = moving.position.x
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(not is_equal_approx(initial_x, moving.position.x))
	assert(platforms[0] == moving.position)
	pause_game()
	var stopped: Vector3 = moving.position
	await get_tree().physics_frame
	assert(stopped == moving.position)
	resume_game()
	# Cross the actual visible edge in both directions and preserve momentum.
	for direction in [-1.0, 1.0]:
		player.position = Vector3(direction * (_wrap_half_width() - 0.01), 2, 0)
		velocity = Vector2(direction * Rules.MOVE_SPEED, Rules.JUMP_SPEED)
		Input.action_press("move_left" if direction < 0 else "move_right")
		await get_tree().physics_frame
		await get_tree().physics_frame
		assert(signf(player.position.x) == -direction, "Screen wrap failed")
		Input.action_release("move_left")
		Input.action_release("move_right")
	# Exercise real touch-event handling, simultaneous fingers and cancellation.
	var left: Control = ui.pads[0]
	var right: Control = ui.pads[1]
	left.show()
	right.show()
	var touch := InputEventScreenTouch.new()
	touch.index = 10
	touch.position = get_viewport().get_stretch_transform() * left.get_global_rect().get_center()
	touch.pressed = true
	Input.parse_input_event(touch)
	Input.flush_buffered_events()
	await get_tree().process_frame
	assert(touch_left, "Left touch did not hold")
	var other := InputEventScreenTouch.new()
	other.index = 11
	other.position = get_viewport().get_stretch_transform() * right.get_global_rect().get_center()
	other.pressed = true
	Input.parse_input_event(other)
	Input.flush_buffered_events()
	await get_tree().process_frame
	assert(touch_left and touch_right)
	touch.pressed = false
	touch.canceled = true
	Input.parse_input_event(touch)
	Input.flush_buffered_events()
	await get_tree().process_frame
	assert(not touch_left and touch_right)
	pause_game()
	assert(not touch_left and not touch_right)
	resume_game()
	_clear_platforms()
	_add_platform(Vector3.ZERO, 0, false, "spikes")
	player.position = Vector3(0, 2, 0)
	velocity = Vector2(0, -1)
	camera_height = 2.3
	for frame in range(60):
		await get_tree().physics_frame
		if mode == "gameover": break
	assert(mode == "gameover" and player.position.y > 0, "Spikes did not end the run")
	show_menu()
	print("SKYJUMP_MECHANICS_OK boost moving pause wrap_left wrap_right multitouch cancel spikes catalogs")

func _run_self_test() -> void:
	await _run_mechanics_tests()
	var test_rng := RandomNumberGenerator.new()
	test_rng.seed = 123
	var pos := Vector3.ZERO
	var before := Vector3.INF
	for i in range(1000):
		var next: Vector3 = Rules.next_platform(pos, test_rng, before)
		assert(absf(next.x - pos.x) <= Rules.MAX_STEP_X + 0.001)
		assert(next.y - pos.y < Rules.JUMP_SPEED * Rules.JUMP_SPEED / (2.0 * Rules.GRAVITY))
		before = pos
		pos = next
	assert(Rules.lands(2.0, 1.4, -2.0, 0.5, Vector3(0, 1.6, 0)))
	assert(not Rules.lands(1.4, 2.0, 2.0, 0.0, Vector3(0, 1.6, 0)))
	assert(not Rules.lands(2.0, 1.4, -2.0, 3.0, Vector3(0, 1.6, 0)))
	# Bounce on one isolated stone twice using real physics, then verify removal.
	start_game()
	_clear_platforms()
	_add_platform(Vector3.ZERO, 0, true)
	var stone = platform_nodes[0]
	for frame in range(80):
		await get_tree().physics_frame
		if stone.hits == 1:
			break
	assert(stone.hits == 1 and platforms.size() == 1)
	pause_game()
	var stone_hits: int = stone.hits
	await get_tree().physics_frame
	assert(stone.hits == stone_hits)
	resume_game()
	for frame in range(80):
		await get_tree().physics_frame
		if stone.hits == 2:
			break
	assert(stone.hits == 2 and platforms.is_empty() and velocity.y > 0.0)
	assert(broken_platforms.size() == 1)
	show_menu()
	assert(broken_platforms.is_empty())
	print("STONE_PHYSICS_OK first=cracked second=removed bounce=preserved reset=clean")
	assert(visual != null)
	select_character("sveta")
	assert(visual != null)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not OS.has_feature("web"):
		get_viewport().get_texture().get_image().save_png("res://../qa/game-menu-sveta.png")
	select_character("emil")
	assert(visual != null and characters.cache.size() == 2)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not OS.has_feature("web"):
		get_viewport().get_texture().get_image().save_png("res://../qa/game-menu.png")
	rng.seed = 77
	start_game()
	# A small deterministic pilot exercises actual physics, landings and scrolling.
	for i in range(1800):
		var target: Vector3 = platforms[0]
		for p in platforms:
			if p.y > last_landing_y + 0.1 and platform_nodes[platforms.find(p)].kind != "spikes":
				target = p
				break
		var difference: float = target.x - player.position.x - velocity.x * 0.12
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(difference) > 0.1:
			Input.action_press("move_right" if difference > 0 else "move_left")
		await get_tree().physics_frame
		if i == 300:
			await RenderingServer.frame_post_draw
			if not OS.has_feature("web"):
				get_viewport().get_texture().get_image().save_png("res://../qa/game-playing.png")
		if mode == "gameover":
			break
	Input.action_release("move_left")
	Input.action_release("move_right")
	assert(landings >= 20, "Pilot did not complete enough of the harder route")
	assert(platforms.size() < 32, "Unbounded platform count")
	print("MVP_PLAYTEST height=", highest, " landings=", landings, " platforms=", platforms.size())
	print("MVP_PERFORMANCE fps=", Engine.get_frames_per_second(), " rendered_primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	if mode == "playing":
		pause_game()
		var frozen: Vector3 = player.position
		await get_tree().physics_frame
		assert(player.position == frozen)
		resume_game()
	player.position.y = camera_height - 12
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(mode == "gameover")
	start_game()
	assert(highest == 0.0 and mode == "playing")
	show_menu()
	assert(mode == "menu")
	print("MVP_SELF_TEST_OK")
	if not OS.has_feature("web"):
		get_tree().quit()
