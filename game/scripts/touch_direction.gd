extends Control

signal held_changed(held: bool)
var direction: int = -1
var fingers: Dictionary = {}
var blocked_fingers: Dictionary = {}
var excluded_controls: Array[Control] = []
var held := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(reset)

func reset() -> void:
	fingers.clear()
	blocked_fingers.clear()
	_update_held()

func _update_held() -> void:
	var next: bool = not fingers.is_empty()
	if next != held:
		held = next
		held_changed.emit(held)

func _over_button(point: Vector2) -> bool:
	for control in excluded_controls:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(point): return true
	return false

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled and _over_button(event.position):
			blocked_fingers[event.index] = true
		if event.pressed and not event.canceled and not blocked_fingers.has(event.index) and get_global_rect().has_point(event.position):
			fingers[event.index] = true
		else:
			fingers.erase(event.index)
		if not event.pressed or event.canceled: blocked_fingers.erase(event.index)
	elif event is InputEventScreenDrag:
		# A finger may cross the middle; a touch begun on Pause never steers.
		if not blocked_fingers.has(event.index) and not _over_button(event.position) and get_global_rect().has_point(event.position):
			fingers[event.index] = true
		else:
			fingers.erase(event.index)
	_update_held()
