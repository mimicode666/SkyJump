extends Node3D

const Rules = preload("res://scripts/jump_rules.gd")
const Characters = preload("res://scripts/characters.gd")
const JumpPlatform = preload("res://scripts/jump_platform.gd")
const Wallet = preload("res://scripts/wallet.gd")
const PlatformServices = preload("res://scripts/platform_services.gd")
const Coin = preload("res://scripts/coin.gd")
const Jetpack = preload("res://scripts/jetpack.gd")
const WalletBadge = preload("res://scripts/wallet_badge.gd")
const Catalog = preload("res://scripts/catalog.gd")
const TouchDirection = preload("res://scripts/touch_direction.gd")
const HowToPlay = preload("res://scripts/how_to_play.gd")
const Journey = preload("res://scripts/journey.gd")
const BounceSound = preload("res://scripts/bounce_sound.gd")
const Localization = preload("res://scripts/localization.gd")
const COLORS = [Color("65b333"), Color("efaa25"), Color("935aca")]
var characters = Characters.new()
var selected: String = Catalog.CHARACTERS[0].id
var equipped: String = Catalog.CHARACTERS[0].id
var services: RefCounted = PlatformServices.new()
var ad_pending := false
var revive_used := false
var run_id := ""
var bonus_tick := 0.0
var platform_suspended := false
var mode: String = "menu"
var player: Node3D
var visual: Node3D
var camera: Camera3D
var world: Node3D
var clouds: Node3D
var journey: Node3D
var bounce_sound: AudioStreamPlayer
var platform_nodes: Array[Node3D] = []
var platforms: Array[Vector3] = []
var velocity := Vector2.ZERO
var highest: float = 0.0
var camera_height: float = 2.3
var rng := RandomNumberGenerator.new()
var motion_rng := RandomNumberGenerator.new()
var pickup_rng := RandomNumberGenerator.new()
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
var tutorial_seen := false
var layout_pending := false
var menu_page := "home"
var sky_material: ProceduralSkyMaterial
var cloud_material: StandardMaterial3D
var last_was_moving := false
var wallet: RefCounted
var coin_nodes: Array[Node3D] = []
var next_coin_index := 6
var run_coins := 0
var run_seconds := 0.0
var current_pace := 1.0
var environment_ink := Color.TRANSPARENT
var wallet_ink := Color.TRANSPARENT
var jetpack_nodes: Array[Node3D] = []
var jetpack_visual := Jetpack.new()
var jetpack_fuel := 0.0
var next_jetpack_index := 24

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	Localization.install()
	Engine.max_fps = 60
	var camera_test: bool = "--camera-test" in OS.get_cmdline_user_args()
	var journey_test: bool = "--journey-test" in OS.get_cmdline_user_args()
	var models_test: bool = "--models-test" in OS.get_cmdline_user_args()
	var locale_test: bool = "--locale-test" in OS.get_cmdline_user_args()
	var input_test: bool = "--input-test" in OS.get_cmdline_user_args()
	automated = "--self-test" in OS.get_cmdline_user_args() or camera_test or journey_test or models_test or locale_test or input_test
	services.availability_changed.connect(_platform_available_changed)
	services.suspension_changed.connect(_platform_suspension_changed)
	services.initialize(automated)
	if services.initializing:
		var loading := CanvasLayer.new()
		add_child(loading)
		var caption := _label("Подождите…", 24)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		loading.add_child(caption)
		await services.initialization_completed
		loading.queue_free()
	Localization.apply(services.language)
	wallet = Wallet.new("user://qa-journey-wallet.cfg" if journey_test else ("user://qa-camera-wallet.cfg" if camera_test else ("user://qa-run-wallet.cfg" if automated else "user://wallet.cfg")))
	if models_test: wallet = Wallet.new("user://qa-models-wallet.cfg")
	if locale_test: wallet = Wallet.new("user://qa-locale-wallet.cfg")
	if input_test: wallet = Wallet.new("user://qa-input-wallet.cfg")
	wallet.clock = func(): return services.now_seconds()
	session_best = wallet.best_score()
	_rng_setup()
	_setup_world()
	_setup_ui()
	select_character(selected)
	get_window().size_changed.connect(_queue_layout)
	_resize_ui()
	set_process(true)
	set_physics_process(true)
	await RenderingServer.frame_post_draw
	if visual != null: services.mark_ready()
	if automated:
		if OS.has_feature("web"):
			assert(services.bridge != null and services.status == "local", "Web platform bridge did not initialize")
			print("SKYJUMP_PLATFORM_BRIDGE_OK local_no_sdk_requests")
		print("QA_WALLET_LOADED=", wallet.balance)
		call_deferred("_run_input_test" if input_test else ("_run_locale_test" if locale_test else ("_run_models_test" if models_test else ("_run_journey_test" if journey_test else ("_run_camera_test" if camera_test else "_run_self_test")))))

func _rng_setup() -> void:
	rng.randomize()
	motion_rng.randomize()
	pickup_rng.randomize()
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
	journey = Journey.new()
	camera.add_child(journey)
	bounce_sound = BounceSound.new()
	add_child(bounce_sound)
	world = Node3D.new()
	add_child(world)
	clouds = Node3D.new()
	add_child(clouds)
	cloud_material = material(Color("f5fcff"), true)
	cloud_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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
	player.add_child(jetpack_visual)
	jetpack_visual.hide()
	_update_camera(1.0)
	_add_platform(Vector3(1.5, 0, 0), 0)

func _add_platform(pos: Vector3, index: int, stone: bool = false, kind: String = "normal") -> void:
	var node := JumpPlatform.new()
	node.position = pos
	var menu_stand: bool = mode == "menu"
	var motion_speed := motion_rng.randf_range(Rules.MOVING_MIN_SPEED, Rules.MOVING_MAX_SPEED) if kind == "moving" else 1.55
	if kind == "moving": motion_speed *= Journey.moving_speed_multiplier(pos.y)
	node.configure(Color("fff8ed") if menu_stand else COLORS[index % COLORS.size()], stone, kind, motion_speed)
	if menu_stand:
		node.scale = Vector3(2.0, 1.0, 2.0)
	world.add_child(node)
	if mode != "menu": node.apply_environment(pos.y)
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
	if generated_count >= next_jetpack_index and kind == "normal" and generated_count < next_coin_index:
		_spawn_jetpack(platform_nodes.back())
		next_jetpack_index = generated_count + pickup_rng.randi_range(Rules.JETPACK_MIN_INTERVAL, Rules.JETPACK_MAX_INTERVAL)
	if generated_count >= next_coin_index:
		_spawn_coin(platform_nodes.back())
		next_coin_index = generated_count + rng.randi_range(5, 8)
	# Extra side platforms offer alternate landings; hazards never replace the main route.
	if generated_count >= 6:
		var side_roll: float = rng.randf()
		var side_x: float = -3.45 if next.x >= 0 else 3.45
		if side_roll < 0.42 and absf(side_x - next.x) > 3.0:
			_add_platform(Vector3(side_x, next.y, 0), generated_count, false, "spikes" if side_roll < 0.20 else "normal")
	before_last_generated = last_generated
	last_generated = next
	last_was_stone = kind == "stone"
	last_was_moving = kind == "moving"
	generated_count += 1

