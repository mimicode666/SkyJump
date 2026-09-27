extends SceneTree

func _initialize() -> void:
	preload("res://tests/progression_checks.gd").run()
	quit()
