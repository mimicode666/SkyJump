extends Node3D
## All heights are world units (the HUD displays ten metres per unit).
const NightSky = preload("res://scripts/night_sky.gd")
enum Zone { EARTH, RAIN, SNOW, CLOUDS, SUNSET, NIGHT, MOON, GALAXIES }
const MOTION_MULTIPLIERS = {Zone.NIGHT: 1.2, Zone.MOON: 1.35, Zone.GALAXIES: 1.5}
const STAGES = [
	{"at": 0.0, "name": "Земля", "top": Color("66cce8"), "horizon": Color("e5f5de"), "cloud": Color("f5fcff"), "surface": Color("95c75b"), "land": 1.0, "clouds": 1.0},
	{"at": 50.0, "name": "Дождевые облака", "top": Color("506b8e"), "horizon": Color("bac9db"), "cloud": Color("a7b8d0"), "surface": Color("8ccbd9"), "rain": 1.0, "clouds": 1.0, "dark": 1.0},
	{"at": 110.0, "name": "Снежное небо", "top": Color("739fc3"), "horizon": Color("e4effa"), "cloud": Color("d9e8f4"), "surface": Color("f0f8ff"), "snow": 1.0, "clouds": 0.7},
	{"at": 180.0, "name": "Над облаками", "top": Color("5daeea"), "horizon": Color("e6f7ff"), "cloud": Color("ffffff"), "surface": Color("e4e9fb"), "clouds": 1.0},
	{"at": 280.0, "name": "Закат", "top": Color("9369b6"), "horizon": Color("ffd4a0"), "cloud": Color("fff0d7"), "surface": Color("efc080"), "clouds": 0.8},
	{"at": 410.0, "name": "Звёздная ночь", "top": Color("010103"), "horizon": Color("03050b"), "cloud": Color("181b35"), "surface": Color("9caedf"), "stars": 1.0, "moon": 1.0, "dark": 1.0},
	{"at": 580.0, "name": "У Луны", "top": Color("010104"), "horizon": Color("060815"), "cloud": Color("181b35"), "surface": Color("bdc4d3"), "stars": 1.0, "moon": 1.0, "near_moon": 1.0, "dark": 1.0},
	{"at": 800.0, "name": "Далёкие галактики", "top": Color("080519"), "horizon": Color("100c26"), "cloud": Color("181b35"), "surface": Color("a69bd9"), "stars": 1.0, "galaxy": 1.0, "dark": 1.0},
]
const FADE_HEIGHT := 20.0
static var textures: Dictionary = {}
var night := NightSky.new()
var hills := Node3D.new()
var rain := MultiMeshInstance3D.new()
var snow := MultiMeshInstance3D.new()
var galaxies := MultiMeshInstance3D.new()
var galaxy_haze := MultiMeshInstance3D.new()
var rain_points: Array[Vector2] = []
var snow_points: Array[Vector3] = []
var galaxy_points: Array[Vector3] = []
var elapsed := 0.0
var state: Dictionary = {}
var galaxy_span := Vector2.ZERO

static func stage_index(height: float) -> int:
	var result := 0
	for i in range(STAGES.size()):
		if height >= STAGES[i].at: result = i
	return result

static func moving_speed_multiplier(height: float) -> float:
	return MOTION_MULTIPLIERS.get(stage_index(height), 1.0)

static func sample(height: float) -> Dictionary:
	var index := stage_index(height)
	var current: Dictionary = STAGES[index]
	var previous: Dictionary = STAGES[maxi(0, index - 1)]
	var blend := smoothstep(current.at, current.at + FADE_HEIGHT, height) if index > 0 else 1.0
	var result := {"index": index, "name": current.name}
	for key in ["top", "horizon", "cloud", "surface"]:
		result[key] = previous[key].lerp(current[key], blend)
	for key in ["land", "clouds", "rain", "snow", "stars", "moon", "near_moon", "galaxy", "dark"]:
		result[key] = lerpf(previous.get(key, 0.0), current.get(key, 0.0), blend)
	return result

static func platform_texture(zone: int) -> Texture2D:
	if textures.has(zone): return textures[zone]
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in range(64):
		for x in range(64):
			var grain := fmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)
			var value: float = 0.93 + absf(grain) * 0.07
			if zone == 0 and (x + y * 3) % 13 < 2: value = 0.83 # Grass fibres.
			elif zone == 1 and (x * 7 + y * 11) % 41 < 2: value = 0.8 # Droplets.
			elif zone == Zone.SNOW: value = 0.96 if (x * 11 + y * 7) % 31 > 2 else 0.84
			elif zone == Zone.CLOUDS: value = 0.93 + sin(x * 0.15 + sin(y * 0.2)) * 0.07
			elif zone == Zone.SUNSET: value = 0.94 + sin(y * 0.3) * 0.06
			elif zone == Zone.MOON:
				for crater in [Vector3(18, 22, 9), Vector3(47, 43, 11), Vector3(45, 13, 5)]:
					var distance: float = Vector2(x - crater.x, y - crater.y).length() / crater.z
					if distance < 1: value *= 0.75 + 0.25 * distance
			elif zone >= Zone.NIGHT and (x * 17 + y * 31) % 151 == 0: value = 0.72
			image.set_pixel(x, y, Color(value, value, value))
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	textures[zone] = texture
	return texture

