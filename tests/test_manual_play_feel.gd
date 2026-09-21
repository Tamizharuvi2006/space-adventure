extends SceneTree

# ── Manual-Play Feel & Cross-Transition Rhythm Independence Audit ────────────
# Specifically tests Pads 1 to 10:
# For each transition N (from Pad N to Pad N+1):
# 1. Finds the natural human input sequence (Right, Dual, Left, Coast timings).
# 2. Cross-tests: Takes the input sequence that comfortably lands Transition N,
#    and applies it directly to Transition N+1.
# 3. If Transition N+1 could be cleared with the SAME input rhythm as Transition N,
#    flags it as "FEELS TOO SIMILAR" so pad geometry can be differentiated!

func _init() -> void:
	print("\n=========================================================================")
	print("       MANUAL-PLAY FEEL AUDIT: PADS 1 TO 10 TRANSITION DIVERSITY         ")
	print("=========================================================================\n")

	var WorldGen = load("res://scripts/world_generator.gd")
	var gen = WorldGen.new()
	root.add_child(gen)

	var transitions: Array = []
	for idx in range(1, 11):
		var bp = gen.get_pad_blueprint(idx, 480.0)
		var pad_w = 160.0
		if bp.pattern == "RECOVERY_PAD":
			pad_w = 200.0
		elif bp.get("is_milestone", false) or idx == 10:
			pad_w = 210.0
		bp["pad_w"] = pad_w
		bp["idx"] = idx
		transitions.append(bp)

	var successful_profiles: Array = []

	print("--- 1. SOLVING INTENDED NATURAL INPUT TIMINGS FOR PADS 1–10 ---")
	for i in range(transitions.size()):
		var bp = transitions[i]
		var from_idx = i
		var to_idx = i + 1
		var profile = solve_human_control_profile(bp.dx, bp.dy, bp.pad_w)
		successful_profiles.append(profile)

		print("Transition %d -> %d: %s (%s)" % [from_idx, to_idx, bp.chapter, bp.pattern])
		print("  • Geometry   : dx = %.0f px, dy = %.0f px, width = %.0f px" % [bp.dx, bp.dy, bp.pad_w])
		print("  • Natural Input Sequence:")
		print("      - Launch impulse : %s" % profile.launch_desc)
		print("      - Mid-flight     : %s" % profile.mid_desc)
		print("      - Approach/Brake : %s" % profile.approach_desc)
		print("  • Touchdown  : t=%.2fs | Fuel Rem: %.1f%% | Land Speed: %.1f px/s\n" % [
			profile.time, profile.fuel, profile.landing_vy
		])

	print("\n--- 2. CROSS-TRANSITION RHYTHM INDEPENDENCE TEST ---")
	print("Testing whether Transition N's input rhythm can comfortably land Transition N+1:\n")

	var identical_rhythm_count = 0
	for i in range(transitions.size() - 1):
		var cur_bp = transitions[i]
		var next_bp = transitions[i + 1]
		var cur_profile = successful_profiles[i]

		# Apply Transition i's inputs to Transition i+1
		var cross_test_res = execute_fixed_profile(cur_profile, next_bp.dx, next_bp.dy, next_bp.pad_w)

		var from_a = i
		var to_a = i + 1
		var from_b = i + 1
		var to_b = i + 2

		if cross_test_res.ok:
			print("  ⚠️  WARNING: Transition %d->%d rhythm ALSO CLEARS Transition %d->%d! (FEELS TOO SIMILAR)" % [
				from_a, to_a, from_b, to_b
			])
			identical_rhythm_count += 1
		else:
			print("  ✅ DISTINCT: Transition %d->%d rhythm FAILS on Transition %d->%d -> %s" % [
				from_a, to_a, from_b, to_b, cross_test_res.reason
			])

	print("\n-------------------------------------------------------------------------")
	if identical_rhythm_count == 0:
		print("RESULT: 100% DISTINCT! Zero consecutive transitions share the same input rhythm.")
		print("Every transition across Pads 1–10 demands an unmistakable physical shift in player hands.")
	else:
		print("RESULT: %d transition pairs share rhythm and require differentiation." % identical_rhythm_count)
	print("=========================================================================\n")
	quit()

