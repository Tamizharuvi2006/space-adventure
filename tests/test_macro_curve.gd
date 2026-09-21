extends SceneTree

# ── 20-Scene Landscape Layout Verification ────────────────────────────────────
# Checks:
#   1. X strictly increasing (dx > 0 on all 100 pads)
#   2. All 100 pads reachable (simulator ok = true)
#   3. Minimum fuel margin >= 20%
#   4. No 8-pad window is monotonically ascending or descending in Y
#   5. Prints per-scene summary with local Y range

const SCENE_DEFS: Array = [
	{"name": "Valley Floor",     "start": 1,  "end": 5},
	{"name": "Rising Ridge",     "start": 6,  "end": 10},
	{"name": "Canyon Shelf",     "start": 11, "end": 15},
	{"name": "Valley Crest",     "start": 16, "end": 20},
	{"name": "Crater Rim",       "start": 21, "end": 25},
	{"name": "Outer Crater",     "start": 26, "end": 30},
	{"name": "Deep Basin",       "start": 31, "end": 35},
	{"name": "Far Rim",          "start": 36, "end": 40},
	{"name": "Mountain Base",    "start": 41, "end": 45},
	{"name": "Sheer Ascent",     "start": 46, "end": 50},
	{"name": "Summit+Couloir",   "start": 51, "end": 55},
	{"name": "Mountain Pass",    "start": 56, "end": 60},
	{"name": "Ruined Approach",  "start": 61, "end": 65},
	{"name": "Sunken Forum",     "start": 66, "end": 70},
	{"name": "Monument Field",   "start": 71, "end": 75},
	{"name": "Pyramid Terraces", "start": 76, "end": 80},
	{"name": "Caldera Rim",      "start": 81, "end": 85},
	{"name": "Plasma Valley",    "start": 86, "end": 90},
	{"name": "Core Ascent",      "start": 91, "end": 95},
	{"name": "Solar Core Apex",  "start": 96, "end": 100},
]

func _init() -> void:
	print("Verifying 20-Scene Landscape Layout...")
	var WorldGen = load("res://scripts/world_generator.gd")
	var Validator = load("res://scripts/flight_validator.gd")
	var gen = WorldGen.new()

	var cur_x = 0.0
	var cur_y = 480.0
	var min_y_global = 99999.0
	var max_y_global = -99999.0
	var min_fuel = 100.0
	var all_reachable = true
	var x_strictly_increasing = true

	var pad_ys: Array = []
	var pad_data: Array = []

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
			print("ERROR: dx <= 0 on Pad %d" % idx)

		cur_x += dx
		cur_y += dy

		if cur_y < min_y_global: min_y_global = cur_y
		if cur_y > max_y_global: max_y_global = cur_y

		var sim = Validator.simulate_flight(dx, dy, pad_w)
		if not sim.ok:
			all_reachable = false
			print("FAIL Pad %d: dx=%.0f dy=%.0f -> %s" % [idx, dx, dy, sim.reason])
		else:
			if sim.fuel_remaining < min_fuel:
				min_fuel = sim.fuel_remaining

		pad_ys.append(cur_y)
		pad_data.append({
			"idx": idx, "x": cur_x, "dx": dx,
			"y": cur_y, "dy": dy,
			"fuel": sim.fuel_remaining, "ok": sim.ok,
			"pattern": bp.pattern, "chapter": bp.chapter
		})

	# Per-scene table
	print("\n===== 20-SCENE BREAKDOWN =====")
	print("%-3s %-22s %-7s %-8s %-8s %-8s" % ["Sc", "Scene Name", "Pads", "MinY", "MaxY", "Range"])
	for si in range(SCENE_DEFS.size()):
		var s = SCENE_DEFS[si]
		var sc_min = 99999.0
		var sc_max = -99999.0
		for pi in range(s.start - 1, s.end):
			if pad_ys[pi] < sc_min: sc_min = pad_ys[pi]
			if pad_ys[pi] > sc_max: sc_max = pad_ys[pi]
		print("S%02d %-22s %d–%d   %-8.0f %-8.0f %-8.0f" % [
			si + 1, s.name, s.start, s.end, sc_min, sc_max, sc_max - sc_min
		])

	# Monotonic corridor check
	print("\n===== MONOTONIC 8-PAD WINDOW CHECK =====")
	var monotonic_fail = false
	for start_i in range(0, 93):
		var w = pad_ys.slice(start_i, start_i + 8)
		var asc = true
		var desc = true
		for wi in range(1, w.size()):
			if w[wi] >= w[wi - 1]: asc = false
			if w[wi] <= w[wi - 1]: desc = false
		if asc or desc:
			monotonic_fail = true
			print("WARN: Monotonic %s window Pads %d-%d" % [
				"ASC" if asc else "DESC", start_i + 1, start_i + 8
			])
	if not monotonic_fail:
		print("OK: No monotonic 8-pad corridor found.")

	# Full pad listing
	print("\n===== FULL 100-PAD ROUTE =====")
	for d in pad_data:
		print("%s Pad %3d X=%7.0f dx=%+5.0f | Y=%7.1f dy=%+6.1f | Fuel=%4.1f%% | %s | %s" % [
			"OK" if d.ok else "XX",
			d.idx, d.x, d.dx, d.y, d.dy, d.fuel, d.pattern, d.chapter
		])

	# Summary
	print("\n===== SUMMARY =====")
	print("X Strictly Increasing : %s" % str(x_strictly_increasing))
	print("All 100 Reachable     : %s" % str(all_reachable))
	print("Min Fuel Margin       : %.1f%%" % min_fuel)
	print("World Vertical Span   : %.0fpx  (Y %.0f to %.0f)" % [
		max_y_global - min_y_global, min_y_global, max_y_global
	])
	print("Monotonic Fail        : %s" % str(monotonic_fail))

	var all_pass = x_strictly_increasing and all_reachable and min_fuel >= 20.0 and not monotonic_fail
	print("\n%s" % ("ALL CHECKS PASSED" if all_pass else "CHECKS FAILED - see above"))
	quit()

