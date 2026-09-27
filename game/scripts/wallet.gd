extends RefCounted
## One local profile: coins, owned characters, timed bonus and personal records.
const Catalog = preload("res://scripts/catalog.gd")
const LEGACY_MAP_PRICES = {"lavender": 50, "mint": 75, "peach": 100, "moon": 150}
var balance: int = 0
var path: String
var persistent := true
var owned: Array[String] = []
var sound_enabled := true
var refunded_maps_amount := 0
var records: Array[Dictionary] = []
var double_until: int = 0
var revision: int = 0
var clock: Callable = func(): return int(Time.get_unix_time_from_system())

func _init(save_path: String = "user://wallet.cfg") -> void:
	path = save_path
	persistent = OS.is_userfs_persistent()
	var config := ConfigFile.new()
	var loaded := config.load(path) == OK
	var storage := _browser_storage()
	if storage != null:
		var text: String = str(storage.loadProfile(path))
		var cached := ConfigFile.new()
		if not text.is_empty() and cached.parse(text) == OK and int(cached.get_value("wallet", "revision", 0)) >= int(config.get_value("wallet", "revision", 0)):
			config = cached
			loaded = true
			persistent = true
	if loaded:
		revision = maxi(0, int(config.get_value("wallet", "revision", 0)))
		var value = config.get_value("wallet", "coins", 0)
		if value is int:
			balance = clampi(value, 0, 1000000000)
		var saved_owned = config.get_value("wallet", "owned", [])
		if saved_owned is Array:
			for id in saved_owned:
				if id is String and not Catalog.character(id).is_empty() and not owned.has(id): owned.append(id)
		sound_enabled = bool(config.get_value("wallet", "sound_enabled", true))
		var expiry = config.get_value("wallet", "double_until", 0)
		if expiry is int: double_until = maxi(0, expiry)
		var saved_records = config.get_value("wallet", "records", [])
		if saved_records is Array:
			for entry in saved_records:
				if entry is Dictionary and entry.get("id") is String and entry.get("score") is int and entry.get("character") is String:
					if entry.score >= 0 and not Catalog.character(entry.character).is_empty():
						records.append({"id": entry.id, "score": mini(entry.score, 1000000000), "character": entry.character})
		_sort_records()
		if int(config.get_value("wallet", "version", 0)) < 4:
			var saved_maps = config.get_value("wallet", "owned_maps", [])
			if saved_maps is Array:
				for id in LEGACY_MAP_PRICES:
					if saved_maps.has(id): refunded_maps_amount += LEGACY_MAP_PRICES[id]
			balance = mini(balance + refunded_maps_amount, 1000000000)
			_save() # Version and refund are saved together, including the Web mirror.

func earn(amount: int = 1) -> void:
	if amount <= 0:
		return
	balance = mini(balance + amount, 1000000000)
	_save()

func owns_character(id: String) -> bool:
	var entry := Catalog.character(id)
	return not entry.is_empty() and (entry.price == 0 or owned.has(id))

func purchase_character(id: String) -> bool:
	var entry := Catalog.character(id)
	if entry.is_empty() or owns_character(id) or balance < entry.price: return false
	balance -= entry.price
	owned.append(id)
	_save()
	return true

func activate_double_coins() -> void:
	double_until = int(clock.call()) + 600
	_save()

func toggle_sound() -> void:
	sound_enabled = not sound_enabled
	_save()

func double_remaining() -> int:
	return maxi(0, double_until - int(clock.call()))

func coin_multiplier() -> int:
	return 2 if double_remaining() > 0 else 1

func record_run(id: String, score: int, character: String) -> void:
	if id.is_empty() or score <= 0 or Catalog.character(character).is_empty(): return
	for i in range(records.size() - 1, -1, -1):
		if records[i].id == id:
			score = maxi(score, records[i].score)
			records.remove_at(i)
	records.append({"id": id, "score": score, "character": character})
	_sort_records()
	_save()

func _sort_records() -> void:
	records.sort_custom(func(a, b): return a.score > b.score)
	if records.size() > 10: records.resize(10)

func best_score() -> int:
	return records[0].score if not records.is_empty() else 0

func _save() -> void:
	revision += 1
	var config := ConfigFile.new()
	config.set_value("wallet", "revision", revision)
	config.set_value("wallet", "version", 4)
	config.set_value("wallet", "coins", balance)
	config.set_value("wallet", "owned", owned)
	config.set_value("wallet", "sound_enabled", sound_enabled)
	config.set_value("wallet", "records", records)
	config.set_value("wallet", "double_until", double_until)
	persistent = config.save(path) == OK and OS.is_userfs_persistent()
	var storage := _browser_storage()
	if storage != null:
		var mirrored: bool = storage.saveProfile(path, config.encode_to_text())
		persistent = persistent or mirrored

static func _browser_storage() -> JavaScriptObject:
	return JavaScriptBridge.get_interface("SkyJumpPlatform") if OS.has_feature("web") else null

static func clear_profile(save_path: String) -> void:
	DirAccess.remove_absolute(save_path)
	var storage := _browser_storage()
	if storage != null: storage.clearProfile(save_path)

func caption() -> String:
	return "Монеты: %d%s" % [balance, "" if persistent else " (временно)"]
