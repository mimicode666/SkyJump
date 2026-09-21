extends Node3D

const Rules = preload("res://scripts/jump_rules.gd")
const Characters = preload("res://scripts/characters.gd")
const JumpPlatform = preload("res://scripts/jump_platform.gd")
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
var emil_button: Button
var sveta_button: Button
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

func _ready() -> void:
	Engine.max_fps = 60
	_rng_setup()
	_setup_world()
	_setup_ui()
	select_character("emil")
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
	var sky_material := ProceduralSkyMaterial.new()
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
	var cloud_material := material(Color("f5fcff"), true)
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

func _add_platform(pos: Vector3, index: int, stone: bool = false) -> void:
	var node := JumpPlatform.new()
	node.position = pos
	node.configure(COLORS[index % COLORS.size()], stone)
	world.add_child(node)
	platforms.append(pos)
	platform_nodes.append(node)

func _generate_platform() -> void:
	var next: Vector3 = Rules.next_platform(last_generated, rng, before_last_generated)
	var stone: bool = generated_count >= 4 and not last_was_stone and rng.randf() < 0.28
	_add_platform(next, generated_count, stone)
	before_last_generated = last_generated
	last_generated = next
	last_was_stone = stone
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
	var title := _label("PLAYER TWO", 18)
	title.position = Vector2(46, 28)
	menu.add_child(title)
	var heading := _label("Прыжок в облака", 44)
	heading.position = Vector2(46, 56)
	menu.add_child(heading)
	var subtitle := _label("Выберите, кто сегодня прыгнет выше", 20)
	subtitle.position = Vector2(48, 117)
	menu.add_child(subtitle)
	var pickers := HBoxContainer.new()
	pickers.position = Vector2(48, 195)
	pickers.add_theme_constant_override("separation", 12)
	menu.add_child(pickers)
	emil_button = _button("Эмиль", func(): select_character("emil"))
	sveta_button = _button("Света", func(): select_character("sveta"))
	emil_button.toggle_mode = true
	sveta_button.toggle_mode = true
	pickers.add_child(emil_button)
	pickers.add_child(sveta_button)
	model_label = _label("", 16)
	model_label.position = Vector2(48, 265)
	menu.add_child(model_label)
	var menu_bottom := VBoxContainer.new()
	menu_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	menu_bottom.position = Vector2(48, -160)
	menu_bottom.add_theme_constant_override("separation", 15)
	menu.add_child(menu_bottom)
	play_button = _button("Прыгать!", start_game)
	play_button.custom_minimum_size = Vector2(240, 60)
	menu_bottom.add_child(play_button)
	menu_bottom.add_child(_label("A / D или стрелки — движение\nПрыжки — автоматически", 18))
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
	if DisplayServer.is_touchscreen_available():
		for side in [-1, 1]:
			var touch := _button("<" if side == -1 else ">", func(): pass)
			touch.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT if side == -1 else Control.PRESET_BOTTOM_RIGHT)
			touch.position = Vector2(25 if side == -1 else -120, -120)
			touch.custom_minimum_size = Vector2(95, 80)
			touch.button_down.connect(func(): _set_touch(side, true))
			touch.button_up.connect(func(): _set_touch(side, false))
			hud.add_child(touch)
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
	column.add_child(overlay_title)
	overlay_text = _label("", 22)
	overlay_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(overlay_text)
	resume_button = _button("Продолжить", resume_game)
	column.add_child(resume_button)
	column.add_child(_button("Ещё раз", start_game))
	column.add_child(_button("Выбрать персонажа", show_menu))
	hud.hide()
	overlay.hide()

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
	emil_button.set_pressed_no_signal(id == "emil")
	sveta_button.set_pressed_no_signal(id == "sveta")
	model_label.text = ""

func start_game() -> void:
	mode = "playing"
	touch_left = false
	touch_right = false
	_clear_platforms()
	generated_count = 1
	last_generated = Vector3.ZERO
	before_last_generated = Vector3.INF
	last_was_stone = false
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
	score_label.text = "0 м"
	record_label.text = "Рекорд: %d м" % session_best

func _physics_process(delta: float) -> void:
	if mode != "playing":
		return
	var direction: float = Input.get_axis("move_left", "move_right")
	if touch_left or touch_right:
		direction = float(touch_right) - float(touch_left)
	velocity.x = move_toward(velocity.x, direction * Rules.MOVE_SPEED, Rules.ACCELERATION * delta)
	var previous_y: float = player.position.y
	velocity.y -= Rules.GRAVITY * delta
	player.position.x = clampf(player.position.x + velocity.x * delta, -Rules.HALF_WIDTH, Rules.HALF_WIDTH)
	player.position.y += velocity.y * delta
	for i in range(platforms.size()):
		if Rules.lands(previous_y, player.position.y, velocity.y, player.position.x, platforms[i]):
			player.position.y = platforms[i].y
			velocity.y = Rules.JUMP_SPEED
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
	var target_x: float = -0.7 if mode == "menu" else 0.0
	var desired := Vector3(target_x, target_y + 4.0, 13)
	camera.position = camera.position.lerp(desired, minf(delta * 7.0, 1.0))
	camera.look_at(Vector3(target_x, camera.position.y - 4.0, 0), Vector3.UP)
	camera.size = 8.7 if mode == "menu" else 10.0

func pause_game() -> void:
	if mode != "playing":
		return
	mode = "paused"
	overlay_title.text = "Передохнём?"
	overlay_text.text = "Высота: %d м" % int(highest * 10)
	resume_button.show()
	overlay.show()
	resume_button.grab_focus()

func resume_game() -> void:
	mode = "playing"
	overlay.hide()

func finish_game() -> void:
	mode = "gameover"
	session_best = maxi(session_best, int(highest * 10))
	overlay_title.text = "Ещё один прыжок?"
	overlay_text.text = "Высота: %d м\nРекорд: %d м" % [int(highest * 10), session_best]
	resume_button.hide()
	overlay.show()

func show_menu() -> void:
	mode = "menu"
	_clear_platforms()
	_add_platform(Vector3(1.5, 0, 0), 0)
	player.scale = Vector3.ONE
	camera_height = 2.3
	select_character(selected)
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
		elif event.keycode == KEY_R and mode == "gameover":
			start_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == "playing" and not automated:
		pause_game()

func _run_self_test() -> void:
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
	get_viewport().get_texture().get_image().save_png("res://../qa/game-menu-sveta.png")
	select_character("emil")
	assert(visual != null and characters.cache.size() == 2)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../qa/game-menu.png")
	rng.seed = 77
	start_game()
	# A small deterministic pilot exercises actual physics, landings and scrolling.
	for i in range(1800):
		var target: Vector3 = platforms[0]
		for p in platforms:
			if p.y > last_landing_y + 0.1:
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
			get_viewport().get_texture().get_image().save_png("res://../qa/game-playing.png")
		if mode == "gameover":
			break
	Input.action_release("move_left")
	Input.action_release("move_right")
	assert(landings >= 20, "Pilot did not complete enough of the harder route")
	assert(platforms.size() < 24, "Unbounded platform count")
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
	get_tree().quit()
