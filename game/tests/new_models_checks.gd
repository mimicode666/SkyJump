extends RefCounted
const Wallet = preload("res://scripts/wallet.gd")

static func run(game: Node3D) -> bool:
	Wallet.clear_profile("user://qa-models-wallet.cfg")
	game.wallet = Wallet.new("user://qa-models-wallet.cfg")
	assert(game.wallet.owns_character("penguin"))
	assert(not game.wallet.owns_character("minion"))
	game._open_menu_page("characters")
	game.select_character("minion")
	assert(game.equipped != "minion" and game.play_button.disabled)
	game.wallet.earn(100)
	game._menu_action()
	assert(game.wallet.owns_character("minion") and game.wallet.balance == 0)
	assert(Wallet.new(game.wallet.path).owns_character("minion"))
	for id in ["penguin", "minion"]:
		game.show_menu()
		game._open_menu_page("characters")
		game.select_character(id)
		assert(game.visual != null)
		var bounds: AABB = game.characters._bounds(game.visual, Transform3D.IDENTITY)
		assert(absf(bounds.size.y - 3.3) < 0.01 and absf(bounds.position.y) < 0.01)
		var textured := 0
		for part in game.visual.find_children("*", "MeshInstance3D", true, false):
			for i in range(part.mesh.get_surface_count()):
				var material: Material = part.get_active_material(i)
				assert(material is StandardMaterial3D)
				assert(material.albedo_texture != null and material.albedo_texture.get_width() > 0)
				textured += 1
		assert(textured > 0)
		await RenderingServer.frame_post_draw
		game.start_game()
		bounds = game.characters._bounds(game.visual, Transform3D.IDENTITY)
		assert(absf(bounds.size.y - 1.6) < 0.01)
		for frame in range(20): await game.get_tree().physics_frame
		assert(game.mode == "playing")
	game.show_menu()
	game._open_menu_page("characters")
	game.select_character("penguin")
	game._update_wallet_labels()
	print("SKYJUMP_NEW_MODELS_OK penguin_free minion_purchase persistence textures framing play")
	return true
