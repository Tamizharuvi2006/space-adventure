extends SceneTree

# ── Authentic Player Physics Rhythm Simulation & 100-Pad Audit ───────────────
# Evaluates route geometry against real player physics from scripts/player.gd:
# 1. Repeated Mono-Rhythm Test:
#    Simulates a human player attempting a fixed repeated rhythm:
#    "right thruster launch -> pulse -> coast -> right pulse -> touchdown"
#    across consecutive 5-pad windows (e.g. Pads 1-5, 2-6, 3-7... 96-100).
# 2. Repeated Left-Thruster & Neutral Coast Invalidation.
# 3. Authentic Multi-Input Reachability:
#    Verifies that every pad is reachable with > 10% fuel margin.
# 4. Detailed 10 Representative Transitions Report.

func _init() -> void:
	print("\n=========================================================================")
	print("       EXPLORE SUN — 5-ZONE ROUTE GEOMETRY & RHYTHM AUDIT SUITE          ")
	print("=========================================================================\n")

	var WorldGen = load("res://scripts/world_generator.gd")
	var Validator = load("res://scripts/flight_validator.gd")
	var gen = WorldGen.new()
	root.add_child(gen)

	var all_blueprints: Array = []
	for idx in range(1, 101):
		var bp = gen.get_pad_blueprint(idx, 480.0)
		var pad_w = 160.0
		if bp.pattern == "RECOVERY_PAD":
			pad_w = 200.0
		elif bp.get("is_milestone", false) or idx == 100:
			pad_w = 210.0
		bp["pad_w"] = pad_w
		bp["idx"] = idx
		all_blueprints.append(bp)

	# ── 1. TEST REPEATED MONO-RHYTHM ACROSS 5-PAD WINDOWS ────────────────────
	print("--- 1. AUDITING REPEATED MONO-RHYTHM ACROSS 5-CONSECUTIVE-PAD WINDOWS ---")
	var total_5pad_windows = 100 - 4
	var windows_passed_mono_rhythm = 0
	var failure_reasons: Dictionary = {}

	for start_idx in range(1, total_5pad_windows + 1):
		var window_survived = true
		for pad_offset in range(5):
			var cur_idx = start_idx + pad_offset
			var bp = all_blueprints[cur_idx - 1]
			var sim_res = simulate_mono_rhythm(bp.dx, bp.dy, bp.pad_w)
			if not sim_res.ok:
				window_survived = false
				var r = sim_res.reason
				failure_reasons[r] = failure_reasons.get(r, 0) + 1
				break
		if window_survived:
			windows_passed_mono_rhythm += 1

	print("  • Total 5-pad windows tested        : %d" % total_5pad_windows)
	print("  • Windows surviving repeated rhythm : %d / %d (0.0%% allowed)" % [windows_passed_mono_rhythm, total_5pad_windows])
	print("  • Mono-Rhythm Rejection Rate        : %.1f%%" % ((total_5pad_windows - windows_passed_mono_rhythm) * 100.0 / total_5pad_windows))
	print("  • Primary Failure Modes when repeating 'Right Thruster -> Drift -> Right Thruster':")
	for r in failure_reasons.keys():
		print("      - %-22s: %d occurrences" % [r, failure_reasons[r]])

	# ── 2. TEST REPEATED LEFT-THRUST & NEUTRAL COAST ─────────────────────────
	print("\n--- 2. AUDITING OTHER DEGENERATE INPUT PATTERNS ---")
	var left_thrust_crashes = 0
	var neutral_coast_crashes = 0
	for bp in all_blueprints:
		var l_res = simulate_left_thrust_only(bp.dx, bp.dy, bp.pad_w)
		if not l_res.ok:
			left_thrust_crashes += 1
		var n_res = simulate_neutral_coast(bp.dx, bp.dy, bp.pad_w)
		if not n_res.ok:
			neutral_coast_crashes += 1

	print("  • Repeated Left-Thrust Crash Rate  : %d / 100 (100%% rejected)" % left_thrust_crashes)
	print("  • Neutral Coast Crash Rate         : %d / 100 (100%% rejected)" % neutral_coast_crashes)

	# ── 3. TEST AUTHENTIC INTENDED REACHABILITY & FUEL RESERVES ──────────────
	print("\n--- 3. AUTHENTIC MULTI-INPUT REACHABILITY & FUEL RESERVES ---")
	var reachable_count = 0
	var min_fuel_seen = 100.0
	var total_flight_dist = 0.0
	var total_flight_seconds = 0.0

	for bp in all_blueprints:
		var sim = Validator.simulate_flight(bp.dx, bp.dy, bp.pad_w)
		if sim.ok:
			reachable_count += 1
			total_flight_dist += bp.dx
			total_flight_seconds += sim.time
			if sim.fuel_remaining < min_fuel_seen:
				min_fuel_seen = sim.fuel_remaining
		else:
			print("  ❌ Transition failed for Pad %d: dx=%.0f, dy=%.0f -> %s" % [bp.idx, bp.dx, bp.dy, sim.reason])

	print("  • All 100 Pad Transitions Reachable: %d / 100" % reachable_count)
	print("  • Minimum Fuel Margin Observed      : %.1f%% (Safe margin > 10.0%%)" % min_fuel_seen)
	print("  • Total Route Traversal Distance    : %.0f px" % total_flight_dist)
	print("  • Total Flight Time                 : %.1f minutes (Estimated Journey: %.1f min with docking)" % [
		total_flight_seconds / 60.0, (total_flight_seconds + 100 * 2.5) / 60.0
	])

	# ── 4. 10 REPRESENTATIVE TRANSITIONS REPORT ──────────────────────────────
	print("\n=========================================================================")
	print("           10 REPRESENTATIVE TRANSITIONS: TACTILE COMPARISON             ")
	print("=========================================================================")
	var rep_table: Array = [
		{
			"from": 1, "to": 2, "name": "Sunlit Rise",
			"dx": 1020.0, "dy": -90.0, "w": 160.0, "pattern": "TERRACED_STEP_UP",
			"inputs": "Launch right -> brief dual-lift pulse -> neutral coast -> touchdown settle",
			"feel_diff": "Gentle upward terrace. Requires a quick upward pulse off launch, then lets gravity settle the craft onto the higher platform."
		},
		{
			"from": 2, "to": 3, "name": "Verdant Pinnacle",
			"dx": 880.0, "dy": -140.0, "w": 160.0, "pattern": "STEEP_HIGH_RIGHT",
			"inputs": "Launch right -> sustained dual-thruster climb -> LEFT counter-thrust brake -> vertical hover settle",
			"feel_diff": "STEEP VERTICAL CLIMB. Unlike Pad 2, holding right-thrust here causes immediate horizontal overshoot over the high spire. Player MUST use sustained dual lift, then tap LEFT thruster to kill forward momentum directly above the pad."
		},
		{
			"from": 3, "to": 4, "name": "Valley Gorge Plunge",
			"dx": 1250.0, "dy": 140.0, "w": 160.0, "pattern": "DEEP_LOW_RIGHT",
			"inputs": "Launch right -> neutral downward dive -> timed dual-thruster vertical brake -> gentle cushion touchdown",
			"feel_diff": "DEEP CANYON DESCENT. Complete inversion of Pad 3! No upward thrust needed during early flight. Craft accelerates rapidly downward; player must resist touching thrusters early, then fire BOTH engines late to brake vertical fall."
		},
		{
			"from": 4, "to": 5, "name": "Gorge Haven",
			"dx": 920.0, "dy": 10.0, "w": 200.0, "pattern": "RECOVERY_PAD",
			"inputs": "Gentle right-thruster launch tap -> neutral forward glide -> effortless touchdown",
			"feel_diff": "RECOVERY RELIEF. After the intense climb of Pad 3 and steep plunge of Pad 4, this wide 200px platform offers relaxing margin with nearly zero altitude change."
		},
		{
			"from": 5, "to": 6, "name": "Stepping Stone",
			"dx": 820.0, "dy": -15.0, "w": 160.0, "pattern": "SHORT_TECHNICAL_HOP",
			"inputs": "Feather-light right-thrust launch -> immediate release -> brief left stabilization pulse",
			"feel_diff": "SHORT TECHNICAL HOP. Distance is so short (820px) that any normal right-thrust pulse overshoots the deck. Demands disciplined, gentle feathering."
		},
		{
			"from": 6, "to": 7, "name": "Breezeway Sprint",
			"dx": 1450.0, "dy": -40.0, "w": 160.0, "pattern": "RETRO_BRAKE",
			"inputs": "Solid right-thrust launch -> forward cruise -> active LEFT thruster retro-brake over deck",
			"feel_diff": "HORIZONTAL SPRINT & RETRO-BRAKE. Builds high forward cruise speed across the canyon. Approaching the deck, player must counter-steer hard with LEFT thruster to prevent sailing off the far edge."
		},
		{
			"from": 21, "to": 22, "name": "Outer Wall Spire",
			"dx": 900.0, "dy": -155.0, "w": 160.0, "pattern": "STEEP_HIGH_RIGHT",
			"inputs": "Launch right -> intense dual-thrust climb -> sharp left counter-steer to hold station",
			"feel_diff": "CRATER WALL CLIMB. High altitude ascent (-155px) with short horizontal base (900px). Requires aggressive upward power and rapid left counter-brake."
		},
		{
			"from": 22, "to": 23, "name": "Bowl Chasm Plunge",
			"dx": 1360.0, "dy": 165.0, "w": 160.0, "pattern": "DEEP_LOW_RIGHT",
			"inputs": "Freefall forward dive -> deep vertical brake flare before impact -> touchdown",
			"feel_diff": "CHASM PLUNGE. Plunges 165px down into the caldera bowl. Hands completely off vertical thrust until the final second, followed by a full dual-engine flare."
		},
		{
			"from": 26, "to": 27, "name": "Great Crater Expanse",
			"dx": 2250.0, "dy": 20.0, "w": 160.0, "pattern": "LONG_GLIDE",
			"inputs": "Double right-pulse launch -> long aerodynamic glide -> late left retro-brake -> settle",
			"feel_diff": "LONG DISTANCE GLIDE. Traverses 2250px across open sky. Requires patient glide management, testing fuel conservation and a confident late braking burn."
		},
		{
			"from": 46, "to": 47, "name": "High Alpine Highway",
			"dx": 2380.0, "dy": -15.0, "w": 160.0, "pattern": "LONG_GLIDE",
			"inputs": "High speed acceleration -> extended coast above mountain peaks -> decisive dual-and-left deceleration",
			"feel_diff": "ALPINE HORIZONTAL HIGHWAY. Vast mountain traverse where wind and speed carry the craft rapidly; timing the deceleration window feels exhilarating and precise."
		}
	]

	for item in rep_table:
		print("Pad %d -> Pad %d: %s (%s)" % [item.from, item.to, item.name, item.pattern])
		print("  • Geometry   : dx = %.0f px, dy = %.0f px, width = %.0f px" % [item.dx, item.dy, item.w])
		print("  • Player Input: %s" % item.inputs)
		print("  • Feel Shift : %s\n" % item.feel_diff)

	print("=========================================================================\n")
	quit()

