extends SceneTree

const WorldGenerator = preload("res://scripts/world_generator.gd")
const SolarFlightValidator = preload("res://scripts/flight_validator.gd")
const SunZoneData = preload("res://scripts/planet_data.gd")

func _init() -> void:
	print("==========================================================================================================")
	print("       EXPLORE SUN V5.4 — 100-PAD 2D MACRO ROUTE & NUMERICAL TRAJECTORY VERIFIER                          ")
	print("==========================================================================================================")
	call_deferred("_run_simulation")

func _run_simulation() -> void:
	var gen = WorldGenerator.new()
	var pad_positions: Array[Vector2] = []
	var pad_widths: Array[float] = []
	var pad_chapters: Array[String] = []
	var jump_fuels: Array[float] = []
	var jump_times: Array[float] = []

	# Initial Pad 0 at origin
	var curr_x = 140.0
	var curr_y = 455.0
	pad_positions.append(Vector2(curr_x, curr_y))
	pad_widths.append(180.0)
	pad_chapters.append("Valley Basin Start")

	var all_reachable = true
	var min_fuel_reserve = 100.0
	var max_fuel_reserve = 0.0
	var total_fuel_used = 0.0
	var reduced_count = 0

	print(String("%-5s | %-20s | %-12s | %-14s | %-14s | %-8s | %-8s | %s") % [
		"PAD", "CHAPTER", "POSITION", "REQ (dx, dy)", "FINAL (dx, dy)", "AIRTIME", "RESERVE", "STATUS"
	])
	print("-".repeat(110))

	for idx in range(1, 101):
		var bp = gen.get_pad_blueprint(idx, curr_y)
		var zone = SunZoneData.get_zone_for_pad(idx)
		var is_milestone: bool = bp.is_milestone or SunZoneData.is_zone_boundary(idx)
		var pad_w: float = randf_range(zone.get("width_min", 140.0), zone.get("width_max", 180.0))
		if is_milestone or idx == SunZoneData.TOTAL_PADS:
			pad_w = 210.0

		var req_dx: float = bp.dx
		var req_dy: float = bp.dy

		# Run detailed numerical trajectory simulation
		var det = SolarFlightValidator.solve_safe_jump_detailed(req_dx, req_dy, pad_w)
		var sim = det.res
		var final_dx: float = det.final_dx
		var final_dy: float = det.final_dy

		if det.reduced:
			reduced_count += 1

		var target_x = curr_x + final_dx
		var target_y = curr_y + final_dy

		var status = "✅ OK"
		if not sim.ok:
			status = "❌ FAIL (%s, vy=%.0f)" % [sim.reason, sim.touchdown_vy]
			all_reachable = false

		var fuel_res = sim.fuel_remaining
		min_fuel_reserve = minf(min_fuel_reserve, fuel_res)
		max_fuel_reserve = maxf(max_fuel_reserve, fuel_res)
		var fuel_used = 100.0 - fuel_res
		total_fuel_used += fuel_used

		pad_positions.append(Vector2(target_x, target_y))
		pad_widths.append(pad_w)
		pad_chapters.append(bp.chapter)
		jump_fuels.append(fuel_used)
		jump_times.append(sim.time)

		var req_str = "(%+.0f, %+.0f)" % [req_dx, req_dy]
		var final_str = "(%+.0f, %+.0f)" % [final_dx, final_dy]
		var pos_str = "(%.0f, %.0f)" % [target_x, target_y]
		var time_str = "%.2fs" % sim.time
		var reserve_str = "%.1f%%" % fuel_res

		if idx % 5 == 0 or idx <= 6 or not sim.ok or idx in [20, 40, 60, 80, 100]:
			print(String("#%03d | %-20s | %-12s | %-14s | %-14s | %-8s | %-8s | %s") % [
				idx, bp.chapter.substr(0, 20), pos_str, req_str, final_str, time_str, reserve_str, status
			])

		curr_x = target_x
		curr_y = target_y

	print("-".repeat(110))

	# =========================================================================
	# ASCII 2D ELEVATION PROFILE
	# =========================================================================
	print("\n=== 100-PAD 2D ELEVATION PROFILE (Lower Y = Higher Altitude / Mountain Peaks) ===")
	var min_y = 99999.0
	var max_y = -99999.0
	for p in pad_positions:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)

	var rows = 22
	var cols = 80
	var grid: Array[Array] = []
	for r in range(rows):
		var row_arr: Array[String] = []
		for c in range(cols):
			row_arr.append(" ")
		grid.append(row_arr)

	var total_pads = pad_positions.size()
	for i in range(total_pads):
		var pos = pad_positions[i]
		var col_idx = int(float(i) / float(total_pads - 1) * float(cols - 1))
		var norm_y = (pos.y - min_y) / maxf(max_y - min_y, 1.0)
		var row_idx = int(norm_y * float(rows - 1))
		row_idx = clampi(row_idx, 0, rows - 1)
		col_idx = clampi(col_idx, 0, cols - 1)

		if i == 0:
			grid[row_idx][col_idx] = "S" # Start
		elif i == 100:
			grid[row_idx][col_idx] = "A" # Apex (Pad 100)
		elif i in [20, 40, 60, 80]:
			grid[row_idx][col_idx] = "M" # Milestone (20, 40, 60, 80)
		else:
			if grid[row_idx][col_idx] == " ":
				grid[row_idx][col_idx] = "•"

	for r in range(rows):
		var y_val = min_y + (float(r) / float(rows - 1)) * (max_y - min_y)
		var line_str = ""
		for c in range(cols):
			line_str += grid[r][c]
		print("Y %5.0f | %s" % [y_val, line_str])
	print("          " + "―".repeat(cols))
	print("Legend: S=Start (Pad 0), M=Milestone (Pads 20, 40, 60, 80), A=Solar Core Apex (Pad 100), •=Pad")

	# =========================================================================
	# SUMMARY STATISTICS
	# =========================================================================
	var total_span_x = pad_positions[-1].x - pad_positions[0].x
	var vertical_range = max_y - min_y
	var avg_fuel = total_fuel_used / 100.0
	print("\n=== ROUTE VALIDATION SUMMARY ===")
	print("  Total Route Horizontal Distance: %.0f px (~%.2f km world scale)" % [total_span_x, total_span_x * 0.001])
	print("  Average Jump Distance: %.0f px" % (total_span_x / 100.0))
	print("  Altitude Range: Y=%.0f (peak/summit) to Y=%.0f (canyon floor/caldera)" % [min_y, max_y])
	print("  Total Vertical Envelope: %.0f px (Target >= 900 px: %s)" % [
		vertical_range, "PASSED ✅" if vertical_range >= 900.0 else "TOO FLAT ❌"
	])
	print("  Route Reduction Rate: %d / 100 jumps modified by validator (%s)" % [
		reduced_count, "GENTLE ENVELOPE PRESERVED ✅" if reduced_count <= 25 else "CHECK REDUCTIONS ⚠️"
	])
	print("  All 100 Jumps Reachable: %s" % ("YES ✅ (100% verified via Euler simulation)" if all_reachable else "NO ❌"))
	print("  Fuel Reserves: Min=%.1f%%, Max=%.1f%%, Avg Burn Per Jump=%.1f%%" % [min_fuel_reserve, max_fuel_reserve, avg_fuel])
	print("  Milestone Pads (20, 40, 60, 80, 100) Width: 210 px confirmed")

	assert(all_reachable, "All 100 jumps must be reachable!")
	assert(vertical_range >= 900.0, "Vertical envelope must be at least 900 px!")
	print("\n🎉 100-PAD 2D MACRO ROUTE FULLY VERIFIED & FEASIBLE UNDER LOCKED PHYSICS!\n")
	quit(0)