func solve_human_control_profile(dx: float, dy: float, pad_w: float) -> Dictionary:
	var dt: float = 0.02
	var px = 0.0; var py = -10.0; var vx = 180.0; var vy = -150.0
	var fuel = 100.0; var time = 0.0
	var half_w = pad_w * 0.5

	var target_speed_x = clampf(dx / 7.0, 200.0, 320.0)
	var arc_apex_height = 40.0 + maxf(-dy * 0.25, 0.0)
	if dy > 40.0:
		arc_apex_height = clampf(40.0 - dy * 0.20, 15.0, 40.0)

	var recorded_inputs: Array = []

	var right_thrust_time = 0.0
	var left_thrust_time = 0.0
	var dual_thrust_time = 0.0
	var coast_time = 0.0

	while time < 20.0 and fuel > 0.0:
		var dist_rem = dx - px
		var over_deck = (px >= dx - half_w * 0.75 and px <= dx + half_w * 0.75)
		var brake_dist = maxf(vx * vx / (2.0 * (320.0 + 180.0)) + 60.0, 100.0)
		var want_brake = (dist_rem <= brake_dist and vx > 30.0) or (over_deck and vx > 15.0) or (px > dx)
		var want_accel = (dist_rem > brake_dist and vx < target_speed_x and not over_deck)

		var progress = clampf(px / maxf(dx, 1.0), 0.0, 1.0)
		var target_y = dy * progress - arc_apex_height * (1.0 - pow(progress * 2.0 - 1.0, 2.0))

		var need_lift = (py > target_y or vy > 40.0)
		var urgent_lift = (vy > 200.0 or py > target_y + 80.0)

		if over_deck and py >= dy - 65.0:
			need_lift = (vy > 100.0)
			urgent_lift = (vy > 180.0)

		var left_active = false
		var right_active = false

		if urgent_lift:
			left_active = true
			right_active = true
			if want_brake and vy < 80.0:
				right_active = false
			elif want_accel and vy < 120.0:
				left_active = false
		elif need_lift:
			if want_brake:
				left_active = true
			elif want_accel:
				right_active = true
			else:
				if int(time * 15.0) % 2 == 0:
					right_active = true
				else:
					left_active = true
		else:
			if want_brake and vx > 50.0:
				left_active = true
			elif want_accel and vx < target_speed_x * 0.8:
				right_active = true

		# Record action
		if left_active and right_active:
			dual_thrust_time += dt
		elif left_active:
			left_thrust_time += dt
		elif right_active:
			right_thrust_time += dt
		else:
			coast_time += dt

		recorded_inputs.append({"l": left_active, "r": right_active})

		var thrust_x = 0.0
		var thrust_y = 0.0
		if left_active and right_active:
			thrust_x = 0.0
			if vy <= 0.0:
				thrust_y = 700.0 * 1.4
			else:
				var target_landing_descent_speed = 60.0
				if vy > target_landing_descent_speed:
					var excess_vy = vy - target_landing_descent_speed
					thrust_y = clampf(640.0 + excess_vy * 3.5, 0.0, 1800.0)
				else:
					thrust_y = 640.0 * clampf(vy / target_landing_descent_speed, 0.0, 1.0)
		elif left_active:
			thrust_x -= 320.0
			thrust_y += 700.0
		elif right_active:
			thrust_x += 320.0
			thrust_y += 700.0

		var height_above_target = dy - py
		if vy <= 0.0 and height_above_target > 220.0:
			var excess_h = height_above_target - 220.0
			var ceiling_attenuation = clampf(1.0 - (excess_h / 140.0), 0.35, 1.0)
			thrust_y *= ceiling_attenuation

		var thruster_count = (1.0 if left_active else 0.0) + (1.0 if right_active else 0.0)
		fuel = maxf(0.0, fuel - (12.0 * thruster_count * dt))

		var net_accel_x = thrust_x
		if absf(net_accel_x) > 0.01:
			vx += net_accel_x * dt
		else:
			vx = move_toward(vx, 0.0, 180.0 * dt)
		vx = clampf(vx, -380.0, 380.0)

		var eff_gravity = 640.0
		if absf(vy) < 60.0:
			eff_gravity = 640.0 * 0.70
		vy += (eff_gravity - thrust_y) * dt
		vy = clampf(vy, -240.0, 520.0)

		px += vx * dt
		py += vy * dt
		time += dt

		if px >= dx - half_w and px <= dx + half_w and py >= dy - 15.0 and py <= dy + 25.0:
			if vy > 0.0 and vy <= 600.0:
				var launch_desc = "Right Launch (vx=180, vy=-150)"
				var mid_desc = "Right: %.1fs | Coast: %.1fs | Dual: %.1fs" % [right_thrust_time, coast_time, dual_thrust_time]
				var app_desc = "Left Counter-Brake: %.2fs | Flare: %.2fs" % [left_thrust_time, dual_thrust_time * 0.4]
				if dy > 60.0:
					app_desc = "Descent Flare Brake: %.2fs | Gentle Settle" % dual_thrust_time
				elif dy < -60.0:
					mid_desc = "Sustained Climb Lift: %.1fs | Left Drift Brake: %.2fs" % [dual_thrust_time + right_thrust_time, left_thrust_time]
				elif dx < 900.0:
					mid_desc = "Short Hop Feathering: Right %.1fs | Coast %.1fs" % [right_thrust_time, coast_time]
					app_desc = "Immediate Left Micro-Stabilize: %.2fs" % left_thrust_time
				elif dx > 2000.0:
					mid_desc = "Extended High-Speed Cruise: Right %.1fs | Long Glide %.1fs" % [right_thrust_time, coast_time]
					app_desc = "Aggressive Left Retro-Brake: %.2fs | Dual Flare" % left_thrust_time

				return {
					"ok": true,
					"time": time,
					"fuel": fuel,
					"landing_vy": vy,
					"inputs": recorded_inputs,
					"launch_desc": launch_desc,
					"mid_desc": mid_desc,
					"approach_desc": app_desc
				}

	return {"ok": false, "inputs": []}

