extends Control
## A light 2D coin; no extra 3D viewport or texture needed for the HUD.
var phase := 0.0
var value := Label.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.position = Vector2(38, 0)
	value.add_theme_font_size_override("font_size", 20)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.size = Vector2(126, 34)
	add_child(value)

func update_balance(balance: int, persistent: bool) -> void:
	value.text = str(balance)
	tooltip_text = "Монеты: %d%s" % [balance, "" if persistent else " (временно)"]
	value.modulate = Color.WHITE if persistent else Color("bc7028")

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	phase = fmod(phase + delta * 1.7, TAU)
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(16, 17), 0, Vector2(maxf(absf(cos(phase)), 0.14), 1))
	draw_circle(Vector2.ZERO, 14, Color("d79724"))
	draw_circle(Vector2(-1, -1), 11.5, Color("ffd24c"))
	draw_arc(Vector2(-1, -1), 9, 0, TAU, 24, Color("fff0a3"), 1.5, true)
	draw_line(Vector2(-1, -6), Vector2(-1, 4), Color("fff5c4"), 2.5, true)
