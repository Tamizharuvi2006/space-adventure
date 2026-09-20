extends RefCounted
class_name SolarFlightValidator

# ─── Explore Sun V5.3 — Numerical Flight Trajectory Simulator ────────────────
# Exact numerical reproduction of scripts/player.gd physics:
# - Gravity: 640.0 px/s² with 0.70x apex float when |vy| < 60.0 px/s
# - Thrusters: single_thruster_vertical = 460.0, single_thruster_horizontal = 320.0
# - Drag: horizontal_drag = 180.0 px/s² applied via move_toward
# - Speeds: max_horizontal_speed = 380.0, max_upward = -420.0, max_fall = 520.0
# - Takeoff impulse: launch_vertical_boost = -320.0, launch_horizontal_boost = 180.0, y -= 10.0
# - Fuel capacity: 100.0, burn rate = 12.0/s per active thruster
# - Abyss death threshold: py > maxf(0.0, dy) + 260.0
# - Hard Safety Floor: >= 15.0% fuel remaining at touchdown

const GRAVITY: float = 640.0
const LAUNCH_HORIZONTAL_BOOST: float = 180.0
const LAUNCH_VERTICAL_BOOST: float = -320.0
const THRUST_VERTICAL: float = 460.0
const THRUST_HORIZONTAL: float = 320.0
const MAX_HORIZONTAL_SPEED: float = 380.0
const HORIZONTAL_DRAG: float = 180.0
const FUEL_BURN_RATE: float = 12.0
const MAX_FALL_SPEED: float = 520.0
const MAX_UPWARD_SPEED: float = -420.0
const MAX_SAFE_LANDING_SPEED: float = 600.0
const HARD_FUEL_FLOOR: float = 15.0

static func simulate_flight(dx: float, dy: float, pad_width: float = 160.0, active_wind: float = 0.0, active_updraft: float = 0.0) -> Dictionary:
	var dt: float = 0.02
	var max_sim_time: float = 6.5

	# 1. Starting state: exact reproduction of player.gd takeoff off platform
	var px: float = 0.0
	var py: float = -10.0 # Liftoff clearance from player.gd: global_position.y -= 10.0
	var vx: float = LAUNCH_HORIZONTAL_BOOST # Takeoff with forward push
	var vy: float = LAUNCH_VERTICAL_BOOST   # Takeoff vertical pop
	var fuel: float = 100.0
	var time: float = 0.0

	var half_w: float = pad_width * 0.5
	var target_speed_x: float = clampf(dx * 0.42, 220.0, MAX_HORIZONTAL_SPEED)
	if dy > 50.0:
		# In deep descents, match horizontal transit time to vertical gravity settling time
		var est_fall_time: float = clampf(3.2 + dy * 0.002, 3.0, 4.2)
		target_speed_x = clampf(dx / est_fall_time, 200.0, 270.0)

	var floor_ref_y: float = maxf(0.0, dy)
	var abyss_death_y: float = floor_ref_y + 260.0

	while time < max_sim_time and fuel > 0.0:
		var dist_rem: float = dx - px

		# ─── Guidance Controller ──────────────────────────────────────────────
		# Physics-based dynamic braking distance
		var brake_dist: float = maxf(vx * vx / (2.0 * (THRUST_HORIZONTAL + HORIZONTAL_DRAG)) + 45.0, 80.0)
		var over_deck: bool = (px >= dx - half_w * 0.5)
		var want_brake: bool = (dist_rem <= brake_dist and vx > 30.0) or (over_deck and vx > 15.0) or (px > dx)
		var want_accel: bool = (dist_rem > brake_dist and vx < target_speed_x and not over_deck)

		# Parabolic altitude guidance from (0,0) to (dx, dy)
		var progress: float = clampf(px / maxf(dx, 1.0), 0.0, 1.0)
		var arc_apex_height: float = 100.0 + maxf(-dy * 0.40, 0.0)
		var target_y: float = dy * progress - arc_apex_height * (1.0 - pow(progress * 2.0 - 1.0, 2.0))

		var need_lift: bool = (py > target_y or vy > 130.0)
		if over_deck and py >= dy - 60.0 and vy < 350.0:
			# Close to landing deck: let gentle gravity settle the craft onto the pad
			need_lift = (vy > 250.0)

		var left_active: bool = false
		var right_active: bool = false

		if need_lift:
			left_active = true
			right_active = true
			if want_brake:
				right_active = false
			elif want_accel and vy < 80.0:
				left_active = false
		else:
			if want_brake:
				left_active = true
			elif want_accel:
				right_active = true

		# ─── Exact Player.gd Physics Integration ──────────────────────────────
		# Dual thruster force calculation
		var thrust_x: float = 0.0
		var thrust_y: float = 0.0
		if left_active:
			thrust_x -= THRUST_HORIZONTAL
			thrust_y += THRUST_VERTICAL
		if right_active:
			thrust_x += THRUST_HORIZONTAL
			thrust_y += THRUST_VERTICAL

		# Stratosphere ceiling attenuation
		var height_above_target: float = dy - py
		if height_above_target > 480.0:
			var excess_h: float = height_above_target - 480.0
			var ceiling_attenuation: float = clampf(1.0 - (excess_h / 200.0), 0.2, 1.0)
			thrust_y *= ceiling_attenuation

		# Fuel burn: burns for each active thruster
		var thruster_count: float = (1.0 if left_active else 0.0) + (1.0 if right_active else 0.0)
		if thruster_count > 0.0:
			fuel = maxf(0.0, fuel - (FUEL_BURN_RATE * thruster_count * dt))

		# 1. Horizontal Physics
		var net_accel_x: float = thrust_x + active_wind
		if absf(net_accel_x) > 0.01:
			vx += net_accel_x * dt
		else:
			vx = move_toward(vx, 0.0, HORIZONTAL_DRAG * dt)
		vx = clampf(vx, -MAX_HORIZONTAL_SPEED, MAX_HORIZONTAL_SPEED)

		# 2. Vertical Physics (Apex float + Updrafts vs Thruster Lift)
		var eff_gravity: float = GRAVITY
		if absf(vy) < 60.0:
			eff_gravity = GRAVITY * 0.70 # Natural apex float from player.gd

		vy += (eff_gravity + active_updraft) * dt
		vy -= thrust_y * dt
		vy = clampf(vy, MAX_UPWARD_SPEED, MAX_FALL_SPEED)

		# Kinematics step
		px += vx * dt
		py += vy * dt
		time += dt

		# ─── Abyss Death Check ────────────────────────────────────────────────
		if py > abyss_death_y:
			return {
				"ok": false,
				"time": time,
				"fuel_remaining": fuel,
				"touchdown_vy": vy,
				"touchdown_vx": vx,
				"y_err": absf(py - dy),
				"px": px,
				"reason": "ABYSS_DEATH"
			}

		# ─── Touchdown Window on Platform Deck ────────────────────────────────
		if px >= dx - half_w * 0.90 and px <= dx + half_w * 0.90:
			var y_err = absf(py - dy)
			if y_err <= 35.0 or (py >= dy - 15.0 and py <= dy + 35.0):
				var is_safe_landing = (vy <= MAX_SAFE_LANDING_SPEED and absf(vx) <= 300.0 and fuel >= HARD_FUEL_FLOOR)
				return {
					"ok": is_safe_landing,
					"time": time,
					"fuel_remaining": fuel,
					"touchdown_vy": vy,
					"touchdown_vx": vx,
					"y_err": y_err,
					"px": px,
					"reason": "OK" if is_safe_landing else ("LOW_FUEL" if fuel < HARD_FUEL_FLOOR else "HARD_LANDING")
				}
		elif px > dx + half_w:
			return {
				"ok": false,
				"time": time,
				"fuel_remaining": fuel,
				"touchdown_vy": vy,
				"touchdown_vx": vx,
				"y_err": absf(py - dy),
				"px": px,
				"reason": "OVERSHOOT"
			}

	return {
		"ok": false,
		"time": time,
		"fuel_remaining": fuel,
		"touchdown_vy": vy,
		"touchdown_vx": vx,
		"y_err": absf(py - dy),
		"px": px,
		"reason": "OUT_OF_FUEL_OR_TIME"
	}

