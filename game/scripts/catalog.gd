extends RefCounted
## Add entries here; selection menus are built from the catalogs, not fixed buttons.
const CHARACTERS = [
	{"id": "emil", "name": "Эмиль", "model": "res://assets/models/emil-lite.glb"},
	{"id": "sveta", "name": "Света", "model": "res://assets/models/sveta-lite.glb"},
]
const MAPS = [
	{"id": "clouds", "name": "Облака", "top": Color("64c9f0"), "horizon": Color("e6f5f9"), "bottom": Color("d6edfc"), "cloud": Color("f5fcff")},
	{"id": "sunset", "name": "Закат", "top": Color("ad8bd5"), "horizon": Color("ffe0b0"), "bottom": Color("edc4d4"), "cloud": Color("fff1dc")},
]
