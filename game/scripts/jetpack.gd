extends Node3D
## Shared lightweight artwork for the pickup and the equipped jetpack.
var active := true
var flames: Array[Node3D] = []
var elapsed := 0.0

func _ready() -> void:
	var body := BoxMesh.new()
	body.size = Vector3(0.62, 0.55, 0.3)
	_piece(body, Vector3(0, 0.04, 0), Color("f0b937"))
	for side in [-1, 1]:
		var tank := CapsuleMesh.new()
		tank.radius = 0.19
		tank.height = 0.83
		tank.radial_segments = 12
		tank.rings = 4
		_piece(tank, Vector3(side * 0.43, 0.08, 0), Color("e6f3ff"))
		var nozzle := CylinderMesh.new()
		nozzle.top_radius = 0.15
		nozzle.bottom_radius = 0.12
		nozzle.height = 0.17
		nozzle.radial_segments = 10
		_piece(nozzle, Vector3(side * 0.43, -0.38, 0), Color("365676"))
		var exhaust := Node3D.new()
		add_child(exhaust)
		exhaust.position = Vector3(side * 0.43, -0.43, 0)
		for core in [false, true]:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.10 if core else 0.15
			cone.bottom_radius = 0
			cone.height = 0.56 if core else 0.85
			cone.radial_segments = 10
			var flame := _piece(cone, Vector3(0, -cone.height / 2, 0.01 if core else 0), Color("fff6bc") if core else Color("39ccff"), true)
			remove_child(flame)
			exhaust.add_child(flame)
		exhaust.hide()
		flames.append(exhaust)
	var light := SphereMesh.new()
	light.radius = 0.09
	light.height = 0.18
	light.radial_segments = 10
	light.rings = 4
	_piece(light, Vector3(0, 0.10, 0.19), Color("39e5ff"), true)

func _piece(mesh: Mesh, at: Vector3, color: Color, unshaded: bool = false) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	if unshaded: material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)
	return part

func animate(delta: float, flying: bool) -> void:
	elapsed += delta
	if not flying: rotation.y += delta * 1.4
	for flame in flames:
		flame.visible = flying
		flame.scale.y = 0.9 + sin(elapsed * 31) * 0.10 + sin(elapsed * 47) * 0.06

func collect(previous: Vector3, current: Vector3) -> bool:
	if not active: return false
	var center := global_position
	var closest := Geometry3D.get_closest_point_to_segment(center, previous + Vector3.UP * 0.8, current + Vector3.UP * 0.8)
	if center.distance_to(closest) > 0.72: return false
	active = false
	hide()
	queue_free()
	return true
