extends RefCounted
## Add characters here; the selection menu is built from this catalog.
const CHARACTERS = [
	{"id": "pikachu", "name": "Пикачу", "price": 0, "model": "res://assets/models/pikachu.glb"},
	{"id": "yablochko", "name": "Яблочко", "price": 0, "model": "res://assets/models/yablochko.glb"},
	{"id": "zaichik", "name": "Зайчик", "price": 50, "model": "res://assets/models/zaichik.glb"},
	{"id": "klubnich", "name": "Клубнич Джунгариков", "price": 75, "model": "res://assets/models/klubnich.glb"},
	{"id": "manye", "name": "Манье", "price": 200, "model": "res://assets/models/manye.glb"},
	{"id": "kirby", "name": "Кирби", "price": 250, "model": "res://assets/models/kirby-blink-fixed.glb"},
	{"id": "cinnamoroll", "name": "Синнаморол", "price": 250, "model": "res://assets/models/cinnamoroll.glb"},
]

static func character(id: String) -> Dictionary:
	for entry in CHARACTERS:
		if entry.id == id: return entry
	return {}