func _spawn_coin(platform: Node3D) -> void:
	var coin := Coin.new()
	platform.add_child(coin)
	coin.position = Vector3(0, 1.05, 0)
	coin_nodes.append(coin)

func _collect_coins(step: float = 0.0) -> void:
	for i in range(coin_nodes.size() - 1, -1, -1):
		var coin = coin_nodes[i]
		if not is_instance_valid(coin):
			coin_nodes.remove_at(i)
			continue
		if jetpack_fuel > 0: coin.attract(player.position, step)
		if coin.collect(player.position):
			coin_nodes.remove_at(i)
			var amount: int = wallet.coin_multiplier()
			run_coins += amount
			wallet.earn(amount)
			_update_wallet_labels()

func _update_wallet_labels() -> void:
	ui.wallet_badge.update_balance(wallet.balance, wallet.persistent)

func _spawn_jetpack(platform: Node3D) -> void:
	var pickup := Jetpack.new()
	platform.add_child(pickup)
	pickup.position = Vector3(0, 1.0, 0)
	pickup.scale = Vector3.ONE * 0.8
	jetpack_nodes.append(pickup)

func _collect_jetpacks(previous: Vector3) -> void:
	# A wrap is a teleport, not a sweep through every pickup in the playfield.
	if absf(previous.x - player.position.x) > _wrap_half_width(): previous.x = player.position.x
	for i in range(jetpack_nodes.size() - 1, -1, -1):
		var pickup = jetpack_nodes[i]
		if not is_instance_valid(pickup):
			jetpack_nodes.remove_at(i)
		elif jetpack_fuel <= 0 and pickup.collect(previous, player.position):
			jetpack_nodes.remove_at(i)
			jetpack_fuel = Rules.JETPACK_DURATION
			velocity.y = maxf(velocity.y, 8.0)
			jetpack_visual.show()
			if wallet.sound_enabled: bounce_sound.bounce("boost")
			_update_jetpack_indicator()

func _stop_jetpack() -> void:
	jetpack_fuel = 0
	jetpack_visual.hide()
	_update_jetpack_indicator()

func _update_jetpack_indicator() -> void:
	if not ui.has("jetpack_meter"): return
	ui.jetpack_meter.value = jetpack_fuel
	ui.jetpack_meter.visible = jetpack_fuel > 0
	ui.jetpack_label.visible = jetpack_fuel > 0

