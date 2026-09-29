extends Control
const Trail = preload("res://scripts/player_trail.gd")
var style := "none"
var elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func advance(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(1, 1, 1, 0.78)
	panel.set_corner_radius_all(22)
	draw_style_box(panel, Rect2(Vector2.ZERO, size))
	var path: Array[Vector2] = []
	for i in range(49):
		var t := float(i) / 48
		path.append(Vector2(size.x * (0.82 - t * 0.65), size.y * 0.52 + sin(elapsed * 2.5 - t * 3.0) * size.y * 0.22))
	if style != "none":
		var bands := 6 if style == "rainbow" else 1
		for i in range(48):
			if style == "dashed" and i % 8 >= 5: continue
			var t0 := float(i) / 48
			var t1 := float(i + 1) / 48
			var side0 := (path[maxi(0, i - 1)] - path[i + 1]).orthogonal().normalized()
			var side1 := (path[i] - path[mini(i + 2, 48)]).orthogonal().normalized()
			for band in range(bands):
				var lo := -1.0 + 2.0 * band / bands
				var hi := -1.0 + 2.0 * (band + 1) / bands
				var w0 := Trail.width_for(style, t0) * 64
				var w1 := Trail.width_for(style, t1) * 64
				var color := Trail.color_for(style, band)
				color.a = 1.0 - smoothstep(0.5, 1.0, t0)
				draw_colored_polygon(PackedVector2Array([path[i] + side0 * w0 * lo, path[i] + side0 * w0 * hi, path[i + 1] + side1 * w1 * hi, path[i + 1] + side1 * w1 * lo]), color)
	draw_circle(path[0], 14, Color("315470"), true, -1, true)
	draw_circle(path[0], 10, Color.WHITE, true, -1, true)
