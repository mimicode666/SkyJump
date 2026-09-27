extends RefCounted
## Add entries here; selection menus are built from the catalogs, not fixed buttons.
const CHARACTERS = [
	{"id": "pikachu", "name": "Пикачу", "price": 0, "model": "res://assets/models/pikachu.glb"},
	{"id": "yablochko", "name": "Яблочко", "price": 0, "model": "res://assets/models/yablochko.glb"},
	{"id": "zaichik", "name": "Зайчик", "price": 50, "model": "res://assets/models/zaichik.glb"},
	{"id": "klubnich", "name": "Клубнич Джунгариков", "price": 75, "model": "res://assets/models/klubnich.glb"},
	{"id": "manye", "name": "Манье", "price": 200, "model": "res://assets/models/manye.glb"},
	{"id": "kirby", "name": "Кирби", "price": 250, "model": "res://assets/models/kirby-blink-fixed.glb"},
	{"id": "cinnamoroll", "name": "Синнаморол", "price": 250, "model": "res://assets/models/cinnamoroll.glb"},
]
const MAPS = [
	{"id": "clouds", "name": "Облака", "top": Color("64c9f0"), "horizon": Color("e6f5f9"), "bottom": Color("d6edfc"), "cloud": Color("f5fcff")},
	{"id": "sunset", "name": "Закат", "top": Color("ad8bd5"), "horizon": Color("ffe0b0"), "bottom": Color("edc4d4"), "cloud": Color("fff1dc")},
]

static func character(id: String) -> Dictionary:
	for entry in CHARACTERS:
		if entry.id == id: return entry
	return {}
