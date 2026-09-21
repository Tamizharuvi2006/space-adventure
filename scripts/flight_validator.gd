extends RefCounted
class_name SolarFlightValidator

## Numerical Flight Trajectory Simulator & Reachability Solver for Explore Sun
## Faithfully mirrors scripts/player.gd physics:
## - Baseline gravity: 640.0 px/s² with 0.70x apex float when |vy| < 60.0 px/s
## - Single thruster vertical: 700.0 px/s² (+60 net climb per thruster)
## - Single thruster horizontal: 320.0 px/s²
## - Speeds: max_horizontal_speed = 380.0, max_upward = -240.0, max_fall = 520.0
## - Takeoff impulse: launch_vertical_boost = -150.0, launch_horizontal_boost = 180.0, y -= 10.0
## - Fuel capacity: 100.0, burn rate = 12.0/s per active thruster
## - Soft stratosphere threshold: 350.0 px above target

const GRAVITY: float = 640.0
const LAUNCH_HORIZONTAL_BOOST: float = 180.0
const LAUNCH_VERTICAL_BOOST: float = -150.0
const THRUST_VERTICAL: float = 700.0
const THRUST_HORIZONTAL: float = 320.0
const MAX_HORIZONTAL_SPEED: float = 380.0
const HORIZONTAL_DRAG: float = 180.0
const FUEL_BURN_RATE: float = 12.0
const MAX_FALL_SPEED: float = 520.0
const MAX_UPWARD_SPEED: float = -240.0
const MAX_SAFE_LANDING_SPEED: float = 600.0
const HARD_FUEL_FLOOR: float = 10.0

