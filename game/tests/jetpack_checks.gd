extends RefCounted
const Rules = preload("res://scripts/jump_rules.gd")
const Journey = preload("res://scripts/journey.gd")

static func run(game: Node3D) -> bool:
	game.motion_rng.seed = 290926
	game.pickup_rng.seed = 290926
	game.start_game()
	game.mode = "paused"
	game._clear_platforms()
	# Variable speeds keep each moving platform inside its original travel range.
	var route_rng: int = game.rng.state
	var speeds: Array[float] = []
	for i in range(24):
		game._add_platform(Vector3(1.2, 10, 0), i, false, "moving")
		var platform: Node3D = game.platform_nodes.back()
		speeds.append(platform.motion_speed)
		var initial_phase: float = platform.motion_time
		platform.advance_motion(0.1)
		assert(is_equal_approx(platform.motion_time - initial_phase, 0.1 * platform.motion_speed))
		for frame in range(180):
			platform.advance_motion(1.4 / 60.0)
			assert(absf(platform.position.x - platform.origin_x) <= platform.motion_amplitude + 0.001)
	assert(speeds.max() - speeds.min() > 1.5 and game.rng.state == route_rng)
	# The same random draw becomes faster only for newly spawned late-zone platforms.
	var baseline := 0.0
	for stage in Journey.STAGES:
		game.motion_rng.seed = 3026
		game._add_platform(Vector3(0, stage.at, 0), 0, false, "moving")
		var moving: Node3D = game.platform_nodes.back()
		if stage.at == 0: baseline = moving.motion_speed
		assert(is_equal_approx(moving.motion_speed, baseline * Journey.moving_speed_multiplier(stage.at)))
		for frame in range(180):
			moving.advance_motion(1.4 / 60)
			assert(absf(moving.position.x) <= moving.motion_amplitude + 0.001)
	assert(Journey.moving_speed_multiplier(409.9) == 1.0)
	assert(Journey.moving_speed_multiplier(410) == 1.2)
	assert(Journey.moving_speed_multiplier(580) == 1.35)
	assert(Journey.moving_speed_multiplier(800) == 1.5)
	assert(game.rng.state == route_rng)
	assert(check_magnet(game), "Magnet checks did not complete")
	# Rare pickups occupy ordinary platforms, separately from coins and spikes.
	game.start_game()
	game.mode = "paused"
	for i in range(250): game._generate_platform()
	assert(game.jetpack_nodes.size() >= 4 and game.jetpack_nodes.size() <= 8)
	for pickup in game.jetpack_nodes:
		assert(pickup.get_parent().kind == "normal")
		for coin in game.coin_nodes: assert(coin.get_parent() != pickup.get_parent())
	# A wrap must not collect a pickup on the far side of the playfield.
	game._clear_platforms()
	game._add_platform(Vector3.ZERO, 0)
	game._spawn_jetpack(game.platform_nodes[0])
	game.player.position = Vector3(-game._wrap_half_width() + 0.01, 0.2, 0)
	game._collect_jetpacks(Vector3(game._wrap_half_width() - 0.01, 0.2, 0))
	assert(game.jetpack_fuel == 0)
	# Collect by crossing the item, including a fast vertical pass.
	game.player.position = Vector3(0, 1.5, 0)
	game._collect_jetpacks(Vector3(0, -1.0, 0))
	assert(game.jetpack_fuel == Rules.JETPACK_DURATION and game.jetpack_nodes.is_empty())
	assert(game.jetpack_visual.visible and game.ui.jetpack_meter.visible)
	game.mode = "playing"
	var yaw: float = game.visual.rotation.y
	game._process(0.1)
	assert(absf(angle_difference(yaw, game.visual.rotation.y)) > 0.4)
	assert(game.jetpack_visual.rotation.is_equal_approx(Vector3(0, game.visual.rotation.y, game.visual.rotation.z)))
	var attachment: Vector3 = game.visual.global_position + Basis.from_euler(game.visual.rotation) * Vector3(0, 0.72, -0.34)
	assert(game.jetpack_visual.global_position.is_equal_approx(attachment), "Jetpack must orbit with the character, not spin in place")
	game.pause_game()
	yaw = game.visual.rotation.y
	game._process(0.1)
	assert(is_equal_approx(game.visual.rotation.y, yaw), "Paused jetpack kept rotating")
	var fuel: float = game.jetpack_fuel
	var at: Vector3 = game.player.position
	await game.get_tree().physics_frame
	await game.get_tree().physics_frame
	assert(game.jetpack_fuel == fuel and game.player.position == at)
	game.resume_game()
	game._platform_suspension_changed(true)
	await game.get_tree().physics_frame
	assert(game.jetpack_fuel == fuel and game.player.position == at)
	game._platform_suspension_changed(false)
	game.ad_pending = true
	await game.get_tree().physics_frame
	assert(game.jetpack_fuel == fuel)
	game.ad_pending = false
	game._sync_platform_state()
	# The real game loop generates ahead of fast ascent; steering still works.
	var start_y: float = game.player.position.y
	game.last_generated = Vector3.ZERO
	game.before_last_generated = Vector3.INF
	game.touch_right = true
	for frame in range(240):
		await game.get_tree().physics_frame
		await game.get_tree().process_frame
		assert(game.mode == "playing")
		assert(game.last_generated.y >= game.camera_height + Rules.SPAWN_AHEAD)
		if frame == 0:
			assert(game.velocity.x > 0 and absf(game.player.position.x) > 0.001, "Jetpack must preserve horizontal control, including screen wrap")
			game.touch_right = false
		if game.jetpack_fuel <= 0: break
	assert(game.jetpack_fuel == 0 and not game.jetpack_visual.visible)
	assert(game.player.position.y - start_y > 55 and game.player.position.y - start_y < 85)
	assert(game.velocity.y <= Rules.JUMP_SPEED)
	for i in range(90): game._process(1.0 / 60)
	assert(absf(angle_difference(game.visual.rotation.y, -0.13)) < 0.001, "Character did not return to facing forward")
	# The normal downward landing path resumes after fuel is exhausted.
	game._clear_platforms()
	var landing_y: float = game.player.position.y - 1
	game._add_platform(Vector3(game.player.position.x, landing_y, 0), 0)
	game.velocity = Vector2(0, -2)
	var old_landings: int = game.landings
	for frame in range(45):
		await game.get_tree().physics_frame
		if game.landings > old_landings: break
	assert(game.landings > old_landings and game.velocity.y > 0)
	game.jetpack_fuel = 1
	game.start_game()
	assert(game.jetpack_fuel == 0 and not game.ui.jetpack_meter.visible)
	game.jetpack_fuel = 1
	game.show_menu()
	assert(game.jetpack_fuel == 0 and game.jetpack_nodes.is_empty())
	print("SKYJUMP_JETPACK_OK spin shared_pivot face_return speed_variation late_zone_speeds magnet rare_pickups swept_collection wrap thrust steering pause focus ads normal_landing reset")
	return true