static func solve_safe_jump_detailed(target_dx: float, target_dy: float, pad_width: float = 160.0) -> Dictionary:
	var dx: float = target_dx
	var dy: float = target_dy

	# 1. Test original requested jump directly
	var initial_res = simulate_flight(dx, dy, pad_width)
	if initial_res.ok:
		return {
			"vector": Vector2(dx, dy),
			"req_dx": target_dx,
			"req_dy": target_dy,
			"final_dx": dx,
			"final_dy": dy,
			"fuel_remaining": initial_res.fuel_remaining,
			"airtime": initial_res.time,
			"reduced": false,
			"res": initial_res
		}

	var best_res = initial_res

	# 2. If unreachable, attempt minimal, gentle adjustments preserving macro geography
	for attempt in range(1, 10):
		if initial_res.reason == "LOW_FUEL":
			# Needs slightly shorter horizontal span
			dx = maxf(dx * 0.96, 680.0)
		elif initial_res.reason == "HARD_LANDING" or initial_res.reason == "OVERSHOOT":
			# Gentle vertical cushion adjustment
			if absf(dy) > 50.0:
				dy *= 0.96
			dx = maxf(dx * 0.98, 680.0)
		else:
			dx = maxf(dx * 0.97, 680.0)
			if absf(dy) > 50.0:
				dy *= 0.97

		var res = simulate_flight(dx, dy, pad_width)
		if res.ok:
			return {
				"vector": Vector2(dx, dy),
				"req_dx": target_dx,
				"req_dy": target_dy,
				"final_dx": dx,
				"final_dy": dy,
				"fuel_remaining": res.fuel_remaining,
				"airtime": res.time,
				"reduced": true,
				"res": res
			}
		best_res = res

	# 3. Controlled fallback preserving the macro direction and majority of vertical displacement
	var safe_dy = clampf(target_dy * 0.82, -220.0, 260.0)
	var safe_dx = clampf(target_dx * 0.92, 680.0, 1150.0)
	var fallback_res = simulate_flight(safe_dx, safe_dy, pad_width)
	return {
		"vector": Vector2(safe_dx, safe_dy),
		"req_dx": target_dx,
		"req_dy": target_dy,
		"final_dx": safe_dx,
		"final_dy": safe_dy,
		"fuel_remaining": fallback_res.fuel_remaining,
		"airtime": fallback_res.time,
		"reduced": true,
		"res": fallback_res
	}

static func solve_safe_jump(target_dx: float, target_dy: float, pad_width: float = 160.0) -> Vector2:
	var det = solve_safe_jump_detailed(target_dx, target_dy, pad_width)
	return det.vector
