extends RefCounted
const Localization = preload("res://scripts/localization.gd")
const Wallet = preload("res://scripts/wallet.gd")

static func check_text(node: Node, english: bool) -> void:
	if node is Label or node is Button:
		var rendered: String = node.tr(node.text)
		if english:
			var cyrillic := RegEx.new()
			cyrillic.compile("[А-Яа-яЁё]")
			assert(cyrillic.search(rendered) == null, "Untranslated UI: " + rendered)
	for child in node.get_children(): check_text(child, english)

static func run(game: Node3D) -> void:
	for code in ["ru", "be", "kk", "uk", "uz", "", "ru-RU"]:
		assert(Localization.locale_for(code) == "ru")
	for code in ["en", "en_US", "fr", "tr", "de"]:
		assert(Localization.locale_for(code) == "en")
	Wallet.clear_profile("user://qa-locale-wallet.cfg")
	game.wallet = Wallet.new("user://qa-locale-wallet.cfg")
	for locale in ["ru", "en"]:
		Localization.apply(locale)
		var english: bool = locale == "en"
		game.show_menu()
		game._update_wallet_labels()
		assert(game.ui.wallet_badge.tooltip_text == ("Coins: 0" if english else "Монеты: 0"))
		assert(game.ui.heading.tr("Персонажи") == ("Characters" if english else "Персонажи"))
		game._open_menu_page("characters")
		check_text(game.menu, english)
		# Test unavailable/affordable/owned captions without loading another GLB.
		game.selected = "cinnamoroll" if english else "minion"
		var price: int = 250 if english else 100
		game._update_choice_labels()
		assert(game.play_button.text == (("Need %d more coins" if english else "Не хватает %d монет") % price))
		game.wallet.earn(price)
		game._update_choice_labels()
		assert(game.play_button.text == (("Buy for %d coins" if english else "Купить за %d монет") % price))
		assert(game.wallet.purchase_character(game.selected))
		assert(Wallet.new(game.wallet.path).owns_character(game.selected))
		game._update_choice_labels()
		check_text(game.menu, english)
		game.selected = "pikachu"
		game._open_menu_page("records")
		check_text(game.menu, english)
		game._open_menu_page("home")
		game.tutorial_seen = false
		game._request_start()
		assert(game.mode == "tutorial")
		check_text(game.ui.tutorial, english)
		await RenderingServer.frame_post_draw
		game._accept_tutorial()
		await game.get_tree().physics_frame
		check_text(game.hud, english)
		game.pause_game()
		check_text(game.overlay, english)
		game.resume_game()
		game.highest = 127.4
		game.finish_game()
		assert(game.overlay_text.text.begins_with("Height: 1274 m" if english else "Высота: 1274 м"))
		check_text(game.overlay, english)
		game.show_menu()
	game._open_menu_page("home")
	game._update_wallet_labels()
	print("SKYJUMP_LOCALIZATION_OK ru en fallback menu characters prices records tutorial hud pause gameover wallet")