static func simulate_flight(dx: float, dy: float, pad_width: float = 160.0, active_wind: float = 0.0, _active_updraft: float = 0.0) -> Dictionary:
	var dt: float = 0.02
	var max_sim_time: float = maxf(18.0, dx / 100.0 + 8.0)

	# 1. Starting state: exact reproduction of player.gd takeoff off platform
	var px: float = 0.0
	var py: float = -10.0 # Liftoff clearance from player.gd: global_position.y -= 10.0
	var vx: float = LAUNCH_HORIZONTAL_BOOST
	var vy: float = LAUNCH_VERTICAL_BOOST
	var fuel: float = 100.0
	var time: float = 0.0

	var half_w: float = pad_width * 0.5
	# Target cruise speed scaled to jump distance
	var target_speed_x: float = clampf(dx / 7.0, 200.0, 320.0)
	if dy > 80.0:
		target_speed_x = clampf(dx / 8.0, 180.0, 280.0)

	var floor_ref_y: float = maxf(0.0, dy)
	var abyss_death_y: float = floor_ref_y + 280.0

	while time < max_sim_time and fuel > 0.0:
		var dist_rem: float = dx - px
		var over_deck: bool = (px >= dx - half_w * 0.75 and px <= dx + half_w * 0.75)

		# Dynamic braking distance
		var brake_dist: float = maxf(vx * vx / (2.0 * (THRUST_HORIZONTAL + HORIZONTAL_DRAG)) + 60.0, 90.0)
		var want_brake: bool = (dist_rem <= brake_dist and vx > 30.0) or (over_deck and vx > 15.0) or (px > dx)
		var want_accel: bool = (dist_rem > brake_dist and vx < target_speed_x and not over_deck)

		# Parabolic altitude guidance from (0,0) to (dx, dy)
		var progress: float = clampf(px / maxf(dx, 1.0), 0.0, 1.0)
		var arc_apex_height: float = 80.0 + maxf(-dy * 0.35, 0.0)
		var target_y: float = dy * progress - arc_apex_height * (1.0 - pow(progress * 2.0 - 1.0, 2.0))

		var need_lift: bool = (py > target_y or vy > 120.0)
		var urgent_lift: bool = (vy > 200.0 or py > target_y + 45.0)

		if over_deck and py >= dy - 65.0:
			# Close to landing deck: let gentle gravity settle the craft onto the pad
			need_lift = (vy > 220.0)
			urgent_lift = (vy > 320.0)

		var left_active: bool = false
		var right_active: bool = false

		if urgent_lift:
			left_active = true
			right_active = true
			if want_brake:
				right_active = false
			elif want_accel and vy < 60.0:
				left_active = false
		elif need_lift:
			if want_brake:
				left_active = true # Lifts with 700, brakes with 320
			elif want_accel:
				right_active = true # Lifts with 700, accelerates with 320
			else:
				# Alternate single thruster pulse to maintain altitude economically
				if int(time * 15.0) % 2 == 0:
					right_active = true
				else:
					left_active = true
		else:
			if want_brake and vx > 50.0:
				left_active = true
			elif want_accel and vx < target_speed_x * 0.8:
				right_active = true

		# Dual thruster force calculation
		var thrust_x: float = 0.0
		var thrust_y: float = 0.0
		if left_active:
			thrust_x -= THRUST_HORIZONTAL
			thrust_y += THRUST_VERTICAL
		if right_active:
			thrust_x += THRUST_HORIZONTAL
			thrust_y += THRUST_VERTICAL

		# Stratosphere ceiling attenuation (soft limit)
		var height_above_target: float = dy - py
		if height_above_target > 350.0:
			var excess_h: float = height_above_target - 350.0
			var ceiling_attenuation: float = clampf(1.0 - (excess_h / 200.0), 0.2, 1.0)
			thrust_y *= ceiling_attenuation

		# Fuel burn
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

		# 2. Vertical Physics (Apex float vs Thruster Lift)
		var eff_gravity: float = GRAVITY
		if absf(vy) < 60.0:
			eff_gravity = GRAVITY * 0.70 # Natural apex float from player.gd

		vy += (eff_gravity - thrust_y) * dt
		vy = clampf(vy, MAX_UPWARD_SPEED, MAX_FALL_SPEED)

		px += vx * dt
		py += vy * dt
		time += dt

		# Abyss check
		if py > abyss_death_y:
			return {
				"ok": false,
				"reason": "ABYSS",
				"time": time,
				"fuel_remaining": fuel,
				"landing_speed": vy,
				"landing_x": px
			}

		# Touchdown zone check
		if px >= dx - half_w and px <= dx + half_w and py >= dy - 15.0 and py <= dy + 25.0:
			if vy > 0.0 and vy <= MAX_SAFE_LANDING_SPEED:
				if fuel >= HARD_FUEL_FLOOR:
					return {
						"ok": true,
						"reason": "OK",
						"time": time,
						"fuel_remaining": fuel,
						"landing_speed": vy,
						"landing_x": px
					}
				else:
					return {
						"ok": false,
						"reason": "LOW_FUEL",
						"time": time,
						"fuel_remaining": fuel,
						"landing_speed": vy,
						"landing_x": px
					}
			elif vy > MAX_SAFE_LANDING_SPEED:
				return {
					"ok": false,
					"reason": "HARD_LANDING",
					"time": time,
					"fuel_remaining": fuel,
					"landing_speed": vy,
					"landing_x": px
				}

	return {
		"ok": false,
		"reason": "OUT_OF_FUEL_OR_TIME",
		"time": time,
		"fuel_remaining": fuel,
		"landing_speed": vy,
		"landing_x": px
	}

static func solve_safe_jump_detailed(target_dx: float, target_dy: float, pad_width: float = 160.0) -> Dictionary:
	var dx: float = target_dx
	var dy: float = target_dy

	# 1. Test requested jump directly
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

	# 2. Minimal fine adjustment preserving macro geometry if needed
	for attempt in range(1, 10):
		if initial_res.reason == "LOW_FUEL":
			dx = maxf(dx * 0.96, 750.0)
		elif initial_res.reason == "HARD_LANDING":
			if absf(dy) > 50.0:
				dy *= 0.96
			dx = maxf(dx * 0.98, 750.0)
		else:
			dx = maxf(dx * 0.97, 750.0)
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

	# 3. Controlled fallback preserving direction
	var safe_dy = clampf(target_dy * 0.85, -180.0, 240.0)
	var safe_dx = clampf(target_dx * 0.90, 750.0, 2400.0)
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
