extends MeshInstance3D
## A short camera-facing ribbon. Cosmetic only; capped samples and one draw call.
const MAX_POINTS := 48
const LIFETIME := 0.34
const MAX_LENGTH := 2.7
const RAINBOW = [Color("ff668a"), Color("ffb65c"), Color("ffe979"), Color("79e6a5"), Color("65d5ff"), Color("b692ff")]
var style := "none"
var points: Array[Vector3] = []
var ages: Array[float] = []
var distances: Array[float] = []
var travelled := 0.0
var ribbon := ImmediateMesh.new()

func _ready() -> void:
	mesh = ribbon
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.vertex_color_use_as_albedo = true
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = ink

static func color_for(kind: String, band: int = 0) -> Color:
	if kind == "rainbow": return RAINBOW[band]
	return Color("ffc45b") if kind == "dashed" else (Color("e99cff") if kind == "pointed" else Color("75e5ff"))

static func width_for(kind: String, fraction: float) -> float:
	return (0.28 * (1.0 - fraction)) if kind == "pointed" else (0.21 if kind == "rainbow" else 0.15)

func reset(kind: String = "none") -> void:
	style = kind
	points.clear()
	ages.clear()
	distances.clear()
	travelled = 0
	ribbon.clear_surfaces()

func advance(at: Vector3, delta: float, view: Camera3D, wrap_width: float) -> void:
	if style == "none": return
	if not points.is_empty() and (absf(at.x - points[0].x) > wrap_width or at.distance_to(points[0]) > 4.0): reset(style)
	for i in range(ages.size()): ages[i] += delta
	if points.is_empty() or at.distance_to(points[0]) > 0.045:
		if not points.is_empty(): travelled += at.distance_to(points[0])
		points.push_front(at)
		ages.push_front(0.0)
		distances.push_front(travelled)
	while not points.is_empty() and (ages.back() > LIFETIME or points.size() > MAX_POINTS or travelled - distances.back() > MAX_LENGTH):
		points.pop_back()
		ages.pop_back()
		distances.pop_back()
	_draw_ribbon(view)

func _draw_ribbon(view: Camera3D) -> void:
	ribbon.clear_surfaces()
	if points.size() < 2: return
	var bands := 6 if style == "rainbow" else 1
	# Slightly behind the hero's camera-axis offset, still ahead of platforms.
	var offset := view.global_basis.z * 3.8
	var begun := false
	for i in range(points.size() - 1):
		if style == "dashed" and fposmod(distances[i], 0.52) > 0.30: continue
		var side0 := (points[maxi(0, i - 1)] - points[i + 1]).cross(view.global_basis.z).normalized()
		var side1 := (points[i] - points[mini(i + 2, points.size() - 1)]).cross(view.global_basis.z).normalized()
		if side0.length_squared() < 0.5 or side1.length_squared() < 0.5: continue
		if not begun:
			ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			begun = true
		var t0 := float(i) / (points.size() - 1)
		var t1 := float(i + 1) / (points.size() - 1)
		for band in range(bands):
			var lo := -1.0 + 2.0 * band / bands
			var hi := -1.0 + 2.0 * (band + 1) / bands
			var a := points[i] + offset + side0 * width_for(style, t0) * lo
			var b := points[i] + offset + side0 * width_for(style, t0) * hi
			var c := points[i + 1] + offset + side1 * width_for(style, t1) * hi
			var d := points[i + 1] + offset + side1 * width_for(style, t1) * lo
			var color := color_for(style, band)
			color.a = 0.82 * (1.0 - smoothstep(0.5, 1.0, t0))
			for vertex in [a, b, c, a, c, d]:
				ribbon.surface_set_color(color)
				ribbon.surface_add_vertex(vertex)
	if begun: ribbon.surface_end()
