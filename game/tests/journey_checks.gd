extends RefCounted
const Journey = preload("res://scripts/journey.gd")
const Platform = preload("res://scripts/jump_platform.gd")

static func run(game: Node3D) -> void:
	# Adjacent samples must stay continuous at both ends of each crossfade.
	for stage in Journey.STAGES:
		for height in [stage.at, stage.at + Journey.FADE_HEIGHT]:
			var before := Journey.sample(height - 0.001)
			var after := Journey.sample(height + 0.001)
			assert(before.top.is_equal_approx(after.top) or before.top.to_rgba32() == after.top.to_rgba32())
			assert(absf(before.stars - after.stars) < 0.001)
			assert(absf(before.clouds - after.clouds) < 0.001)
	game.start_game()
	game.mode = "paused"
	game._clear_platforms()
	var random_state: int = game.rng.state
	for stage in Journey.STAGES:
		game.highest = stage.at + Journey.FADE_HEIGHT
		game.camera_height = game.highest + 1
		game.player.position = Vector3(0, game.highest, 0)
		game._update_camera(1.0)
		assert(game.journey.state.name == stage.name)
		assert(game.rng.state == random_state, "Decoration consumed route RNG")
		game._add_platform(Vector3(0, game.highest, 0), 0)
		var platform: Node3D = game.platform_nodes.back()
		assert(platform.parts[0].material_override.albedo_texture != null)
		assert(platform.parts[0].material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED)
		await game.get_tree().process_frame
		await RenderingServer.frame_post_draw
		game._clear_platforms()
	assert(Journey.textures.size() == 7)
	assert(game.journey.galaxies.visible and not game.journey.night.moon.visible)
	# Animated artwork must not move the collision root or the attached coin.
	for kind in ["normal", "moving", "boost", "stone"]:
		var platform := Platform.new()
		game.world.add_child(platform)
		platform.configure(Color.GREEN, kind == "stone", kind)
		platform.apply_environment(180)
		var collision_position := platform.position
		assert(not platform.register_landing())
		platform.advance_feedback(0.07)
		assert(platform.position == collision_position and platform.scale == Vector3.ONE)
		if kind == "stone":
			assert(platform.crumbs[0].visible and platform.cracks[0].visible and platform.hits == 1)
		else:
			assert(platform.artwork.scale.x > 1 and platform.pulse.visible)
			assert(platform.pulse.material_override.albedo_color.a > 0)
		if kind == "boost": assert(platform.springs[2].position.y > platform.springs[2].get_meta("rest_y"))
		platform.advance_feedback(1.0)
		assert(platform.artwork.scale == Vector3.ONE and platform.artwork.position == Vector3.ZERO)
		if kind == "stone":
			assert(platform.register_landing(), "Stone no longer breaks on second landing")
			platform.break_apart()
			assert(platform.artwork.position == Vector3.ZERO and platform.landing_elapsed < 0)
		platform.free()
	# Real physics on the stone retains both rebounds, including the break.
	game.start_game()
	game._clear_platforms()
	game.last_generated.y = 1000
	game._add_platform(Vector3.ZERO, 0, true)
	var stone: Node3D = game.platform_nodes[0]
	for frame in range(160):
		await game.get_tree().physics_frame
		if stone.hits == 2: break
	assert(stone.hits == 2 and game.platforms.is_empty() and game.velocity.y > 0)
	game.start_game()
	game._clear_platforms()
	game.last_generated.y = 1000
	game._add_platform(Vector3.ZERO, 0, false, "boost")
	game.player.position = Vector3(0, 0.02, 0)
	game.velocity = Vector2(0, -3)
	await game.get_tree().physics_frame
	await game.get_tree().physics_frame
	assert(game.velocity.y > game.Rules.JUMP_SPEED + 3)
	game.pause_game()
	var effect_time: float = game.platform_nodes[0].landing_elapsed
	var weather_time: float = game.journey.elapsed
	await game.get_tree().process_frame
	assert(game.platform_nodes[0].landing_elapsed == effect_time and game.journey.elapsed == weather_time)
	game.resume_game()
	await load("res://tests/camera_framing_checks.gd").integration(game)
	assert(game.journey.state.index == 0 and not game.ui.has("map_choice"))
	for sound in game.bounce_sound.SOUNDS.values(): assert(sound.get_length() > 0.05 and sound.get_length() < 0.3)
	print("SKYJUMP_JOURNEY_OK seven_zones smooth_transitions route_rng textures solid_platforms bounce spring stone pause reset one_model local_pcm")

static func show_tour(game: Node3D) -> void:
	# Explicit QA-only UI for checking actual Web-rendered zones without playing
	# through kilometres of route or touching the player's saved profile.
	game.start_game()
	game.mode = "paused"
	game.overlay.hide()
	var layer := CanvasLayer.new()
	game.add_child(layer)
	var next := Button.new()
	next.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	next.position = Vector2(18, -58)
	next.size = Vector2(350, 42)
	layer.add_child(next)
	var state := {"index": -1}
	var advance := func():
		state.index = (state.index + 1) % Journey.STAGES.size()
		game._clear_platforms()
		game.highest = Journey.STAGES[state.index].at + Journey.FADE_HEIGHT
		game.camera_height = game.highest + 1
		game.player.position = Vector3(0, game.highest, 0)
		for i in range(5):
			game._add_platform(Vector3((i % 2 * 2 - 1) * 1.8 if i != 1 else 0, game.highest + (i - 1) * 2.4, 0), i, i == 3, ["normal", "normal", "boost", "stone", "moving"][i])
		game.platform_nodes[1].register_landing()
		game.platform_nodes[1].advance_feedback(0.07)
		game.score_label.text = "%d м" % int(game.highest * 10)
		game._update_camera(1)
		next.text = "QA %d/7 · %s · Далее" % [state.index + 1, Journey.STAGES[state.index].name]
	next.pressed.connect(advance)
	advance.call()
