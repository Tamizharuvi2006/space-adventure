extends SceneTree

# ── Macro Silhouette Complete Verification & Audit ────────────────────────────

func _init() -> void:
	print("Verifying Complete Macro Route Profile from WorldGenerator...")
	var WorldGen = load("res://scripts/world_generator.gd")
	var Validator = load("res://scripts/flight_validator.gd")
	var gen = WorldGen.new()

	var cur_x = 0.0
	var cur_y = 480.0
	var min_y = 99999.0
	var max_y = -99999.0
	var min_fuel = 100.0
	var all_reachable = true
	var x_strictly_increasing = true

	print("\n================ FULL 100-PAD MACRO ROUTE ELEVATIONS ================")
	for idx in range(1, 101):
		var bp = gen.get_pad_blueprint(idx, cur_y)
		var dx: float = bp.dx
		var dy: float = bp.dy
		var pad_w = 160.0
		if bp.pattern == "RECOVERY_PAD":
			pad_w = 200.0
		elif bp.get("is_milestone", false) or idx == 100:
			pad_w = 210.0

		if dx <= 0.0:
			x_strictly_increasing = false
			print("❌ ERROR: dx <= 0 on Pad %d" % idx)

		cur_x += dx
		cur_y += dy

		if cur_y < min_y: min_y = cur_y
		if cur_y > max_y: max_y = cur_y

		var sim = Validator.simulate_flight(dx, dy, pad_w)
		if not sim.ok:
			all_reachable = false
			print("❌ REACHABILITY FAILED on Pad %d: dx=%.0f, dy=%.0f, w=%.0f -> %s" % [idx, dx, dy, pad_w, sim.reason])
		else:
			if sim.fuel_remaining < min_fuel:
				min_fuel = sim.fuel_remaining

		print("Pad %3d: X=%8.0f (dx=%+5.0f) | Y=%7.1f (dy=%+6.1f) | Fuel=%4.1f%% | %-20s | %s" % [
			idx, cur_x, dx, cur_y, dy, sim.fuel_remaining, bp.pattern, bp.chapter
		])

	print("\n================ MACRO SILHOUETTE SUMMARY ================")
	print("  • Total Pads                  : 100")
	print("  • X Strictly Increasing       : %s" % str(x_strictly_increasing))
	print("  • Total World Distance (X)    : %.0f px" % cur_x)
	print("  • Highest Altitude (Min Y)    : %.1f px" % min_y)
	print("  • Lowest Depth (Max Y)        : %.1f px" % max_y)
	print("  • Total World Vertical Span   : %.1f px" % (max_y - min_y))
	print("  • All 100 Pads Reachable      : %s" % str(all_reachable))
	print("  • Minimum Fuel Margin         : %.1f%%" % min_fuel)

	quit()
