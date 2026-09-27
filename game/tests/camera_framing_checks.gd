extends RefCounted

static func run(game: Node3D) -> void:
	var saved_height: float = game.camera_height
	var viewport := SubViewport.new()
	game.add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	var boxes: Array[AABB] = []
	var model: Node3D = game.characters.create_character(game.selected, 1.6)
	for tilt in [-0.3, 0.0, 0.3]:
		model.rotation = Vector3(0, -0.13, tilt)
		boxes.append(game.characters._bounds(model, Transform3D.IDENTITY))
	model.free()
	# Both orientations, a tablet and a narrow phone; use real Camera3D projection.
	for resolution in [Vector2i(1280, 720), Vector2i(390, 844), Vector2i(320, 740), Vector2i(768, 1024), Vector2i(844, 390)]:
		viewport.size = resolution
		var portrait: bool = resolution.x < resolution.y * 0.85
		camera.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
		camera.size = 8.8 if portrait else 10.0
		for height in [2.3, 120.0, 120.5]:
			game.camera_height = height
			game._frame_game_camera(camera)
			assert(is_equal_approx(game._fall_height(), height - 7.0), "Death threshold changed")
			var half_width: float = 4.4 if portrait else 5.0 * resolution.x / resolution.y
			assert(absf(camera.unproject_position(Vector3(half_width, height, 0)).x - resolution.x) < 0.02, "Horizontal wrap edge moved")
			# Even the top of a platform at the death threshold must be off screen.
			assert(camera.unproject_position(Vector3(0, game._fall_height() + 0.3, -0.78)).y > resolution.y, "Dead platform remains visible")
			for box in boxes:
				for corner in range(8):
					for squash in [Vector3.ONE, Vector3(1.08, 0.9, 1.08)]:
						var point: Vector3 = box.get_endpoint(corner) * squash + Vector3(0, game._fall_height(), 0)
						assert(camera.unproject_position(point).y > resolution.y, "Hero still visible at death on %s" % resolution)
			var before: Vector2 = camera.unproject_position(Vector3(0, game._fall_height(), 0))
			game._frame_game_camera(camera)
			assert(camera.unproject_position(Vector3(0, game._fall_height(), 0)).distance_to(before) < 0.01, "Camera drifts while paused")
	game.camera_height = saved_height
	viewport.free()
	print("SKYJUMP_CAMERA_OK five_aspects one_model tilt squash scrolling pause wrap threshold")

static func integration(game: Node3D) -> void:
	game.start_game()
	game._clear_platforms()
	game.last_generated.y = 1000
	game.highest = 29
	game.camera_height = 30
	game.player.position = Vector3(0, game._fall_height() + 0.02, 0)
	game.velocity = Vector2(0, -3)
	game._update_camera(1.0)
	var frame: Vector2 = game.get_viewport().get_visible_rect().size
	assert(game.camera.unproject_position(game.visual.global_position + Vector3.UP * 1.6).y > frame.y, "Head visible at falling threshold")
	await game.get_tree().physics_frame
	await game.get_tree().physics_frame
	assert(game.mode == "gameover", "Existing death threshold no longer works")
	game.start_game()
	assert(game.highest == 0 and game.mode == "playing")
	game.pause_game()
	var stopped: Vector3 = game.camera.position
	await game.get_tree().process_frame
	assert(game.camera.position.is_equal_approx(stopped), "Paused camera moved")
	game.resume_game()
	game.show_menu()
	game._update_camera(1.0)
	assert(not game.journey.night.visible and game.clouds.visible)
	print("SKYJUMP_CAMERA_INTEGRATION_OK fall restart pause earth_reset one_model")
