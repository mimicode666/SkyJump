extends Node3D
## Camera-local decoration: one batched star mesh and a small, unlit moon.
## No textures, lights, animation or shared gameplay RNG.
var stars := MultiMeshInstance3D.new()
var moon := Node3D.new()
var points: Array[Vector2] = []
var sizes: Array[float] = []
var last_span := Vector2.ZERO
var last_moon_y := -1.0

func _ready() -> void:
	position.z = -40
	var random := RandomNumberGenerator.new()
	random.seed = 1907
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = mesh
	batch.instance_count = 64
	stars.multimesh = batch
	stars.material_override = _material(Color.WHITE, true)
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stars)
	for i in range(batch.instance_count):
		points.append(Vector2(random.randf_range(-0.49, 0.49), random.randf_range(-0.48, 0.48)))
		sizes.append(random.randf_range(0.022, 0.052))
		batch.set_instance_color(i, Color("fff3d3") if i % 5 == 0 else Color("c6d5f6").lerp(Color.WHITE, random.randf()))
	add_child(moon)
	_disk(moon, Vector3.ZERO, Vector3(1, 1, 0.045), Color("fff3d1"))
	_disk(moon, Vector3(-0.32, 0.3, 0.048), Vector3(0.21, 0.16, 0.005), Color("dbd7c4"))
	_disk(moon, Vector3(0.36, -0.15, 0.048), Vector3(0.29, 0.22, 0.005), Color("e0dcc7"))
	_disk(moon, Vector3(-0.2, -0.46, 0.048), Vector3(0.12, 0.1, 0.005), Color("d4d1c0"))
	_disk(moon, Vector3(0.32, 0.49, 0.048), Vector3(0.1, 0.085, 0.005), Color("e0dcc7"))

func _material(color: Color, vertex_colors: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.albedo_color = color
	result.vertex_color_use_as_albedo = vertex_colors
	return result

func _disk(parent: Node3D, at: Vector3, dimensions: Vector3, color: Color) -> void:
	var disk := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1
	sphere.height = 2
	sphere.radial_segments = 32
	sphere.rings = 12
	disk.mesh = sphere
	disk.material_override = _material(color)
	disk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disk.position = at
	disk.scale = dimensions
	parent.add_child(disk)

func layout(span: Vector2, moon_y: float) -> void:
	if span.is_equal_approx(last_span) and is_equal_approx(moon_y, last_moon_y): return
	last_span = span
	last_moon_y = moon_y
	for i in range(points.size()):
		var basis := Basis.IDENTITY.scaled(Vector3.ONE * sizes[i])
		basis = basis.rotated(Vector3.FORWARD, PI * 0.25)
		stars.multimesh.set_instance_transform(i, Transform3D(basis, Vector3(points[i].x * span.x, points[i].y * span.y, -0.1)))
	moon.position = Vector3(span.x * 0.3, span.y * moon_y, 0)
	moon.scale = Vector3.ONE * minf(span.x, span.y) * 0.085