func execute_fixed_profile(profile: Dictionary, target_dx: float, target_dy: float, pad_w: float) -> Dictionary:
	var dt: float = 0.02
	var px = 0.0; var py = -10.0; var vx = 180.0; var vy = -150.0
	var time = 0.0
	var half_w = pad_w * 0.5
	var abyss_y = maxf(0.0, target_dy) + 240.0

	var recorded = profile.inputs
	var n_steps = recorded.size()

	for step in range(n_steps + 100): # Allow up to 2 seconds of settling after replay
		var left_active = false
		var right_active = false
		if step < n_steps:
			left_active = recorded[step].l
			right_active = recorded[step].r

		var thrust_x = 0.0
		var thrust_y = 0.0
		if left_active and right_active:
			thrust_x = 0.0
			if vy <= 0.0:
				thrust_y = 700.0 * 1.4
			else:
				var target_landing_descent_speed = 60.0
				if vy > target_landing_descent_speed:
					var excess_vy = vy - target_landing_descent_speed
					thrust_y = clampf(640.0 + excess_vy * 3.5, 0.0, 1800.0)
				else:
					thrust_y = 640.0 * clampf(vy / target_landing_descent_speed, 0.0, 1.0)
		elif left_active:
			thrust_x -= 320.0
			thrust_y += 700.0
		elif right_active:
			thrust_x += 320.0
			thrust_y += 700.0

		var net_accel_x = thrust_x
		if absf(net_accel_x) > 0.01:
			vx += net_accel_x * dt
		else:
			vx = move_toward(vx, 0.0, 180.0 * dt)
		vx = clampf(vx, -380.0, 380.0)

		var eff_gravity = 640.0
		if absf(vy) < 60.0:
			eff_gravity = 640.0 * 0.70
		vy += (eff_gravity - thrust_y) * dt
		vy = clampf(vy, -240.0, 520.0)

		px += vx * dt
		py += vy * dt
		time += dt

		if py > abyss_y:
			return {"ok": false, "reason": "CRASHED INTO ABYSS / GROUND"}
		if px > target_dx + half_w + 30.0:
			return {"ok": false, "reason": "OVERSHOT PLATFORM"}

		if px >= target_dx - half_w and px <= target_dx + half_w and py >= target_dy - 15.0 and py <= target_dy + 25.0:
			if vy > 0.0 and vy <= 600.0:
				return {"ok": true, "reason": "LANDED"}
			elif vy > 600.0:
				return {"ok": false, "reason": "CRASHED - HARD LANDING"}

	if px < target_dx - half_w:
		return {"ok": false, "reason": "UNDERSHOT PLATFORM (Fell short)"}

	return {"ok": false, "reason": "MISSED TOUCHDOWN WINDOW"}
