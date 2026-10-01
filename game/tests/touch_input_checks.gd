extends RefCounted
const Localization = preload("res://scripts/localization.gd")

static func touch(game: Node, index: int, point: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = game.get_viewport().get_stretch_transform() * point
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)
	Input.flush_buffered_events()

static func drag(game: Node, index: int, point: Vector2, delta: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = game.get_viewport().get_stretch_transform() * point
	event.screen_relative = delta
	Input.parse_input_event(event)
	Input.flush_buffered_events()

static func run(game: Node3D) -> void:
	game.start_game()
	var pad: Control = game.ui.pads[0]
	var area: Vector2 = game.get_viewport().get_visible_rect().size
	assert(game.ui.pads.size() == 1 and pad.size == area and pad.is_visible_in_tree())
	var point := Vector2(area.x * 0.8, area.y * 0.6)
	touch(game, 10, point, true)
	assert(not game.touch_left and not game.touch_right, "Touch-down must be neutral")
	point.x -= 8
	drag(game, 10, point, Vector2(-8, 0))
	assert(game.touch_left and not game.touch_right, "Slide left in the right half")
	var initial_x: float = game.player.position.x
	for frame in range(5): await game.get_tree().physics_frame
	assert(game.player.position.x < initial_x, "Gesture did not move the actual player")
	point.x = area.x * 0.15
	drag(game, 10, point, Vector2(-area.x * 0.65, 0))
	point.x += 2
	drag(game, 10, point, Vector2(2, 0))
	assert(game.touch_right and not game.touch_left, "Reverse immediately far left, without returning to touch origin")
	for frame in range(12): await game.get_tree().physics_frame
	assert(game.velocity.x > 0, "Reverse gesture did not reverse horizontal velocity")
	drag(game, 10, point + Vector2(0, 20), Vector2(0, 20))
	assert(game.touch_right, "Vertical movement changed steering")
	drag(game, 10, point, Vector2(-0.2, 0))
	assert(game.touch_right, "Touch jitter reversed steering")
	touch(game, 11, Vector2(area.x * 0.9, point.y), true)
	drag(game, 11, point, Vector2(-20, 0))
	touch(game, 11, point, false)
	assert(game.touch_right, "Second finger stole or released steering")
	touch(game, 10, point, false)
	assert(not game.touch_left and not game.touch_right, "Touch release stuck")
	touch(game, 10, point, true)
	drag(game, 10, point + Vector2(10, 0), Vector2(10, 0))
	touch(game, 10, point, false, true)
	assert(not game.touch_left and not game.touch_right, "Canceled touch stuck")
	# A pause-button touch must not become a steering finger when dragged away.
	var button_touch := InputEventScreenTouch.new()
	button_touch.index = 12
	button_touch.pressed = true
	button_touch.position = game.ui.pause.get_global_rect().get_center()
	pad._input(button_touch)
	var blocked_drag := InputEventScreenDrag.new()
	blocked_drag.index = 12
	blocked_drag.position = point
	blocked_drag.screen_relative = Vector2(20, 0)
	pad._input(blocked_drag)
	assert(not game.touch_left and not game.touch_right, "Touch begun on Pause leaked into steering")
	for device in [0, InputEvent.DEVICE_ID_EMULATION]:
		var mouse := InputEventMouseButton.new()
		mouse.device = device
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = true
		mouse.position = point
		pad._input(mouse)
		var motion := InputEventMouseMotion.new()
		motion.device = device
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = point + Vector2(100, 0)
		pad._input(motion)
	assert(not game.touch_left and not game.touch_right, "Mouse must not steer")
	Input.action_press("move_right")
	for frame in range(10): await game.get_tree().physics_frame
	assert(game.velocity.x > 0, "Keyboard steering broke")
	Input.action_release("move_right")
	touch(game, 10, point, true)
	drag(game, 10, point + Vector2(-10, 0), Vector2(-10, 0))
	game.pause_game()
	assert(not game.touch_left and not game.touch_right and pad.active_finger == -1)
	game.resume_game()
	drag(game, 10, point, Vector2(10, 0))
	assert(not game.touch_left and not game.touch_right, "Old finger resumed after pause")
	touch(game, 10, point, true)
	drag(game, 10, point + Vector2(-10, 0), Vector2(-10, 0))
	game._platform_suspension_changed(true)
	assert(not game.touch_left and not game.touch_right)
	game._platform_suspension_changed(false)
	game.show_menu()
	for language in ["ru", "en"]:
		Localization.apply(language)
		game.tutorial_seen = false
		game._request_start()
		load("res://tests/localization_checks.gd").check_text(game.ui.tutorial, language == "en")
		await RenderingServer.frame_post_draw
		game._accept_tutorial()
		game.show_menu()
	Localization.apply("ru")
	game.tutorial_seen = false
	print("SKYJUMP_INPUT_OK gesture reverse_far_left release jitter vertical second_finger cancel pause focus mouse_disabled keyboard ru en")