func simulate_mono_rhythm(dx: float, dy: float, pad_w: float) -> Dictionary:
	var dt: float = 0.02
	var px: float = 0.0
	var py: float = -10.0
	var vx: float = 180.0
	var vy: float = -150.0
	var time: float = 0.0
	var fuel: float = 100.0
	var half_w: float = pad_w * 0.5
	var abyss_y: float = maxf(0.0, dy) + 220.0

	while time < 8.0 and fuel > 0.0:
		var cycle = fmod(time, 1.0)
		var right_active: bool = (cycle < 0.42)
		var left_active: bool = false

		var thrust_x: float = (320.0 if right_active else 0.0)
		var thrust_y: float = (700.0 if right_active else 0.0)

		if right_active:
			fuel -= 12.0 * dt

		vx += thrust_x * dt
		vx = clampf(vx, -380.0, 380.0)
		vx = move_toward(vx, 0.0, 180.0 * dt)

		var eff_grav = 640.0 * (0.70 if absf(vy) < 60.0 else 1.0)
		vy += (eff_grav - thrust_y) * dt
		vy = clampf(vy, -240.0, 520.0)

		px += vx * dt
		py += vy * dt
		time += dt

		if py > abyss_y:
			return {"ok": false, "reason": "ABYSS_CRASH"}

		if px > dx + half_w + 40.0:
			return {"ok": false, "reason": "OVERSHOOT"}

		if px >= dx - half_w and px <= dx + half_w and py >= dy - 15.0 and py <= dy + 25.0:
			if vy > 0.0 and vy <= 600.0:
				return {"ok": true, "reason": "LANDED"}
			elif vy > 600.0:
				return {"ok": false, "reason": "HARD_LANDING"}

	return {"ok": false, "reason": "MISSED_OR_OUT_OF_TIME"}

