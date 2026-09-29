extends RefCounted
const Wallet = preload("res://scripts/wallet.gd")
const Catalog = preload("res://scripts/catalog.gd")

static func run(game: Node3D) -> bool:
	Wallet.clear_profile("user://qa-trail-wallet.cfg")
	game.wallet = Wallet.new("user://qa-trail-wallet.cfg")
	assert(game.wallet.selected_trail == "none" and game.wallet.owns_trail("none"))
	assert(not game.wallet.purchase_trail("rainbow") and not game.wallet.equip_trail("rainbow"))
	assert(not game.wallet.purchase_trail("missing"))
	game.wallet.earn(1000)
	game.wallet.record_run("trail-test", 123, "pikachu")
	game._open_menu_page("trails")
	assert(game.ui.option_list.get_child_count() == 5)
	for entry in Catalog.TRAILS:
		game.preview_trail = entry.id
		game.ui.trail_preview.style = entry.id
		game._update_choice_labels()
		var before: int = game.wallet.balance
		assert(game.wallet.selected_trail != entry.id or entry.id == "none")
		if entry.price > 0:
			game._menu_action()
			assert(game.wallet.balance == before - entry.price and game.wallet.selected_trail == entry.id)
			assert(not game.wallet.purchase_trail(entry.id), "Duplicate trail purchase charged coins")
		var restored := Wallet.new(game.wallet.path)
		assert(restored.selected_trail == game.wallet.selected_trail and restored.balance == game.wallet.balance)
		assert(restored.best_score() == 123 and restored.owns_character("pikachu"))
	assert(game.wallet.balance == 670)
	game.wallet.equip_trail("none")
	assert(Wallet.new(game.wallet.path).selected_trail == "none")
	# Legacy and invalid trail fields preserve existing coins, purchases and record.
	var config := ConfigFile.new()
	config.set_value("wallet", "version", 4)
	config.set_value("wallet", "coins", 42)
	config.set_value("wallet", "owned", ["kirby"])
	config.set_value("wallet", "selected_trail", "rainbow")
	config.set_value("wallet", "owned_trails", ["invalid", 123])
	assert(config.save("user://qa-trail-legacy.cfg") == OK)
	var legacy := Wallet.new("user://qa-trail-legacy.cfg")
	assert(legacy.balance == 42 and legacy.owns_character("kirby") and legacy.selected_trail == "none")
	Wallet.clear_profile(legacy.path)
	# Layout at phone, tablet and desktop proportions, one existing hero only.
	var window := game.get_window()
	var old_size := window.size
	for dimensions in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(768, 1024), Vector2i(1280, 720)]:
		window.size = dimensions
		game._open_menu_page("trails")
		await game.get_tree().process_frame
		game._resize_ui()
		assert(not game.ui.trail_preview.get_global_rect().intersects(game.ui.options.get_global_rect()))
		assert(not game.ui.wallet_badge.get_global_rect().intersects(game.ui.options.get_global_rect()))
		assert(game.ui.options.size.y >= 80)
		game._open_menu_page("home")
		await game.get_tree().process_frame
		game._resize_ui()
		assert(not game.ui.pickers.get_global_rect().intersects(game.ui.bottom.get_global_rect()), "Home buttons overlap on a short screen")
	window.size = old_size
	# Real mesh, bounded length, no teleport line, pause and reset.
	game._open_menu_page("home")
	game.wallet.equip_trail("rainbow")
	game.start_game()
	game.mode = "paused"
	for entry in Catalog.TRAILS:
		game.trail.reset(entry.id)
		for i in range(80):
			game.trail.advance(Vector3(sin(i * 0.1), i * 0.13, 0), 1.0 / 60, game.camera, 4.4)
		assert(game.trail.points.size() <= game.trail.MAX_POINTS)
		if entry.id == "none": assert(game.trail.ribbon.get_surface_count() == 0)
		else: assert(game.trail.ribbon.get_surface_count() == 1)
		await RenderingServer.frame_post_draw
	game.trail.reset("rainbow")
	game.trail.advance(Vector3(4.3, 0, 0), 0.016, game.camera, 4.4)
	game.trail.advance(Vector3(-4.3, 0, 0), 0.016, game.camera, 4.4)
	assert(game.trail.points.size() == 1 and game.trail.ribbon.get_surface_count() == 0)
	game.start_game()
	for i in range(12): await game.get_tree().process_frame
	game.pause_game()
	var ages: Array[float] = game.trail.ages.duplicate()
	await game.get_tree().process_frame
	assert(game.trail.ages == ages)
	game.show_menu()
	assert(game.trail.points.is_empty())
	game._open_menu_page("trails")
	game.preview_trail = "rainbow"
	game.ui.trail_preview.style = "rainbow"
	game._update_choice_labels()
	game._update_wallet_labels()
	print("SKYJUMP_TRAILS_OK purchase preview equip none persistence legacy prices mesh_bound wrap pause reset layouts one_model")
	return true
