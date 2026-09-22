extends RefCounted
## Local in-game currency only. No purchases or external services.
var balance: int = 0
var path: String
var persistent := true

func _init(save_path: String = "user://wallet.cfg") -> void:
	path = save_path
	persistent = OS.is_userfs_persistent()
	var config := ConfigFile.new()
	if config.load(path) == OK:
		var value = config.get_value("wallet", "coins", 0)
		if value is int:
			balance = clampi(value, 0, 1000000000)

func earn(amount: int = 1) -> void:
	if amount <= 0:
		return
	balance = mini(balance + amount, 1000000000)
	var config := ConfigFile.new()
	config.set_value("wallet", "version", 1)
	config.set_value("wallet", "coins", balance)
	persistent = config.save(path) == OK and OS.is_userfs_persistent()

func caption() -> String:
	return "Монеты: %d%s" % [balance, "" if persistent else " (временно)"]