func _clear_platforms() -> void:
	coin_nodes.clear()
	jetpack_nodes.clear()
	_stop_jetpack()
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
	var disabled := style.duplicate()
	disabled.bg_color = Color("dceaf0")
	disabled.shadow_size = 0
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_color("font_disabled_color", "Button", Color("526c7c"))
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
	var back_button := _button("‹ В меню", func(): _open_menu_page("home"))
	back_button.add_theme_font_size_override("font_size", 15)
	menu.add_child(back_button)
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
	var sound_choice := _button("", _toggle_sound)
	pickers.add_child(character_choice)
	pickers.add_child(sound_choice)
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
	play_button = _button("Прыгать!", _menu_action)
	play_button.custom_minimum_size = Vector2(240, 60)
	menu_bottom.add_child(play_button)
	var menu_hint := _label("", 16)
	menu_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_bottom.add_child(menu_hint)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	menu.add_child(actions)
	var bonus_button := _button("", _request_double_coins)
	var leaders_button := _button("Рекорды", func(): _open_menu_page("records"))
	for button in [bonus_button, leaders_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 16)
		actions.add_child(button)
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
	var fuel_label := _label("Джетпак", 16)
	fuel_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(fuel_label)
	var fuel_meter := ProgressBar.new()
	fuel_meter.max_value = Rules.JETPACK_DURATION
	fuel_meter.show_percentage = false
	fuel_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for bar_style in ["background", "fill"]:
		var bar := StyleBoxFlat.new()
		bar.bg_color = Color("eaf4fc") if bar_style == "background" else Color("edb83d")
		bar.set_corner_radius_all(4)
		fuel_meter.add_theme_stylebox_override(bar_style, bar)
	hud.add_child(fuel_meter)
	fuel_label.hide()
	fuel_meter.hide()
	var hint := _label("Стрелки или A / D       ·       Esc — пауза", 16)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(40, -44)
	hud.add_child(hint)
	var touch_pads: Array[Control] = []
	var touch := TouchDirection.new()
	touch.excluded_controls.append(pause_button)
	touch.direction_changed.connect(func(direction: int):
		touch_left = direction < 0
		touch_right = direction > 0)
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
	var continue_button := _button("", _request_continue)
	continue_button.add_theme_font_size_override("font_size", 17)
	column.add_child(continue_button)
	column.add_child(_button("Ещё раз", start_game))
	column.add_child(_button("Главное меню", show_menu))
	# Above every menu/scroll list, so the balance cannot be covered by cards.
	var wallet_badge := WalletBadge.new()
	root.add_child(wallet_badge)
	var tutorial := HowToPlay.new()
	root.add_child(tutorial)
	tutorial.accepted.connect(_accept_tutorial)
	tutorial.hide()
	var ad_cover := ColorRect.new()
	ad_cover.color = Color(0.83, 0.93, 0.98, 0.94)
	ad_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(ad_cover)
	var ad_label := _label("Подождите…", 24)
	ad_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ad_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ad_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ad_cover.add_child(ad_label)
	ui = {"title": title, "heading": heading, "subtitle": subtitle, "pickers": pickers,
		"jetpack_label": fuel_label, "jetpack_meter": fuel_meter,
		"back": back_button, "tutorial": tutorial,
		"ad_cover": ad_cover, "ad_label": ad_label,
		"bottom": menu_bottom, "menu_hint": menu_hint, "pause": pause_button,
		"actions": actions, "bonus": bonus_button, "continue": continue_button,
		"hint": hint, "column": column, "pads": touch_pads,
		"wallet_badge": wallet_badge, "character_choice": character_choice, "sound_choice": sound_choice, "options": options, "option_list": option_list}
	hud.hide()
	overlay.hide()
	_open_menu_page("home")
	_update_wallet_labels()
	_sync_platform_state()

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
	touch_controls = DisplayServer.is_touchscreen_available()
	var margin: float = 22.0 if compact else 46.0
	var short_landscape: bool = compact and not portrait
	var menu_width: float = area.x - margin * 2 if portrait else minf(440, area.x * 0.52 - margin)
	ui.character_choice.add_theme_font_size_override("font_size", 17 if compact else 20)
	_place(ui.wallet_badge, Vector2(area.x - margin - 176, 16 if compact else 24) if mode == "menu" else Vector2(margin, 91 if compact else 104), Vector2(176, 48))
	ui.wallet_badge.set_menu_size(mode == "menu")
	_place(ui.title, Vector2(margin, 16 if short_landscape else 24), Vector2(menu_width, 24))
	ui.title.add_theme_font_size_override("font_size", 12 if compact else 16)
	ui.title.visible = menu_page == "home"
	ui.back.visible = menu_page != "home"
	_place(ui.back, Vector2(margin, 16 if compact else 24), Vector2(124, 48))
	ui.heading.add_theme_font_size_override("font_size", 30 if compact else 44)
	_place(ui.heading, Vector2(margin, 44 if short_landscape else 53), Vector2(menu_width, 52))
	ui.heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if menu_page == "records" else HORIZONTAL_ALIGNMENT_LEFT
	if menu_page == "records": ui.heading.size.x = area.x - margin * 2
	ui.subtitle.text = "От земли до далёких галактик" if menu_page == "home" else "Нажмите, чтобы выбрать героя"
	ui.subtitle.visible = menu_page != "records"
	ui.subtitle.add_theme_font_size_override("font_size", 16 if compact else 20)
	ui.subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(ui.subtitle, Vector2(margin, 90 if short_landscape else (98 if compact else 117)), Vector2(menu_width, 42))
	if menu_page != "home":
		ui.heading.position.y = ui.back.position.y + ui.back.size.y + 10
		ui.subtitle.position.y = ui.heading.position.y + 48
	_place(ui.pickers, Vector2(margin, 148 if short_landscape else (159 if compact else 195)), Vector2(menu_width, 120))
	for button in [ui.character_choice, ui.sound_choice]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 54)
	_place(model_label, Vector2(margin, 272 if compact else 330), Vector2(menu_width, 46))
	model_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bottom_height: float = 132 if portrait else (116 if compact else 155)
	if menu_page != "home": bottom_height = 84
	_place(ui.bottom, Vector2(margin, area.y - bottom_height), Vector2(menu_width, 0))
	play_button.custom_minimum_size = Vector2(0, 58)
	ui.bottom.add_theme_constant_override("separation", 8 if compact else 15)
	ui.menu_hint.add_theme_font_size_override("font_size", 14 if compact and not portrait else 16)
	ui.menu_hint.text = ("Сдвигайте палец влево или вправо\nПрыжки — автоматически" if touch_controls else "A / D или стрелки — движение\nПрыжки — автоматически") if menu_page == "home" else ""
	ui.menu_hint.visible = menu_page == "home"
	ui.pickers.visible = menu_page == "home"
	ui.actions.visible = menu_page == "home"
	_place(ui.actions, Vector2(margin, ui.bottom.position.y - 88) if portrait else Vector2(area.x * 0.55, area.y - 86), Vector2(menu_width if portrait else area.x * 0.45 - margin, 72))
	ui.options.visible = menu_page != "home"
	var content_top: float = ui.subtitle.position.y + 46
	var options_y: float = content_top
	if menu_page == "records": options_y = ui.heading.position.y + ui.heading.size.y + 18
	if portrait and menu_page == "characters":
		options_y += clampf((area.y - 500) * 0.3 + 100, 120, 200)
	var list_width: float = minf(640, area.x - margin * 2) if menu_page == "records" else menu_width
	_place(ui.options, Vector2(margin, options_y), Vector2(list_width, maxf(80, ui.bottom.position.y - options_y - 16)))
	if menu_page == "records":
		ui.options.position.x = (area.x - list_width) * 0.5
		ui.bottom.size.x = minf(360, area.x - margin * 2)
		ui.bottom.position.x = (area.x - ui.bottom.size.x) * 0.5
	_place(score_label, Vector2(margin, 20), Vector2(180, 48))
	score_label.add_theme_font_size_override("font_size", 34 if compact else 42)
	_place(record_label, Vector2(margin, 65 if compact else 78), Vector2(180, 24))
	_place(ui.pause, Vector2(area.x - margin - 112, 24), Vector2(112, 52))
	_place(ui.jetpack_label, Vector2(area.x - margin - 112, 84), Vector2(112, 22))
	_place(ui.jetpack_meter, Vector2(area.x - margin - 112, 110), Vector2(112, 8))
	ui.hint.visible = not touch_controls
	_place(ui.hint, Vector2(margin, area.y - 40), Vector2(area.x - margin * 2, 24))
	for pad in ui.pads:
		pad.visible = mode == "playing" and not platform_suspended and not ad_pending
		_place(pad, Vector2.ZERO, area)
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

func select_character(id: String) -> void:
	if Catalog.character(id).is_empty(): return
	selected = id
	if wallet.owns_character(id): equipped = id
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
			ui.character_choice.text = tr("Персонаж: %s") % tr(entry.name)
	ui.sound_choice.text = "Звук: вкл." if wallet.sound_enabled else "Звук: выкл."
	for button in ui.option_list.get_children():
		if not button is Button: continue
		button.set_pressed_no_signal(button.get_meta("choice") == selected)
		if menu_page == "characters":
			var entry := Catalog.character(button.get_meta("choice"))
			var owned: bool = wallet.owns_character(entry.id)
			var status: String = tr(" · доступен") if entry.price == 0 else (tr(" · куплен") if owned else "")
			button.text = tr("%s\n%d монет%s") % [tr(entry.name), entry.price, status]
	play_button.disabled = false
	play_button.text = "Прыгать!" if menu_page == "home" else "В меню"
	if menu_page == "characters":
		var entry := Catalog.character(selected)
		var owned: bool = wallet.owns_character(selected)
		if owned: play_button.text = "Выбрать"
		else:
			play_button.disabled = wallet.balance < entry.price
			play_button.text = tr("Не хватает %d монет") % (entry.price - wallet.balance) if play_button.disabled else tr("Купить за %d монет") % entry.price
	if visual == null: play_button.disabled = true
	_update_reward_buttons()

