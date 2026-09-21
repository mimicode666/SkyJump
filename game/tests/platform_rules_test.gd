extends SceneTree
const Rules = preload("res://scripts/jump_rules.gd")
const Platform = preload("res://scripts/jump_platform.gd")

func _initialize() -> void:
	var checked: int = 0
	var lowest_gap: float = INF
	var highest_gap: float = 0.0
	for seed_number in range(200):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_number
		var before := Vector3.INF
		var previous := Vector3.ZERO
		var x: float = 0.0
		var vx: float = 0.0
		for step in range(200):
			var next: Vector3 = Rules.next_platform(previous, rng, before)
			var gap: float = next.y - previous.y
			lowest_gap = minf(lowest_gap, gap)
			highest_gap = maxf(highest_gap, gap)
			if not _check(absf(next.x) <= Rules.PLATFORM_EDGE + 0.001, "Out of bounds"):
				return
			if not _check(absf(next.x - previous.x) <= Rules.MAX_STEP_X + 0.001 and absf(next.x - previous.x) >= 1.749, "Invalid horizontal step"):
				return
			if not _check(gap >= Rules.MIN_HEIGHT_STEP - 0.001 and gap <= Rules.MAX_HEIGHT_STEP + 0.001, "Invalid vertical gap"):
				return
			if before.is_finite():
				var span: float = maxf(next.x, maxf(previous.x, before.x)) - minf(next.x, minf(previous.x, before.x))
				if not _check(span > 2 * (Rules.PLATFORM_RADIUS + Rules.FOOT_RADIUS), "Three-platform vertical shortcut"):
					return
			# Simulate the real acceleration and gravity with the same steering as the live pilot.
			var y: float = previous.y
			var vy: float = Rules.JUMP_SPEED
			var landed: bool = false
			for frame in range(100):
				var difference: float = next.x - x - vx * 0.12
				var direction: float = signf(difference) if absf(difference) > 0.1 else 0.0
				vx = move_toward(vx, direction * Rules.MOVE_SPEED, Rules.ACCELERATION / 60.0)
				var previous_y: float = y
				vy -= Rules.GRAVITY / 60.0
				x = clampf(x + vx / 60.0, -Rules.HALF_WIDTH, Rules.HALF_WIDTH)
				y += vy / 60.0
				if Rules.lands(previous_y, y, vy, x, next):
					landed = true
					break
			if not _check(landed, "Unreachable route seed=%d step=%d dx=%f gap=%f" % [seed_number, step, next.x - previous.x, gap]):
				return
			before = previous
			previous = next
			checked += 1
	var stone := Platform.new()
	stone.configure(Color.WHITE, true)
	if not _check(not stone.register_landing() and stone.hits == 1 and stone.active, "Stone broke before second landing"):
		return
	if not _check(stone.cracks.all(func(part): return part.visible), "Cracks not shown"):
		return
	if not _check(stone.register_landing() and stone.hits == 2 and not stone.active, "Stone did not break on second landing"):
		return
	if not _check(not stone.register_landing() and stone.hits == 2, "Broken stone accepted another landing"):
		return
	stone.free()
	var normal := Platform.new()
	normal.configure(Color.GREEN, false)
	for i in range(10):
		if not _check(not normal.register_landing() and normal.active, "Normal platform broke"):
			return
	normal.free()
	print("PLATFORM_TEST_OK routes=200 jumps=", checked, " gap_range=", lowest_gap, "..", highest_gap)
	quit(0)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
