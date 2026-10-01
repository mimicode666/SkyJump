extends Control
## Local vector splash: stays sharp on phones, tablets and desktop.
signal accepted
var heading: Label
var caption: Label
var left_text: Label
var right_text: Label
var keyboard: Label
var start_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	heading = _text("Как играть", 34)
	caption = _text("Сдвигайте палец влево или вправо\nБез возврата к центру", 18)
	left_text = _text("Палец влево\nГерой влево", 20)
	right_text = _text("Палец вправо\nГерой вправо", 20)
	keyboard = _text("Отпустите палец, чтобы остановиться\nПрыжки — автоматически\nКлавиатура: A / D или стрелки", 17)
	start_button = Button.new()
	start_button.text = "Понятно, играем!"
	start_button.pressed.connect(func(): accepted.emit())
	add_child(start_button)
	resized.connect(_layout)
	_layout()

func _text(text: String, font_size: int) -> Label:
	var label := Label.new()
	# Give wrapping an initial width before text shaping computes minimum height.
	label.size = Vector2(300, 40)
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _layout() -> void:
	if heading == null: return
	var short_screen := size.y < 500
	heading.position = Vector2(20, 18 if short_screen else 42)
	heading.size = Vector2(size.x - 40, 46)
	caption.position = heading.position + Vector2(0, 48)
	caption.size = Vector2(size.x - 40, 50)
	var center_y: float = (112.0 + size.y - 150.0) * 0.5
	for i in range(2):
		var label: Label = left_text if i == 0 else right_text
		label.add_theme_font_size_override("font_size", 17 if size.x < 500 else 20)
		label.position = Vector2(i * size.x * 0.5 + 14, center_y - 5)
		label.size = Vector2(size.x * 0.5 - 28, 60 if short_screen else 94)
	keyboard.add_theme_font_size_override("font_size", 14 if short_screen else 17)
	keyboard.position = Vector2(20, size.y - 155)
	keyboard.size = Vector2(size.x - 40, 66)
	start_button.position = Vector2(maxf(22, (size.x - 360) * 0.5), size.y - 80)
	start_button.size = Vector2(minf(360, size.x - 44), 58)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
	var center_y: float = (112.0 + size.y - 150.0) * 0.5
	# One continuous gesture area, with no left/right button boundary.
	draw_line(Vector2(size.x * 0.25, center_y - 37), Vector2(size.x * 0.75, center_y - 37), Color("dceaf0"), 3, true)
	draw_circle(Vector2(size.x * 0.5, center_y - 37), 12, Color("a4d8ed"))
	for i in range(2):
		var c := Vector2(size.x * (0.25 if i == 0 else 0.75), center_y - 37)
		var d := -1.0 if i == 0 else 1.0
		draw_circle(c, 30, Color("edf7fb"))
		draw_line(c - Vector2(d * 13, 0), c + Vector2(d * 13, 0), Color("457599"), 3, true)
		draw_polyline(PackedVector2Array([c + Vector2(d * 3, -10), c + Vector2(d * 13, 0), c + Vector2(d * 3, 10)]), Color("457599"), 3, true)
