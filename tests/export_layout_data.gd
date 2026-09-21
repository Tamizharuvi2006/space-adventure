extends SceneTree

func _init() -> void:
	var WorldGen = load("res://scripts/world_generator.gd")
	var Validator = load("res://scripts/flight_validator.gd")
	var gen = WorldGen.new()

	var pads: Array = []
	var cur_x = 0.0
	var cur_y = 480.0

	# Add Pad 0 (Spawn pad)
	pads.append({
		"idx": 0,
		"x": cur_x,
		"y": cur_y,
		"dx": 0.0,
		"dy": 0.0,
		"width": 190.0,
		"motif": "VALLEY_SHELF",
		"pattern": "SPAWN",
		"chapter": "Prologue",
		"fuel": 100.0,
		"ok": true
	})

	for idx in range(1, 101):
		var bp = gen.get_pad_blueprint(idx, cur_y)
		var dx: float = bp.dx
		var dy: float = bp.dy
		var pad_w: float = bp.get("width", 160.0)

		cur_x += dx
		cur_y += dy

		var sim = Validator.simulate_flight(dx, dy, pad_w)

		pads.append({
			"idx": idx,
			"x": cur_x,
			"y": cur_y,
			"dx": dx,
			"dy": dy,
			"width": pad_w,
			"motif": bp.get("motif", ""),
			"pattern": bp.get("pattern", ""),
			"chapter": bp.get("chapter", ""),
			"is_milestone": bp.get("is_milestone", false),
			"fuel": sim.fuel_remaining,
			"ok": sim.ok
		})

	var file = FileAccess.open("res://tests/pad_layout.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(pads, "\t"))
		file.close()
		print("Successfully exported %d pads to res://tests/pad_layout.json" % pads.size())
	else:
		print("Failed to open file for export")
	quit()
