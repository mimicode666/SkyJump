extends Control

signal held_changed(held: bool)
var direction: int = -1
var fingers: Dictionary = {}
var mouse_held := false
var held := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(reset)
	resized.connect(queue_redraw)

func reset() -> void:
	fingers.clear()
	mouse_held = false
	_update_held()

func _update_held() -> void:
	var next: bool = mouse_held or not fingers.is_empty()
	if next != held:
		held = next
		held_changed.emit(held)
		queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled and get_global_rect().has_point(event.position):
			fingers[event.index] = true
		else:
			fingers.erase(event.index)
	elif event is InputEventScreenDrag:
		# Sliding away releases the direction; sliding onto the other pad transfers it.
		if get_global_rect().has_point(event.position):
			fingers[event.index] = true
		else:
			fingers.erase(event.index)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_held = event.pressed and get_global_rect().has_point(event.position)
	elif event is InputEventMouseMotion and mouse_held:
		mouse_held = get_global_rect().has_point(event.position)
	_update_held()

func _draw() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("d6edc0") if held else Color(1, 1, 1, 0.92)
	style.border_color = Color("7bb450") if held else Color(0.5, 0.7, 0.8, 0.35)
	style.set_border_width_all(3 if held else 1)
	style.set_corner_radius_all(24)
	draw_style_box(style, Rect2(Vector2.ZERO, size))
	var c := size * 0.5
	var d := float(direction)
	draw_polyline(PackedVector2Array([c + Vector2(-d * 6, -11), c + Vector2(d * 6, 0), c + Vector2(-d * 6, 11)]), Color("315470"), 4, true)
