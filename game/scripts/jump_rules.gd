extends RefCounted
## A narrow 3D playfield keeps the first prototype easy to control.
const GRAVITY: float = 30.0
const JUMP_SPEED: float = 13.2
const BOOST_SPEED: float = 22.0
const MOVE_SPEED: float = 7.4
const ACCELERATION: float = 58.0
const HALF_WIDTH: float = 4.6
const PLATFORM_RADIUS: float = 0.78
const FOOT_RADIUS: float = 0.14
const LANDING_MARGIN: float = 0.05
const MIN_HEIGHT_STEP: float = 2.1
const MAX_HEIGHT_STEP: float = 2.6
const SPAWN_AHEAD: float = 24.0
const MAX_STEP_X: float = 2.85
const PLATFORM_EDGE: float = 3.55
const MOVING_MIN_SPEED: float = 1.1
const MOVING_MAX_SPEED: float = 3.8
const JETPACK_DURATION: float = 3.2
const JETPACK_SPEED: float = 24.0
const JETPACK_ACCELERATION: float = 40.0
const JETPACK_MIN_INTERVAL: int = 36
const JETPACK_MAX_INTERVAL: int = 52
const JETPACK_MAGNET_RADIUS: float = 3.4
const JETPACK_MAGNET_SPEED: float = 40.0

static func pace(height: float, seconds: float) -> float:
	# Scale simulation time, so jumps become quicker without changing their height.
	return 1.0 + 0.28 * clampf(height / 140.0, 0.0, 1.0) + 0.12 * clampf(seconds / 150.0, 0.0, 1.0)

static func wrap_x(x: float, half_width: float) -> float:
	return wrapf(x, -half_width, half_width)

static func lands(previous_y: float, next_y: float, velocity_y: float, player_x: float, platform: Vector3) -> bool:
	return velocity_y <= 0.0 and previous_y >= platform.y and next_y <= platform.y and absf(player_x - platform.x) <= PLATFORM_RADIUS + FOOT_RADIUS + LANDING_MARGIN

static func next_platform(previous: Vector3, rng: RandomNumberGenerator, before_previous: Vector3 = Vector3.INF) -> Vector3:
	var difficulty: float = clampf(previous.y / 35.0, 0.0, 1.0)
	var min_step_x: float = lerpf(1.75, 2.1, difficulty)
	var low: float = maxf(-PLATFORM_EDGE, previous.x - MAX_STEP_X)
	var high: float = minf(PLATFORM_EDGE, previous.x + MAX_STEP_X)
	var next_x: float = low if absf(low - previous.x) > absf(high - previous.x) else high
	# Sample inside the boundary instead of clamping: no vertical stacks at edges.
	# Three successive landing areas must never share one horizontal position.
	for attempt in range(64):
		var candidate: float = rng.randf_range(low, high)
		if absf(candidate - previous.x) < min_step_x:
			continue
		if before_previous.is_finite():
			var span: float = maxf(candidate, maxf(previous.x, before_previous.x)) - minf(candidate, minf(previous.x, before_previous.x))
			if span <= 2.0 * (PLATFORM_RADIUS + FOOT_RADIUS) + 0.12:
				continue
		next_x = candidate
		break
	# Fallback must preserve the same anti-column constraint, even at an edge.
	if before_previous.is_finite():
		var span: float = maxf(next_x, maxf(previous.x, before_previous.x)) - minf(next_x, minf(previous.x, before_previous.x))
		if span <= 2.0 * (PLATFORM_RADIUS + FOOT_RADIUS) + 0.12:
			next_x = high if next_x == low else low
	var gap: float = rng.randf_range(lerpf(MIN_HEIGHT_STEP, 2.3, difficulty), lerpf(2.35, MAX_HEIGHT_STEP, difficulty))
	return Vector3(next_x, previous.y + gap, 0.0)
