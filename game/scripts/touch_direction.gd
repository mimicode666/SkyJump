extends Control
## The first finger steers by its latest movement, never by screen position.
signal direction_changed(direction: int)
const MOTION_THRESHOLD := 1.5 # Screen pixels; filter tiny touch jitter.
var direction := 0
var active_finger := -1
var pending_motion := 0.0
var excluded_controls: Array[Control] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(reset)

func reset() -> void:
	active_finger = -1
	pending_motion = 0.0
	_set_direction(0)

func _set_direction(value: int) -> void:
	if direction != value:
		direction = value
		direction_changed.emit(direction)

func _over_button(point: Vector2) -> bool:
	for control in excluded_controls:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(point): return true
	return false

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	# Mouse clicks (including synthetic touch clicks) never steer the character.
	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			if event.index == active_finger: reset()
		elif active_finger == -1 and not _over_button(event.position) and get_global_rect().has_point(event.position):
			active_finger = event.index
			pending_motion = 0.0
	elif event is InputEventScreenDrag and event.index == active_finger:
		# Unscaled deltas keep sensitivity consistent across phone/tablet sizes.
		var delta_x: float = event.screen_relative.x
		if is_zero_approx(delta_x): return
		if signf(delta_x) != signf(pending_motion): pending_motion = 0.0
		pending_motion += delta_x
		if absf(pending_motion) >= MOTION_THRESHOLD:
			_set_direction(1 if pending_motion > 0 else -1)
			pending_motion = 0.0