func _menu_action() -> void:
	if ad_pending: return
	if menu_page == "home": _request_start()
	elif menu_page == "characters" and not wallet.owns_character(selected):
		if wallet.purchase_character(selected): equipped = selected
		_update_wallet_labels()
		_update_choice_labels()
	else: _open_menu_page("home")

func _toggle_sound() -> void:
	wallet.toggle_sound()
	_update_choice_labels()
	_sync_platform_state()

func _open_menu_page(page: String) -> void:
	menu_page = page
	if page == "home" and not wallet.owns_character(selected): select_character(equipped)
	player.visible = page != "records"
	world.visible = page != "records"
	ui.title.text = "ВЫШЕ ОБЛАКОВ" if page == "home" else "SkyJump"
	ui.heading.text = "SkyJump" if page == "home" else "Персонажи"
	if page == "records": ui.heading.text = "Рекорды"
	play_button.text = "Прыгать!" if page == "home" else "Готово"
	for child in ui.option_list.get_children():
		ui.option_list.remove_child(child)
		child.queue_free()
	if page == "records":
		_build_record_card()
	elif page == "characters":
		for entry in Catalog.CHARACTERS:
			var id: String = entry.id
			var button := _button(entry.name, func():
				select_character(id)
				_update_choice_labels())
			button.toggle_mode = true
			button.custom_minimum_size.y = 66
			button.add_theme_font_size_override("font_size", 17)
			button.set_meta("choice", id)
			ui.option_list.add_child(button)
	_update_choice_labels()
	ui.options.scroll_vertical = 0
	_resize_ui()

func _build_record_card() -> void:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.96)
	style.set_corner_radius_all(22)
	style.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", style)
	ui.option_list.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	card.add_child(content)
	content.add_child(_label("Рекорд за всё время", 19))
	var best := _label(tr("%d м") % wallet.best_score(), 44)
	content.add_child(best)
	var divider := HSeparator.new()
	content.add_child(divider)
	content.add_child(_label("Список лучших", 19))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	content.add_child(row)
	var rank := _label("1", 23)
	rank.custom_minimum_size.x = 32
	rank.add_theme_color_override("font_color", Color("6b9b3d"))
	row.add_child(rank)
	var player_name := _label("Вы", 23)
	player_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(player_name)
	var distance := _label(tr("%d м") % wallet.best_score(), 23)
	distance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(distance)

func _request_start() -> void:
	bounce_sound.unlocked = true
	if ad_pending or platform_suspended: return
	if tutorial_seen:
		start_game()
		return
	mode = "tutorial"
	_reset_touch()
	menu.hide()
	hud.hide()
	overlay.hide()
	ui.tutorial.show()
	ui.tutorial.start_button.grab_focus()
	_sync_platform_state()

func _accept_tutorial() -> void:
	if mode != "tutorial" or ad_pending or platform_suspended: return
	tutorial_seen = true
	start_game()

func _update_environment_label_colors() -> void:
	if ui.is_empty(): return
	var ink := Color("315470").lerp(Color("edf2ff"), journey.state.get("dark", 0.0))
	if not ink.is_equal_approx(environment_ink):
		environment_ink = ink
		for label in [ui.title, ui.heading, ui.subtitle, model_label, ui.menu_hint, score_label, record_label, ui.hint]:
			label.add_theme_color_override("font_color", ink)
		ui.jetpack_label.add_theme_color_override("font_color", ink)
	var balance_ink := Color("315470") if overlay.visible else ink
	if not balance_ink.is_equal_approx(wallet_ink):
		wallet_ink = balance_ink
		ui.wallet_badge.value.add_theme_color_override("font_color", balance_ink)