static func check_magnet(game: Node3D) -> bool:
	game._clear_platforms()
	game.player.position = Vector3.ZERO
	game._add_platform(Vector3(2.8, 0, 0), 0)
	game._spawn_coin(game.platform_nodes.back())
	var coin: Node3D = game.coin_nodes[0]
	var original: Vector3 = coin.global_position
	game._collect_coins(1.0 / 60)
	assert(coin.global_position == original, "Ordinary jumping must not attract coins")
	game.jetpack_fuel = 1
	game._physics_process(1.0 / 60)
	assert(coin.global_position == original, "Pause must also pause the magnet")
	game._collect_coins(1.0 / 60)
	assert(coin.global_position.x < original.x and coin.active, "Nearby coin did not fly toward the player")
	game._stop_jetpack()
	var stopped: Vector3 = coin.global_position
	game._collect_coins(1.0 / 60)
	assert(coin.global_position == stopped, "Magnet persisted after fuel ended")
	game._add_platform(Vector3(4.1, 0, 0), 1)
	game._spawn_coin(game.platform_nodes.back())
	var far_coin: Node3D = game.coin_nodes.back()
	var far_original: Vector3 = far_coin.global_position
	var balance: int = game.wallet.balance
	var run_coins: int = game.run_coins
	var previous_expiry: int = game.wallet.double_until
	game.wallet.activate_double_coins()
	game.jetpack_fuel = 1
	for frame in range(12): game._collect_coins(1.0 / 60)
	assert(game.coin_nodes.size() == 1 and far_coin.global_position == far_original)
	assert(game.wallet.balance == balance + 2 and game.run_coins == run_coins + 2, "Magnet must credit the wallet exactly once and respect x2")
	game.wallet.double_until = previous_expiry
	# Coins remain collectible at maximum thrust and pace, at 30 and 60 Hz.
	for fps in [30, 60]:
		game._clear_platforms()
		game.player.position = Vector3.ZERO
		game._add_platform(Vector3(2.5, 5, 0), 0)
		game._spawn_coin(game.platform_nodes.back())
		game.jetpack_fuel = 1
		var step: float = 1.4 / fps
		for frame in range(30):
			game.player.position.y += Rules.JETPACK_SPEED * step
			game._collect_coins(step)
			if game.coin_nodes.is_empty(): break
		assert(game.coin_nodes.is_empty(), "Jetpack outran the magnet")
	# Teleporting across the screen must not pull a distant coin across the level.
	game._clear_platforms()
	game._add_platform(Vector3(3.5, 0, 0), 0)
	game._spawn_coin(game.platform_nodes.back())
	coin = game.coin_nodes[0]
	original = coin.global_position
	game.player.position = Vector3(-4.4, 0, 0)
	game.jetpack_fuel = 1
	game._collect_coins(1.0 / 60)
	assert(coin.global_position == original)
	game._clear_platforms()
	print("SKYJUMP_MAGNET_OK nearby_only active_jetpack_only pause expiry x2_once fast_flight wrap")
	return true