func _ready() -> void:
	position.z = -40
	add_child(night)
	night.position.z = 0
	add_child(hills)
	for i in range(4):
		var hill := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radial_segments = 24
		sphere.rings = 10
		hill.mesh = sphere
		hill.material_override = _material(Color("8ebf85").lightened(i * 0.045))
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hills.add_child(hill)
	_setup_batch(rain, 42, Color("d8e8f8"))
	_setup_batch(snow, 72, Color.WHITE)
	var flake := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var radius := (Vector2(x, y) - Vector2(7.5, 7.5)).length() / 7.5
			flake.set_pixel(x, y, Color(1, 1, 1, 1 - smoothstep(0.4, 1.0, radius)))
	snow.material_override.albedo_texture = ImageTexture.create_from_image(flake)
	_setup_batch(galaxies, 192, Color.WHITE)
	_setup_batch(galaxy_haze, 2, Color.WHITE)
	var glow := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var radius := (Vector2(x, y) - Vector2(31.5, 31.5)).length() / 31.5
			var color := Color("b198ef").lerp(Color("fff1cd"), exp(-radius * 9))
			color.a = exp(-radius * 5.5) * smoothstep(1.0, 0.65, radius) * 0.7
			glow.set_pixel(x, y, color)
	galaxy_haze.material_override.albedo_texture = ImageTexture.create_from_image(glow)
	var random := RandomNumberGenerator.new()
	random.seed = 280926 # Never consume the route's RNG.
	for i in range(42): rain_points.append(Vector2(random.randf(), random.randf()))
	for i in range(72): snow_points.append(Vector3(random.randf(), random.randf(), random.randf()))
	for i in range(192):
		var arm: float = i % 3 * TAU / 3.0
		var radius := random.randf_range(0.02, 1.0)
		var angle := arm + radius * 5.8 + random.randf_range(-0.14, 0.14)
		galaxy_points.append(Vector3(cos(angle) * radius, sin(angle) * radius * 0.38, random.randf_range(0.018, 0.044)))
		galaxies.multimesh.set_instance_color(i, Color("c0aaff").lerp(Color("fff3da"), 1 - radius))

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	return material

func _setup_batch(node: MultiMeshInstance3D, count: int, color: Color) -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = mesh
	batch.instance_count = count
	for i in range(count): batch.set_instance_color(i, Color.WHITE)
	node.multimesh = batch
	node.material_override = _material(color)
	node.material_override.vertex_color_use_as_albedo = true
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func update_view(height: float, span: Vector2, delta: float) -> void:
	state = sample(height)
	elapsed += delta
	var small := minf(span.x, span.y)
	night.visible = state.stars > 0.001
	if night.visible:
		night.layout(span, lerpf(0.27, -0.12, state.near_moon))
		night.set_weights(state.stars, state.moon)
		# layout caches the span, so explicitly set the absolute scale each frame.
		night.moon.scale = Vector3.ONE * small * 0.085 * lerpf(1.0, 4.2, state.near_moon)
	hills.visible = state.land > 0.001
	for i in range(hills.get_child_count()):
		var hill = hills.get_child(i)
		hill.position = Vector3(span.x * (-0.48 + i * 0.33), -span.y * (0.48 + (1 - state.land) * 0.2), -3 - i * 0.1)
		hill.scale = Vector3(span.x * 0.65, span.y * (0.22 + (i % 2) * 0.08), 0.8)
		hill.material_override.albedo_color.a = state.land
	rain.visible = state.rain > 0.001
	if rain.visible:
		rain.material_override.albedo_color.a = state.rain * 0.38
		for i in range(rain_points.size()):
			var p := rain_points[i]
			var at := Vector3((p.x - 0.5) * span.x, (0.5 - fposmod(p.y + elapsed * 0.32, 1.0)) * span.y, -1)
			var basis := Basis.IDENTITY.scaled(Vector3(0.012, 0.18, 1)).rotated(Vector3.FORWARD, -0.13)
			rain.multimesh.set_instance_transform(i, Transform3D(basis, at))
	snow.visible = state.snow > 0.001
	if snow.visible:
		snow.material_override.albedo_color.a = state.snow * 0.9
		for i in range(snow_points.size()):
			var p := snow_points[i]
			var x := fposmod(p.x + sin(elapsed * 0.55 + i) * 0.018, 1.0)
			var y := fposmod(p.y + elapsed * lerpf(0.045, 0.10, p.z), 1.0)
			var size := lerpf(0.035, 0.085, p.z)
			var at := Vector3((x - 0.5) * span.x, (0.5 - y) * span.y, -0.5)
			snow.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(size, size, 1)), at))
	galaxies.visible = state.galaxy > 0.001
	galaxy_haze.visible = galaxies.visible
	if galaxies.visible:
		galaxies.material_override.albedo_color.a = state.galaxy * 0.8
		galaxy_haze.material_override.albedo_color.a = state.galaxy
		if span.is_equal_approx(galaxy_span): return
		galaxy_span = span
		for i in range(2):
			var center := Vector2(-span.x * 0.22, span.y * 0.25) if i == 0 else Vector2(span.x * 0.28, -span.y * 0.23)
			galaxy_haze.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(small * 0.6, small * 0.23, 1)), Vector3(center.x, center.y, -2.1)))
		for i in range(galaxy_points.size()):
			var p := galaxy_points[i]
			var group: int = i % 2
			var center := Vector2(-span.x * 0.22, span.y * 0.25) if group == 0 else Vector2(span.x * 0.28, -span.y * 0.23)
			var at := Vector3(center.x + p.x * small * 0.28, center.y + p.y * small * 0.28, -2)
			galaxies.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * p.z), at))
