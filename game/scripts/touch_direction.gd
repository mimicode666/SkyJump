extends Control

signal held_changed(held: bool)
var direction: int = -1
var fingers: Dictionary = {}
var blocked_fingers: Dictionary = {}
var excluded_controls: Array[Control] = []
var held := false
var mouse_down := false
var mouse_held := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(reset)

func reset() -> void:
	fingers.clear()
	blocked_fingers.clear()
	mouse_down = false
	mouse_held = false
	_update_held()

func _update_held() -> void:
	var next: bool = mouse_held or not fingers.is_empty()
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
	# Touch already steers directly; its synthetic mouse events must not stick.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
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
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_down = event.pressed and not _over_button(event.position) and get_viewport().get_visible_rect().has_point(event.position)
		mouse_held = mouse_down and get_global_rect().has_point(event.position)
	elif event is InputEventMouseMotion:
		mouse_down = mouse_down and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
		mouse_held = mouse_down and get_global_rect().has_point(event.position) and not _over_button(event.position)
	_update_held()