func start_game() -> void:
	if ad_pending or platform_suspended: return
	ui.tutorial.hide()
	if not wallet.owns_character(selected): selected = equipped
	player.show()
	world.show()
	revive_used = false
	run_id = "%s-%d" % [str(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	mode = "playing"
	_reset_touch()
	_clear_platforms()
	generated_count = 1
	last_generated = Vector3.ZERO
	before_last_generated = Vector3.INF
	last_was_stone = false
	last_was_moving = false
	next_coin_index = rng.randi_range(5, 8)
	next_jetpack_index = pickup_rng.randi_range(22, 30)
	run_coins = 0
	run_seconds = 0.0
	current_pace = 1.0
	highest = 0
	landings = 0
	last_landing_y = 0.0
	player.scale = Vector3.ONE
	camera_height = 2.3
	select_character(selected)
	velocity = Vector2(0, Rules.JUMP_SPEED)
	_add_platform(Vector3.ZERO, 0)
	while last_generated.y < camera_height + Rules.SPAWN_AHEAD:
		_generate_platform()
	menu.hide()
	overlay.hide()
	hud.show()
	for pad in ui.pads: pad.show()
	_update_camera(1.0)
	score_label.text = "0 м"
	record_label.text = tr("Рекорд: %d м") % session_best
	_resize_ui()
	_sync_platform_state()

func _physics_process(delta: float) -> void:
	if mode != "playing" or platform_suspended or ad_pending:
		return
	run_seconds += delta
	current_pace = Rules.pace(highest, run_seconds)
	var step: float = delta * current_pace
	for i in range(platform_nodes.size()):
		platform_nodes[i].advance_motion(step)
		platforms[i] = platform_nodes[i].position
	var direction: float = Input.get_axis("move_left", "move_right")
	if touch_left or touch_right:
		direction = float(touch_right) - float(touch_left)
	velocity.x = move_toward(velocity.x, direction * Rules.MOVE_SPEED, Rules.ACCELERATION * step)
	var previous_position: Vector3 = player.position
	var previous_y: float = player.position.y
	if jetpack_fuel > 0:
		jetpack_fuel = maxf(0, jetpack_fuel - step)
		var thrust_speed := lerpf(Rules.JUMP_SPEED, Rules.JETPACK_SPEED, clampf(jetpack_fuel / 0.35, 0, 1))
		velocity.y = move_toward(velocity.y, thrust_speed, Rules.JETPACK_ACCELERATION * step)
		if jetpack_fuel <= 0:
			velocity.y = minf(velocity.y, Rules.JUMP_SPEED)
			_stop_jetpack()
		_update_jetpack_indicator()
	else:
		velocity.y -= Rules.GRAVITY * step
	player.position.x = Rules.wrap_x(player.position.x + velocity.x * step, _wrap_half_width())
	player.position.y += velocity.y * step
	for i in range(platforms.size()):
		if Rules.lands(previous_y, player.position.y, velocity.y, player.position.x, platforms[i] + Vector3(0, 0.42 if platform_nodes[i].kind == "spikes" else 0.0, 0)):
			if platform_nodes[i].kind == "spikes":
				finish_game()
				return
			player.position.y = platforms[i].y
			velocity.y = Rules.BOOST_SPEED if platform_nodes[i].kind == "boost" else Rules.JUMP_SPEED
			if wallet.sound_enabled: bounce_sound.bounce(platform_nodes[i].kind)
			landings += 1
			last_landing_y = platforms[i].y
			if platform_nodes[i].register_landing():
				var broken: Node3D = platform_nodes[i]
				platforms.remove_at(i)
				platform_nodes.remove_at(i)
				broken.break_apart()
				broken_platforms.append(broken)
			break
	_collect_coins(step)
	_collect_jetpacks(previous_position)
	highest = maxf(highest, player.position.y)
	camera_height = maxf(camera_height, highest + 1.0)
	score_label.text = tr("%d м") % int(highest * 10.0)
	while last_generated.y < camera_height + Rules.SPAWN_AHEAD:
		_generate_platform()
	while platforms.size() > 0 and platforms[0].y < camera_height - 10:
		platforms.pop_front()
		platform_nodes.pop_front().queue_free()
	if player.position.y < _fall_height():
		finish_game()

func _process(delta: float) -> void:
	bonus_tick += delta
	if bonus_tick >= 1.0:
		bonus_tick = 0.0
		_update_reward_buttons()
	if platform_suspended or ad_pending: return
	if mode == "menu" and visual != null:
		visual.rotation.y = sin(Time.get_ticks_msec() * 0.00045) * 0.22
	if mode == "playing" and visual != null:
		for pickup in jetpack_nodes:
			if is_instance_valid(pickup): pickup.animate(delta * current_pace, false)
		if jetpack_fuel > 0:
			jetpack_visual.animate(delta * current_pace, true)
			visual.rotation.y = wrapf(visual.rotation.y + delta * current_pace * 4.6, -PI, PI)
		else:
			visual.rotation.y = lerp_angle(visual.rotation.y, -0.13, 1.0 - exp(-10.0 * delta))
		for coin in coin_nodes:
			if is_instance_valid(coin): coin.rotation.y += delta * current_pace * 2.0
		visual.rotation.z = lerpf(visual.rotation.z, -velocity.x * 0.035, delta * 10.0)
		for platform in platform_nodes: platform.advance_feedback(delta)
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
	if mode == "menu": player.scale = Vector3.ONE
	if mode == "menu" and portrait and not ui.is_empty():
		var area := Vector2(get_window().content_scale_size)
		var preview_top: float = ui.subtitle.position.y + 46
		var model_center: float = (287.0 + ui.actions.position.y) * 0.5 if menu_page == "home" else (preview_top + ui.options.position.y) * 0.5
		if menu_page != "home": model_center -= 7
		var preview_scale: float = clampf((ui.actions.position.y - 287.0) / 250.0, 0.72, 1.0) if menu_page == "home" else clampf((ui.options.position.y - preview_top - 20) * 7.2 / area.x / 3.6, 0.35, 0.78)
		player.scale = Vector3.ONE * preview_scale
		target_y = 1.65 * preview_scale + (model_center - area.y * 0.5) * 7.2 / area.x
	elif mode == "menu" and menu_page == "characters":
		player.scale = Vector3.ONE * 0.8
	if mode == "menu":
		for stand in platform_nodes: stand.scale = Vector3(2, 1, 2) * player.scale.x
	var target_x: float = (1.5 if portrait else -0.7) if mode == "menu" else 0.0
	camera.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
	camera.size = (7.2 if portrait else 8.7) if mode == "menu" else (8.8 if portrait else 10.0)
	if mode == "menu":
		var desired := Vector3(target_x, target_y + 4.0, 13)
		camera.position = camera.position.lerp(desired, minf(delta * 7.0, 1.0))
		camera.look_at(Vector3(target_x, camera.position.y - 4.0, 0), Vector3.UP)
	else:
		_frame_game_camera(camera)
	var area := get_viewport().get_visible_rect().size
	var span := Vector2(camera.size, camera.size * area.y / maxf(area.x, 1.0)) if portrait else Vector2(camera.size * area.x / maxf(area.y, 1.0), camera.size)
	journey.update_view(0.0 if mode in ["menu", "tutorial"] else highest, span, delta if mode == "playing" else 0.0)
	sky_material.sky_top_color = journey.state.top
	sky_material.sky_horizon_color = journey.state.horizon
	sky_material.ground_horizon_color = journey.state.horizon
	sky_material.ground_bottom_color = journey.state.horizon.darkened(0.12)
	cloud_material.albedo_color = journey.state.cloud
	cloud_material.albedo_color.a = journey.state.clouds
	clouds.visible = journey.state.clouds > 0.001
	_update_environment_label_colors()
	if visual != null:
		# Orthographic view: shifting only the artwork toward the camera preserves
		# its screen position and scale, but keeps it in front of solid platforms.
		# The logical player, landings, coins and source GLB materials stay unchanged.
		visual.global_position = player.global_position + (camera.global_basis.z * 4.0 if mode != "menu" else Vector3.ZERO)
		if jetpack_fuel > 0:
			# Rotate the attachment around the same pivot, without the GLB's scale.
			jetpack_visual.global_position = visual.global_position + Basis.from_euler(visual.rotation) * Vector3(0, 0.72, -0.34)
			jetpack_visual.rotation = Vector3(0, visual.rotation.y, visual.rotation.z)

func _frame_game_camera(view_camera: Camera3D) -> void:
	var area := view_camera.get_viewport().get_visible_rect().size
	var vertical_span: float = view_camera.size
	if view_camera.keep_aspect == Camera3D.KEEP_WIDTH:
		vertical_span *= area.y / maxf(area.x, 1.0)
	# Account for the camera's tilt on the gameplay plane (z = 0).
	# Two world units let the entire 1.6-unit hero leave the frame before death.
	# Keep zoom and horizontal bounds intact; tall screens extend upward only.
	var view_up_y: float = 13.0 / Vector2(4.0, 13.0).length()
	var center_y: float = _fall_height() + 2.0 + vertical_span * 0.5 / view_up_y
	view_camera.position = Vector3(0, center_y + 4.0, 13)
	view_camera.look_at(Vector3(0, center_y, 0), Vector3.UP)
	# camera_height already follows the continuous ascent. An extra Y lerp here
	# would expose the death threshold again while the camera catches up.

func _fall_height() -> float:
	return camera_height - 7.0

func _platform_available_changed() -> void:
	Localization.apply(services.language)
	_update_reward_buttons()

func _platform_suspension_changed(suspended: bool) -> void:
	platform_suspended = suspended
	_reset_touch()
	_sync_platform_state()

func _sync_platform_state() -> void:
	services.set_gameplay(mode == "playing" and not platform_suspended and not ad_pending)
	var muted: bool = wallet != null and not wallet.sound_enabled
	AudioServer.set_bus_mute(0, platform_suspended or ad_pending or mode == "paused" or muted)
	if platform_suspended or ad_pending or mode != "playing" or muted:
		if bounce_sound != null: bounce_sound.stop()
	if ui.is_empty(): return
	_update_environment_label_colors()
	ui.ad_cover.visible = ad_pending or platform_suspended
	ui.ad_label.text = "Просмотр рекламы…" if ad_pending else "Пауза\nВернитесь в игру"
	ui.wallet_badge.visible = mode != "tutorial"
	for pad in ui.pads: pad.visible = mode == "playing" and not platform_suspended and not ad_pending

func _update_reward_buttons() -> void:
	if ui.is_empty(): return
	var remaining: int = wallet.double_remaining()
	var available: bool = services.is_rewarded_available()
	ui.bonus.disabled = ad_pending or remaining > 0 or not available
	ui.bonus.text = "×2 · %02d:%02d" % [remaining / 60, remaining % 60] if remaining > 0 else ("×2 на 10 минут\nЗа рекламу" if available else "Монеты ×2\nНедоступно")
	ui.continue.visible = mode == "gameover" and not revive_used
	ui.continue.disabled = ad_pending or not available
	ui.continue.text = "Продолжить за рекламу" if available else "Продолжить за рекламу\nНедоступно"
	if ad_pending:
		ui.bonus.disabled = true
		ui.bonus.text = "Ожидаем просмотр…"
		ui.continue.text = "Ожидаем просмотр…"

func _request_double_coins() -> void:
	if mode != "menu" or platform_suspended or ad_pending or wallet.double_remaining() > 0 or not services.is_rewarded_available(): return
	ad_pending = true
	_sync_platform_state()
	_update_reward_buttons()
	var rewarded: bool = await services.request_rewarded("double_coins")
	ad_pending = false
	if rewarded: wallet.activate_double_coins()
	else: ui.menu_hint.text = "Награда не получена. Попробуйте ещё."
	_sync_platform_state()
	_update_reward_buttons()

func _request_continue() -> void:
	if mode != "gameover" or platform_suspended or revive_used or ad_pending or not services.is_rewarded_available(): return
	ad_pending = true
	_sync_platform_state()
	var request_run := run_id
	_update_reward_buttons()
	var rewarded: bool = await services.request_rewarded("continue")
	ad_pending = false
	if rewarded and mode == "gameover" and run_id == request_run and not revive_used: _revive()
	elif not rewarded: overlay_text.text = tr("Высота: %d м\nНаграда не получена.\nПопробуйте ещё.") % int(highest * 10)
	_sync_platform_state()
	_update_reward_buttons()

func _revive() -> void:
	revive_used = true
	# Resume on a safe existing platform without resetting this run or its coins.
	var safe := Vector3.INF
	for platform in platform_nodes:
		if platform.active and platform.kind != "spikes" and platform.position.y <= highest and platform.position.y > _fall_height() + 1.0:
			if not safe.is_finite() or platform.position.y > safe.y: safe = platform.position
	if not safe.is_finite():
		safe = Vector3(0, highest, 0)
		_add_platform(safe, generated_count)
	player.position = safe + Vector3(0, 0.05, 0)
	player.scale = Vector3.ONE
	velocity = Vector2(0, Rules.JUMP_SPEED)
	_reset_touch()
	resume_game()

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
	overlay_text.text = tr("Высота: %d м") % int(highest * 10)
	resume_button.show()
	ui.continue.hide()
	overlay.show()
	resume_button.grab_focus()
	_sync_platform_state()

func resume_game() -> void:
	if ad_pending: return
	mode = "playing"
	for pad in ui.pads: pad.show()
	overlay.hide()
	_sync_platform_state()

func finish_game() -> void:
	_stop_jetpack()
	_reset_touch()
	for pad in ui.pads: pad.hide()
	mode = "gameover"
	session_best = maxi(session_best, int(highest * 10))
	wallet.record_run(run_id, int(highest * 10), selected)
	overlay_title.text = "Ещё один прыжок?"
	overlay_text.text = tr("Высота: %d м\nРекорд: %d м\nСобрано монет: %d") % [int(highest * 10), session_best, run_coins]
	resume_button.hide()
	_update_reward_buttons()
	overlay.show()
	_sync_platform_state()

func show_menu() -> void:
	if ad_pending: return
	ui.tutorial.hide()
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
	_sync_platform_state()

func _unhandled_key_input(event: InputEvent) -> void:
	if ad_pending or platform_suspended: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if mode == "tutorial":
				show_menu()
			elif mode == "playing":
				pause_game()
			elif mode == "paused":
				resume_game()
			elif mode == "menu" and menu_page != "home":
				_open_menu_page("home")
		elif event.keycode == KEY_R and mode == "gameover":
			start_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == "playing" and not automated and (not OS.has_feature("web") or services.bridge == null):
		pause_game()

func _run_mechanics_tests() -> void:
	tutorial_seen = false
	_request_start()
	assert(mode == "tutorial" and ui.tutorial.visible and not hud.visible and not ui.wallet_badge.visible)
	var before_help: Vector3 = player.position
	await get_tree().physics_frame
	assert(player.position == before_help, "Game started behind the instructions")
	assert(ui.tutorial.heading.position.y + ui.tutorial.heading.size.y <= ui.tutorial.caption.position.y, "Tutorial heading overlaps caption")
	assert(ui.tutorial.keyboard.position.y + ui.tutorial.keyboard.size.y <= ui.tutorial.start_button.position.y, "Keyboard hint overlaps start")
	_accept_tutorial()
	assert(mode == "playing" and tutorial_seen and not ui.tutorial.visible)
	show_menu()
	_open_menu_page("characters")
	await get_tree().process_frame
	assert(ui.heading.position.y >= ui.back.position.y + ui.back.size.y + 8, "Back button overlaps heading")
	if portrait and get_viewport().get_visible_rect().size.y >= 600:
		assert(ui.options.size.y > 230, "Character selector is too short")
	assert(ui.option_list.get_child_count() == Catalog.CHARACTERS.size())
	select_character(Catalog.CHARACTERS[1].id)
	_open_menu_page("home")
	start_game()
	_clear_platforms()
	last_generated.y = 1000
	_add_platform(Vector3.ZERO, 0, false, "boost")
	_update_camera(1.0)
	assert(camera.unproject_position(visual.global_position).distance_to(camera.unproject_position(player.global_position)) < 0.02, "Foreground artwork moved on screen")
	assert(visual.global_position.distance_to(player.global_position) > 3.9, "Artwork is not in front of the platforms")
	for part in platform_nodes[0].parts:
		assert(part.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and part.material_override.albedo_color.a == 1.0)
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
	await load("res://tests/touch_input_checks.gd").run(self)
	start_game()
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
	print("SKYJUMP_MECHANICS_OK boost moving pause wrap_left wrap_right spikes catalogs tutorial touch_gestures")

func _run_currency_tests() -> void:
	for entry in Catalog.CHARACTERS:
		select_character(entry.id)
		assert(visual != null, "Character failed to load: " + entry.id)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if not OS.has_feature("web"):
			get_viewport().get_texture().get_image().save_png("res://../qa/character-" + entry.id + ".png")
		if entry.id in ["kirby", "cinnamoroll"]:
			var animation_players: Array[Node] = visual.find_children("*", "AnimationPlayer", true, false)
			assert(not animation_players.is_empty(), "Kirby blink animation missing")
			var animation_player: AnimationPlayer = animation_players[0]
			assert(animation_player.is_playing())
			var face: MeshInstance3D
			for mesh in visual.find_children("*", "MeshInstance3D", true, false):
				if mesh.get_blend_shape_count() > 0: face = mesh
			assert(face != null, "Kirby blink shape missing")
			# Sample the supplied timeline: the two models blink at different times.
			var blink_animation := animation_player.get_animation(animation_player.current_animation)
			var closed_time := 0.0
			var max_weight := 0.0
			for sample in range(131):
				var sample_time: float = blink_animation.length * sample / 130.0
				animation_player.seek(sample_time, true)
				if face.get_blend_shape_value(0) > max_weight:
					max_weight = face.get_blend_shape_value(0)
					closed_time = sample_time
			assert(max_weight > 0.9, "Blink did not close eyes: " + entry.id)
			animation_player.seek(closed_time, true)
			await RenderingServer.frame_post_draw
			if not OS.has_feature("web"):
				get_viewport().get_texture().get_image().save_png("res://../qa/" + entry.id + "-blink-closed.png")
			animation_player.seek(0.0, true)
			assert(face.get_blend_shape_value(0) < 0.05, "Kirby did not reopen his eyes")
	_open_menu_page("characters")
	assert(ui.wallet_badge.is_visible_in_tree())
	assert(not ui.wallet_badge.get_global_rect().intersects(ui.options.get_global_rect()), "Character list covers wallet")
	_open_menu_page("home")
	print("SKYJUMP_MODEL_UI_OK blink wallet_visible catalog=", Catalog.CHARACTERS.size())
	assert(characters.cache.size() == Catalog.CHARACTERS.size())
	start_game()
	assert(coin_nodes.size() <= generated_count / 5 + 1)
	_clear_platforms()
	_add_platform(Vector3.ZERO, 0)
	_spawn_coin(platform_nodes[0])
	var previous_balance: int = wallet.balance
	player.position = Vector3.ZERO
	_collect_coins()
	_collect_coins()
	assert(run_coins == 1 and wallet.balance == previous_balance + 1, "Coin was missed or counted twice")
	var restored := Wallet.new(wallet.path)
	assert(restored.balance == wallet.balance, "Wallet did not persist")
	start_game()
	assert(wallet.balance == previous_balance + 1 and run_coins == 0, "Restart reset the wallet")
	var malformed := ConfigFile.new()
	malformed.set_value("wallet", "coins", -100)
	assert(malformed.save("user://qa-invalid-wallet.cfg") == OK)
	var safe_wallet := Wallet.new("user://qa-invalid-wallet.cfg")
	assert(safe_wallet.balance == 0)
	Wallet.clear_profile("user://qa-invalid-wallet.cfg")
	show_menu()
	print("SKYJUMP_CURRENCY_OK characters=", Catalog.CHARACTERS.size(), " one_pickup save_reload restart invalid_save")

func _run_reward_tests() -> void:
	var saved_wallet: RefCounted = wallet
	var saved_services: RefCounted = services
	var saved_best := session_best
	Wallet.clear_profile("user://qa-rewards-wallet.cfg")
	wallet = Wallet.new("user://qa-rewards-wallet.cfg")
	show_menu()
	assert(ui.bonus.disabled)
	await _request_double_coins()
	assert(wallet.coin_multiplier() == 1, "Unavailable ad granted reward")
	var fake: RefCounted = load("res://tests/reward_stub.gd").new()
	services = fake
	await _request_double_coins()
	assert(wallet.coin_multiplier() == 1, "Cancelled ad granted reward")
	fake.success = true
	await _request_double_coins()
	assert(wallet.coin_multiplier() == 2)
	var calls: int = fake.calls
	await _request_double_coins()
	assert(fake.calls == calls, "Active bonus allowed duplicate ad")
	select_character("kirby")
	start_game()
	assert(selected == equipped and selected != "kirby", "Locked character can play")
	_clear_platforms()
	_add_platform(Vector3.ZERO, 0)
	_spawn_coin(platform_nodes[0])
	player.position = Vector3.ZERO
	_collect_coins()
	_collect_coins()
	assert(run_coins == 2 and wallet.balance == 2, "Timed bonus did not double one pickup")
	highest = 1.0
	finish_game()
	fake.success = false
	await _request_continue()
	assert(mode == "gameover" and not revive_used)
	fake.success = true
	# A spike closer to the peak must never be chosen as a revival platform.
	_add_platform(Vector3(2, 0.5, 0), 1, false, "spikes")
	await _request_continue()
	assert(mode == "playing" and revive_used and player.position.x == 0)
	assert(run_coins == 2 and highest == 1.0 and is_equal_approx(velocity.y, Rules.JUMP_SPEED))
	highest = 2.0
	finish_game()
	calls = fake.calls
	await _request_continue()
	assert(mode == "gameover" and fake.calls == calls and not ui.continue.visible)
	assert(wallet.records.size() == 1 and wallet.best_score() == 20)
	show_menu()
	_open_menu_page("characters")
	select_character("zaichik")
	assert(play_button.disabled and "48" in play_button.text)
	wallet.earn(48)
	_update_choice_labels()
	assert(not play_button.disabled and "50" in play_button.text)
	_menu_action()
	assert(wallet.balance == 0 and wallet.owns_character("zaichik") and equipped == "zaichik")
	_menu_action()
	assert(menu_page == "home" and wallet.balance == 0)
	_open_menu_page("records")
	assert(ui.option_list.get_child_count() == 1 and not player.visible)
	wallet.record_run("older-lower-score", 10, selected)
	_open_menu_page("records")
	assert(ui.option_list.get_child_count() == 1 and wallet.best_score() == 20, "Records must show one all-time best")
	_open_menu_page("home")
	assert(player.visible and world.visible)
	services = saved_services
	wallet = saved_wallet
	session_best = saved_best
	equipped = Catalog.CHARACTERS[0].id
	selected = equipped
	Wallet.clear_profile("user://qa-rewards-wallet.cfg")
	show_menu()
	_update_wallet_labels()
	print("SKYJUMP_REWARDS_OK unavailable cancelled confirmed once revive_safe doubled_pickup locked_skin")

func _run_platform_tests() -> void:
	start_game()
	var frozen := player.position
	_platform_suspension_changed(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(player.position.is_equal_approx(frozen) and mode == "playing")
	assert(ui.ad_cover.visible and AudioServer.is_bus_mute(0))
	_platform_suspension_changed(false)
	assert(not ui.ad_cover.visible and not AudioServer.is_bus_mute(0))
	pause_game()
	_platform_suspension_changed(true)
	_platform_suspension_changed(false)
	assert(mode == "paused" and AudioServer.is_bus_mute(0), "SDK resumed manual pause")
	show_menu()
	print("SKYJUMP_PLATFORM_PAUSE_OK physics input_block sound manual_pause")

func _run_journey_test() -> void:
	load("res://tests/progression_checks.gd").run()
	load("res://tests/camera_framing_checks.gd").run(self)
	await load("res://tests/journey_checks.gd").run(self)
	if "--journey-tour" in OS.get_cmdline_user_args():
		load("res://tests/journey_checks.gd").show_tour(self)
	if not OS.has_feature("web"): get_tree().quit()

func _run_models_test() -> void:
	assert(await load("res://tests/new_models_checks.gd").run(self))
	if not OS.has_feature("web"): get_tree().quit()

func _run_locale_test() -> void:
	await load("res://tests/localization_checks.gd").run(self)
	if not OS.has_feature("web"): get_tree().quit()

func _run_input_test() -> void:
	await load("res://tests/touch_input_checks.gd").run(self)
	if not OS.has_feature("web"): get_tree().quit()

func _run_camera_test() -> void:
	var checks = load("res://tests/camera_framing_checks.gd")
	checks.run(self)
	await checks.integration(self)
	if not OS.has_feature("web"): get_tree().quit()

func _run_self_test() -> void:
	load("res://tests/progression_checks.gd").run()
	load("res://tests/camera_framing_checks.gd").run(self)
	await _run_platform_tests()
	await _run_reward_tests()
	await _run_mechanics_tests()
	await _run_currency_tests()
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
	last_generated.y = 1000.0
	_add_platform(Vector3.ZERO, 0, true)
	var stone = platform_nodes[0]
	for frame in range(80):
		await get_tree().physics_frame
		if stone.hits == 1:
			break
	assert(stone.hits == 1 and platforms.size() == 1, "Stone setup hits=%d platforms=%d mode=%s player=%s velocity=%s" % [stone.hits, platforms.size(), mode, player.position, velocity])
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
	select_character(Catalog.CHARACTERS[1].id)
	assert(visual != null)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not OS.has_feature("web"):
		get_viewport().get_texture().get_image().save_png("res://../qa/game-menu-alternate.png")
	select_character(Catalog.CHARACTERS[0].id)
	assert(visual != null and characters.cache.size() == Catalog.CHARACTERS.size())
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not OS.has_feature("web"):
		get_viewport().get_texture().get_image().save_png("res://../qa/game-menu.png")
	rng.seed = 77
	start_game()
	# A small deterministic pilot exercises actual physics, landings and scrolling.
	for i in range(1800):
		var target: Vector3 = platforms[0]
		# A spring skips several levels: aim for the highest reachable landing,
		# rather than chasing the first platform far below the boosted apex.
		for j in range(platforms.size()):
			var p: Vector3 = platforms[j]
			if platform_nodes[j].kind == "spikes" or p.y <= target.y:
				continue
			var discriminant: float = velocity.y * velocity.y - 2.0 * Rules.GRAVITY * (p.y - player.position.y)
			if discriminant < 0: continue
			var landing_time: float = (velocity.y + sqrt(discriminant)) / Rules.GRAVITY
			if landing_time <= 0: continue
			if platform_nodes[j].kind == "moving":
				p.x = platform_nodes[j].origin_x + sin(platform_nodes[j].motion_time + landing_time * 1.55) * platform_nodes[j].motion_amplitude
			if absf(p.x - player.position.x) <= Rules.MOVE_SPEED * maxf(0, landing_time - 0.08) + Rules.PLATFORM_RADIUS:
				target = p
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
			print("PILOT_STOP frame=", i, " height=", highest, " landings=", landings, " player=", player.position, " target=", target, " last_landing=", last_landing_y)
			break
	Input.action_release("move_left")
	Input.action_release("move_right")
	assert(landings >= 20, "Pilot did not complete enough of the harder route")
	assert(platforms.size() < 40, "Unbounded platform count")
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
	print("QA_WALLET_SAVED=", wallet.balance)
	print("MVP_SELF_TEST_OK")
	if not OS.has_feature("web"):
		get_tree().quit()
