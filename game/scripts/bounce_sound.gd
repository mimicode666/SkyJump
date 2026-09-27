extends AudioStreamPlayer
## Prebuilt PCM samples work with the single-threaded Web Audio sample backend.
const SOUNDS = {
	"normal": preload("res://assets/audio/pop.wav"),
	"stone": preload("res://assets/audio/stone.wav"),
	"boost": preload("res://assets/audio/spring.wav"),
}
var unlocked := false
var variation := RandomNumberGenerator.new()

func _ready() -> void:
	variation.seed = 2809
	volume_db = -12
	max_polyphony = 2

func bounce(kind: String) -> void:
	if not unlocked: return
	stream = SOUNDS.get(kind, SOUNDS.normal)
	pitch_scale = variation.randf_range(0.97, 1.03)
	play()
