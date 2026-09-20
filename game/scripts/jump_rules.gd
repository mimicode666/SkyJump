extends RefCounted
## A narrow 3D playfield keeps the first prototype easy to control.
const GRAVITY: float = 21.0
const JUMP_SPEED: float = 10.3
const MOVE_SPEED: float = 5.4
const ACCELERATION: float = 24.0
const HALF_WIDTH: float = 4.6
const PLATFORM_RADIUS: float = 1.04
const FOOT_RADIUS: float = 0.18
const HEIGHT_STEP: float = 1.6
const MAX_STEP_X: float = 2.4

static func lands(previous_y: float, next_y: float, velocity_y: float, player_x: float, platform: Vector3) -> bool:
	return velocity_y <= 0.0 and previous_y >= platform.y and next_y <= platform.y and absf(player_x - platform.x) <= PLATFORM_RADIUS + FOOT_RADIUS

static func next_platform(previous: Vector3, rng: RandomNumberGenerator) -> Vector3:
	var next_x: float = clampf(previous.x + rng.randf_range(-MAX_STEP_X, MAX_STEP_X), -3.55, 3.55)
	return Vector3(next_x, previous.y + HEIGHT_STEP, 0.0)
