extends Node3D
## A platform owns its durability and appearance; the level owns collision order.
const Rules = preload("res://scripts/jump_rules.gd")
const Journey = preload("res://scripts/journey.gd")
var stone: bool = false
var kind: String = "normal"
var origin_x: float = 0.0
var motion_time: float = 0.0
var motion_amplitude: float = 0.0
var motion_speed: float = 1.55
var hits: int = 0
var active: bool = true
var parts: Array[MeshInstance3D] = []
var cracks: Array[MeshInstance3D] = []
var marks: Array[MeshInstance3D] = []
var break_elapsed: float = -1.0
var break_origin: Vector3
var break_rotation: float = 0.0
var artwork := Node3D.new()
var landing_elapsed := -1.0
var pulse: MeshInstance3D
var springs: Array[MeshInstance3D] = []
var crumbs: Array[MeshInstance3D] = []
var surface_color: Color

func configure(color: Color, is_stone: bool = false, type_id: String = "normal", speed: float = 1.55) -> void:
	add_child(artwork)
	stone = is_stone
	kind = "stone" if stone else type_id
	origin_x = position.x
	motion_time = position.y * 1.7
	motion_speed = clampf(speed, Rules.MOVING_MIN_SPEED, Rules.MOVING_MAX_SPEED * Journey.MOTION_MULTIPLIERS[Journey.Zone.GALAXIES])
	motion_amplitude = minf(0.7, maxf(0.0, Rules.HALF_WIDTH - Rules.PLATFORM_RADIUS - absf(origin_x)))
	var base_color: Color = Color("85919f") if stone else color
	if kind == "moving":
		base_color = Color("12bed1")
	elif kind == "boost":
		base_color = Color("ff7bb8")
	elif kind == "spikes":
		base_color = Color("dc5356")
	surface_color = base_color
	var disk := CylinderMesh.new()
	disk.top_radius = Rules.PLATFORM_RADIUS
	disk.bottom_radius = Rules.PLATFORM_RADIUS * (0.84 if stone else 0.9)
	disk.height = 0.38 if stone else 0.3
	disk.radial_segments = 10 if stone else 32
	_piece(disk, Vector3(0, -disk.height / 2, 0), base_color, false)
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
		_piece(ring, Vector3(0, -0.04, 0), base_color.lightened(0.22), false)
	if kind == "spikes":
		for x in [-0.62, 0.0, 0.62]:
			for z in [-0.35, 0.32]:
				var spike := CylinderMesh.new()
				spike.top_radius = 0.0
				spike.bottom_radius = 0.2
				spike.height = 0.48
				spike.radial_segments = 6
				_piece(spike, Vector3(x, 0.24, z), Color("f7eded"))
	elif kind == "boost":
		# Raised spring rings remain identifiable without relying on colour.
		for i in range(3):
			var spring := TorusMesh.new()
			spring.inner_radius = 0.23
			spring.outer_radius = 0.33
			spring.rings = 16
			spring.ring_segments = 6
			var coil := _piece(spring, Vector3(0, 0.05 + i * 0.09, 0), Color("fff1a8"))
			coil.set_meta("rest_y", coil.position.y)
			springs.append(coil)
	elif kind == "moving":
		for sign_x in [-1, 1]:
			for sign_z in [-1, 1]:
				var stripe := BoxMesh.new()
				stripe.size = Vector3(0.36, 0.025, 0.085)
				var part := _piece(stripe, Vector3(sign_x * 0.36, 0.025, sign_z * 0.12), Color("edffff"))
				part.rotation.y = sign_x * sign_z * 0.65
	_setup_landing_effect()

func apply_environment(height: float) -> void:
	var theme := Journey.sample(height)
	var disk: StandardMaterial3D = parts[0].material_override
	disk.albedo_texture = Journey.platform_texture(Journey.Zone.MOON if stone else theme.index)
	disk.roughness = 0.55 if theme.index == 1 and not stone else 0.85
	if kind == "normal":
		disk.albedo_color = theme.surface
		parts[1].material_override.albedo_color = theme.surface.lightened(0.24)
		parts[1].material_override.emission_enabled = theme.dark > 0.5
		parts[1].material_override.emission = theme.surface * 0.18

func _setup_landing_effect() -> void:
	if kind == "spikes": return
	if stone:
		for i in range(4):
			var chip := BoxMesh.new()
			chip.size = Vector3.ONE * 0.07
			var crumb := _piece(chip, Vector3.ZERO, Color("b8c4cf"), false)
			crumb.hide()
			crumbs.append(crumb)
		return
	pulse = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = Rules.PLATFORM_RADIUS - 0.035
	ring.outer_radius = Rules.PLATFORM_RADIUS + 0.005
	ring.rings = 32
	ring.ring_segments = 6
	pulse.mesh = ring
	pulse.position.y = 0.045
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color("fff6d6")
	pulse.material_override = glow
	pulse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	artwork.add_child(pulse)
	pulse.hide()

func advance_feedback(delta: float) -> void:
	if landing_elapsed < 0 or not active: return
	landing_elapsed += delta
	var t: float = clampf(landing_elapsed / (0.34 if kind == "boost" else 0.26), 0, 1)
	if stone:
		artwork.position.x = sin(t * 45.0) * (1 - t) * 0.025
		for i in range(crumbs.size()):
			var angle: float = i * TAU / crumbs.size()
			crumbs[i].position = Vector3(cos(angle) * (0.2 + t * 0.55), sin(t * PI) * 0.25 - t * 0.12, sin(angle) * (0.2 + t * 0.55))
			crumbs[i].scale = Vector3.ONE * (1 - t * 0.9)
	else:
		var compression: float = sin(t * PI * 2.0) * exp(-t * 3.0)
		artwork.scale = Vector3(1 + compression * 0.12, 1 - compression * 0.24, 1 + compression * 0.12)
		pulse.scale = Vector3.ONE * (1 + t * 0.28)
		pulse.material_override.albedo_color.a = sin(t * PI) * (1 - t) * 0.75
		for i in range(springs.size()):
			springs[i].position.y = springs[i].get_meta("rest_y") + sin(t * PI) * (i + 1) * 0.12
	if t >= 1:
		landing_elapsed = -1
		artwork.scale = Vector3.ONE
		artwork.position = Vector3.ZERO
		if pulse != null: pulse.hide()
		for crumb in crumbs: crumb.hide()
		for coil in springs: coil.position.y = coil.get_meta("rest_y")

func advance_motion(delta: float) -> void:
	if kind == "moving" and active:
		motion_time += delta * motion_speed
		position.x = origin_x + sin(motion_time) * motion_amplitude

func _piece(mesh: Mesh, offset: Vector3, color: Color, fit_to_disk: bool = true) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	# Decorations use the original disk's proportions; keep them within smaller rims.
	if fit_to_disk:
		var ratio: float = Rules.PLATFORM_RADIUS / 1.04
		part.scale = Vector3(ratio, 1.0, ratio)
		offset *= Vector3(ratio, 1.0, ratio)
	part.position = offset
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0 if stone else 0.85
	part.material_override = mat
	artwork.add_child(part)
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
	if not active: return false
	landing_elapsed = 0.0
	if pulse != null: pulse.show()
	for crumb in crumbs: crumb.show()
	if not stone: return false
	hits += 1
	marks[mini(hits - 1, 1)].hide()
	if hits == 1:
		for crack in cracks:
			crack.show()
		return false
	active = false
	return true

func break_apart() -> void:
	landing_elapsed = -1
	artwork.scale = Vector3.ONE
	artwork.position = Vector3.ZERO
	break_origin = position
	break_elapsed = 0.0
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