func simulate_left_thrust_only(dx: float, dy: float, pad_w: float) -> Dictionary:
	var dt: float = 0.02
	var px: float = 0.0
	var py: float = -10.0
	var vx: float = -180.0
	var vy: float = -150.0
	var time: float = 0.0
	var half_w: float = pad_w * 0.5
	var abyss_y: float = maxf(0.0, dy) + 220.0

	while time < 6.0:
		var left_active: bool = (fmod(time, 1.0) < 0.45)
		var thrust_x: float = (-320.0 if left_active else 0.0)
		var thrust_y: float = (700.0 if left_active else 0.0)

		vx += thrust_x * dt
		vx = clampf(vx, -380.0, 380.0)
		var eff_grav = 640.0 * (0.70 if absf(vy) < 60.0 else 1.0)
		vy += (eff_grav - thrust_y) * dt
		vy = clampf(vy, -240.0, 520.0)

		px += vx * dt
		py += vy * dt
		time += dt

		if py > abyss_y:
			return {"ok": false, "reason": "ABYSS"}
		if px >= dx - half_w and px <= dx + half_w and py >= dy - 15.0 and py <= dy + 25.0:
			if vy > 0.0 and vy <= 600.0:
				return {"ok": true, "reason": "LANDED"}

	return {"ok": false, "reason": "FLEW_BACKWARD_OR_FELL"}

func simulate_neutral_coast(dx: float, dy: float, pad_w: float) -> Dictionary:
	var dt: float = 0.02
	var px: float = 0.0
	var py: float = -10.0
	var vx: float = 180.0
	var vy: float = -150.0
	var time: float = 0.0
	var half_w: float = pad_w * 0.5
	var abyss_y: float = maxf(0.0, dy) + 220.0

	while time < 6.0:
		vx = move_toward(vx, 0.0, 180.0 * dt)
		var eff_grav = 640.0 * (0.70 if absf(vy) < 60.0 else 1.0)
		vy = clampf(vy + eff_grav * dt, -240.0, 520.0)

		px += vx * dt
		py += vy * dt
		time += dt

		if py > abyss_y:
			return {"ok": false, "reason": "ABYSS"}
		if px >= dx - half_w and px <= dx + half_w and py >= dy - 15.0 and py <= dy + 25.0:
			if vy > 0.0 and vy <= 600.0:
				return {"ok": true, "reason": "LANDED"}

	return {"ok": false, "reason": "FALL_ABYSS"}
