extends RefCounted
const Catalog = preload("res://scripts/catalog.gd")
var cache: Dictionary = {}

func create_character(id: String, height: float = 1.7) -> Node3D:
	if not cache.has(id):
		for entry in Catalog.CHARACTERS:
			if entry.id == id:
				cache[id] = load(entry.model)
		if not cache.has(id):
			return null
	var packed: PackedScene = cache[id] as PackedScene
	if packed == null:
		return null
	var model: Node3D = packed.instantiate() as Node3D
	var box: AABB = _bounds(model, Transform3D.IDENTITY)
	if box.size.y <= 0.001:
		model.free()
		return null
	var pivot := Node3D.new()
	var s: float = height / box.size.y
	pivot.add_child(model)
	model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
	pivot.scale = Vector3.ONE * s
	return pivot

func _bounds(node: Node, parent_transform: Transform3D) -> AABB:
	var transform: Transform3D = parent_transform
	if node is Node3D:
		transform = parent_transform * node.transform
	var result := AABB()
	if node is MeshInstance3D and node.mesh != null:
		result = transform * node.get_aabb()
	for child in node.get_children():
		var child_box := _bounds(child, transform)
		if child_box.size.length_squared() > 0:
			result = child_box if result.size.length_squared() == 0 else result.merge(child_box)
	return result
