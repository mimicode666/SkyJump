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
	{"id": "clouds", "name": "Облака", "price": 0, "top": Color("64c9f0"), "horizon": Color("e6f5f9"), "bottom": Color("d6edfc"), "cloud": Color("f5fcff")},
	{"id": "sunset", "name": "Закат", "price": 0, "top": Color("ad8bd5"), "horizon": Color("ffe0b0"), "bottom": Color("edc4d4"), "cloud": Color("fff1dc")},
	{"id": "lavender", "name": "Лаванда", "price": 50, "top": Color("c2a0fa"), "horizon": Color("f8edff"), "bottom": Color("e4d3fb"), "cloud": Color("fff5ff")},
	{"id": "mint", "name": "Мятное небо", "price": 75, "top": Color("77dab8"), "horizon": Color("def8f0"), "bottom": Color("b8e8df"), "cloud": Color("effff4")},
	{"id": "peach", "name": "Персиковый рассвет", "price": 100, "top": Color("f5b484"), "horizon": Color("ffeddc"), "bottom": Color("f6d3cb"), "cloud": Color("fff9e8")},
	{"id": "moon", "name": "Лунное небо", "price": 150, "top": Color("8998c7"), "horizon": Color("d8def3"), "bottom": Color("bacced"), "cloud": Color("f3f0ff")},
]

static func character(id: String) -> Dictionary:
	for entry in CHARACTERS:
		if entry.id == id: return entry
	return {}

static func map_entry(id: String) -> Dictionary:
	for entry in MAPS:
		if entry.id == id: return entry
	return {}
