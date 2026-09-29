extends Node3D
const Rules = preload("res://scripts/jump_rules.gd")
var active := true

func _ready() -> void:
	var disk := CylinderMesh.new()
	disk.top_radius = 0.27
	disk.bottom_radius = 0.27
	disk.height = 0.09
	disk.radial_segments = 16
	var mesh := MeshInstance3D.new()
	mesh.mesh = disk
	mesh.rotation.x = PI / 2
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("ffd044")
	gold.roughness = 0.5
	mesh.material_override = gold
	add_child(mesh)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.19
	rim.outer_radius = 0.24
	rim.rings = 16
	rim.ring_segments = 4
	var border := MeshInstance3D.new()
	border.mesh = rim
	border.rotation.x = PI / 2
	border.position.z = 0.05
	var bright := StandardMaterial3D.new()
	bright.albedo_color = Color("fff3a8")
	border.material_override = bright
	add_child(border)

func attract(player_position: Vector3, step: float) -> void:
	if not active: return
	var target := player_position + Vector3.UP * 0.8
	# Recheck proximity every tick: no attraction across a screen-wrap teleport.
	if global_position.distance_to(target) <= Rules.JETPACK_MAGNET_RADIUS:
		global_position = global_position.move_toward(target, Rules.JETPACK_MAGNET_SPEED * step)

func collect(player_position: Vector3) -> bool:
	if not active or global_position.distance_to(player_position + Vector3(0, 0.8, 0)) > 0.6:
		return false
	active = false
	hide()
	queue_free()
	return true
