extends Node3D
## A platform owns its durability and appearance; the level owns collision order.
const Rules = preload("res://scripts/jump_rules.gd")
var stone: bool = false
var hits: int = 0
var active: bool = true
var parts: Array[MeshInstance3D] = []
var cracks: Array[MeshInstance3D] = []
var marks: Array[MeshInstance3D] = []
var break_elapsed: float = -1.0
var break_origin: Vector3
var break_rotation: float = 0.0

func configure(color: Color, is_stone: bool) -> void:
	stone = is_stone
	var base_color: Color = Color("85919f") if stone else color
	var disk := CylinderMesh.new()
	disk.top_radius = Rules.PLATFORM_RADIUS
	disk.bottom_radius = Rules.PLATFORM_RADIUS * (0.84 if stone else 0.9)
	disk.height = 0.38 if stone else 0.3
	disk.radial_segments = 10 if stone else 32
	_piece(disk, Vector3(0, -disk.height / 2, 0), base_color)
	if stone:
		# Two small surface marks show the remaining landings.
		for x in [-0.17, 0.17]:
			var dot := CylinderMesh.new()
			dot.top_radius = 0.075
			dot.bottom_radius = 0.075
			dot.height = 0.015
			dot.radial_segments = 8
			marks.append(_piece(dot, Vector3(x, 0.012, 0.57), Color("e6f2ff")))
		var paths = [Vector2(-0.78, -0.35), Vector2(-0.24, -0.13), Vector2(0.04, 0.17), Vector2(0.5, 0.34), Vector2(0.81, 0.63)]
		for i in range(paths.size() - 1):
			_crack(paths[i], paths[i + 1])
		_crack(Vector2(-0.24, -0.13), Vector2(-0.02, -0.68))
		_crack(Vector2(0.04, 0.17), Vector2(-0.32, 0.75))
	else:
		var ring := TorusMesh.new()
		ring.inner_radius = Rules.PLATFORM_RADIUS - 0.09
		ring.outer_radius = Rules.PLATFORM_RADIUS
		ring.rings = 32
		ring.ring_segments = 8
		_piece(ring, Vector3(0, -0.04, 0), color.lightened(0.22))

func _piece(mesh: Mesh, offset: Vector3, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = offset
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0 if stone else 0.85
	part.material_override = mat
	add_child(part)
	parts.append(part)
	return part

func _crack(a: Vector2, b: Vector2) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(a.distance_to(b), 0.012, 0.045)
	var middle: Vector2 = (a + b) / 2.0
	var part := _piece(mesh, Vector3(middle.x, 0.015, middle.y), Color("354356"))
	part.rotation.y = -atan2(b.y - a.y, b.x - a.x)
	part.hide()
	cracks.append(part)

func register_landing() -> bool:
	if not active or not stone:
		return false
	hits += 1
	marks[mini(hits - 1, 1)].hide()
	if hits == 1:
		for crack in cracks:
			crack.show()
		return false
	active = false
	return true

func break_apart() -> void:
	break_origin = position
	break_elapsed = 0.0
	set_obscured(false)
	# The original low-poly disk becomes a few cheap fragments, with no rigid bodies.
	for part in parts:
		part.hide()
	for i in range(5):
		var chunk := BoxMesh.new()
		chunk.size = Vector3(0.45, 0.25, 0.45)
		var angle: float = i * TAU / 5
		var fragment := _piece(chunk, Vector3(cos(angle) * 0.45, -0.12, sin(angle) * 0.45), Color("85919f"))
		fragment.rotation = Vector3(i * 0.31, angle, 0.2)
	break_rotation = -0.6 if position.x < 0 else 0.6

func animate_break(delta: float) -> void:
	if break_elapsed < 0:
		return
	break_elapsed += delta
	var t: float = minf(break_elapsed / 0.45, 1.0)
	position.y = break_origin.y - t * t * 1.4
	rotation.z = break_rotation * t
	scale = Vector3.ONE * (1.0 - t * 0.75)
	if t >= 1:
		queue_free()

func set_obscured(obscured: bool) -> void:
	for part in parts:
		var mat: StandardMaterial3D = part.material_override
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if obscured else BaseMaterial3D.TRANSPARENCY_DISABLED
		mat.albedo_color.a = 0.2 if obscured else 1.0
