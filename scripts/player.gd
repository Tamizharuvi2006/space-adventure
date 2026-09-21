extends CharacterBody2D
class_name SolarPlayer

signal landed_safely(platform: Node2D, is_perfect: bool)
signal crashed(reason: String)
signal fuel_changed(current: float, max_val: float)

enum State { ON_PAD, FLYING, LANDED, CRASHED }

# Physics parameters - Mars: Mars Dual-Thruster Flight Model
@export var gravity: float = 640.0
@export var max_fall_speed: float = 520.0
@export var max_upward_speed: float = -240.0

@export var launch_vertical_boost: float = -150.0
@export var launch_horizontal_boost: float = 180.0

# Dual Thruster Authority
@export var single_thruster_vertical: float = 700.0   # 700 overcomes baseline gravity 640 (+60 net climb per thruster)
@export var single_thruster_horizontal: float = 320.0 # Meaningful sideways travel without launching across screen
@export var max_horizontal_speed: float = 380.0
@export var horizontal_drag: float = 180.0

@export var max_tilt_angle_deg: float = 20.0
@export var tilt_lerp_speed: float = 12.0

@export var max_fuel: float = 100.0
@export var fuel_burn_rate: float = 12.0 # Burn rate per active thruster
@export var max_safe_landing_speed: float = 600.0 # Forgiving touchdown
@export var max_safe_angle_deg: float = 52.0

# Stratosphere Soft Limit
@export var soft_altitude_threshold: float = 350.0 
@export var restoring_force: float = 150.0
@export var max_restoring_force: float = 250.0

var current_state: State = State.ON_PAD
var fuel: float = 100.0
var active_platform: Node2D = null
var last_docked_platform: Node2D = null
var target_platform_ref: Node2D = null

# Telemetry for tuning and debug
var telemetry_height_above_target: float = 0.0
var telemetry_restoring_force: float = 0.0
var telemetry_thrust_x: float = 0.0
var telemetry_thrust_y: float = 0.0

# Timers for state safety
var launch_grace_timer: float = 0.0
var landing_grace_timer: float = 0.0

# Dual thruster input tracking
var mobile_left_active: bool = false
var mobile_right_active: bool = false
var was_thruster_active_last_frame: bool = false

# Active Environmental Modifiers (configured per planet destination)
var active_gravity: float = 640.0
var active_wind_x: float = 0.0
var active_updraft_y: float = 0.0

@onready var left_particles: CPUParticles2D = $LeftJet
@onready var right_particles: CPUParticles2D = $RightJet
@onready var sprite_node: Node2D = $Visuals
@onready var crash_particles: CPUParticles2D = $CrashParticles
@onready var sound_manager: Node = get_node_or_null("/root/SoundManager")

@onready var left_leg: Node2D = get_node_or_null("Visuals/LeftLeg")
@onready var right_leg: Node2D = get_node_or_null("Visuals/RightLeg")
@onready var left_arm: Node2D = get_node_or_null("Visuals/LeftArm")
@onready var right_arm: Node2D = get_node_or_null("Visuals/RightArm")
@onready var head_node: Node2D = get_node_or_null("Visuals/Head")
@onready var torso_node: Node2D = get_node_or_null("Visuals/Torso")
@onready var backpack_node: Node2D = get_node_or_null("Visuals/Backpack")

var astronaut_anim_time: float = 0.0
var launch_kick_timer: float = 0.0
var landing_squash_timer: float = 0.0
var idle_time_on_pad: float = 0.0

func _ready() -> void:
	fuel = max_fuel
	active_gravity = gravity
	emit_signal("fuel_changed", fuel, max_fuel)
	_update_particles(false, false)

func spawn_on_platform(platform: Node2D) -> void:
	active_platform = platform
	last_docked_platform = platform
	global_position = platform.get_landing_position()
	velocity = Vector2.ZERO
	rotation = 0.0
	launch_grace_timer = 0.0
	landing_grace_timer = 0.2
	launch_kick_timer = 0.0
	landing_squash_timer = 0.0
	idle_time_on_pad = 0.0
	fuel = max_fuel
	current_state = State.ON_PAD
	_update_particles(false, false)
	sprite_node.visible = true
	emit_signal("fuel_changed", fuel, max_fuel)
	print("[PHYSICS] Spawned player on %s at %s" % [platform.name, global_position])

var is_control_enabled: bool = true

func set_control_enabled(enabled: bool) -> void:
	is_control_enabled = enabled
	if not enabled:
		mobile_left_active = false
		mobile_right_active = false
		_update_particles(false, false)
		if sound_manager: sound_manager.play_thruster(false)

func set_mobile_inputs(steer_l: bool, steer_r: bool, _legacy_boost: bool = false) -> void:
	mobile_left_active = steer_l
	mobile_right_active = steer_r

func set_target_platform(platform: Node2D) -> void:
	target_platform_ref = platform

func set_environmental_modifiers(g: float, wind: float, updraft: float = 0.0) -> void:
	active_gravity = g
	active_wind_x = wind
	active_updraft_y = updraft
	print("[PLAYER] Environment modifiers: Grav=%.0f, Wind=%.0f, Updraft=%.0f" % [active_gravity, active_wind_x, active_updraft_y])

func _physics_process(delta: float) -> void:
	if not is_control_enabled or current_state == State.CRASHED:
		_update_particles(false, false)
		if sound_manager: sound_manager.play_thruster(false)
		return
		
	if launch_grace_timer > 0.0:
		launch_grace_timer = maxf(0.0, launch_grace_timer - delta)
	if landing_grace_timer > 0.0:
		landing_grace_timer = maxf(0.0, landing_grace_timer - delta)

	# 1. Inputs: Desktop (A/D/Left/Right + Q/E + W/Up/Space for both thrusters) + Mobile
	var key_l = Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_Q)
	var key_r = Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_E)
	var key_thrust = Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
	
	var want_left = key_l or key_thrust or mobile_left_active
	var want_right = key_r or key_thrust or mobile_right_active
	
	var can_fire = fuel > 0.0
	var left_active = want_left and can_fire
	var right_active = want_right and can_fire
	var any_thruster_active = left_active or right_active
	
	var thruster_just_activated = any_thruster_active and not was_thruster_active_last_frame
	
	# Launch sequence off platform:
	# Undocks immediately when a thruster becomes active, or if held after landing grace period
	if (current_state == State.ON_PAD or current_state == State.LANDED):
		if thruster_just_activated or (any_thruster_active and landing_grace_timer <= 0.0):
			current_state = State.FLYING
			last_docked_platform = active_platform
			active_platform = null
			launch_grace_timer = 0.25
			launch_kick_timer = 0.35
			idle_time_on_pad = 0.0
			global_position.y -= 6.0
			velocity.y = launch_vertical_boost
			if left_active and right_active:
				velocity.x = 0.0
			elif left_active:
				velocity.x = -launch_horizontal_boost
			elif right_active:
				velocity.x = launch_horizontal_boost
			print("[PHYSICS] Launched off pad: vel=%s" % velocity)
			
	# Fuel consumption: each active thruster burns fuel
	if current_state == State.FLYING and can_fire:
		var thruster_count = 0.0
		if left_active: thruster_count += 1.0
		if right_active: thruster_count += 1.0
		if thruster_count > 0.0:
			fuel = maxf(0.0, fuel - (fuel_burn_rate * thruster_count * delta))
			emit_signal("fuel_changed", fuel, max_fuel)
			if fuel <= 0.0 and sound_manager:
				sound_manager.play_warning()
			
	# Jet particles and thruster sound
	_update_particles(left_active, right_active)
	if sound_manager:
		sound_manager.play_thruster(any_thruster_active)
		
	# DOCKED ON PAD: Anchor cleanly, zero velocity, remain completely stationary while no input
	if current_state == State.ON_PAD or current_state == State.LANDED:
		velocity = Vector2.ZERO
		rotation = 0.0
		telemetry_thrust_x = 0.0
		telemetry_thrust_y = 0.0
		if is_instance_valid(active_platform):
			global_position = active_platform.get_landing_position()
		was_thruster_active_last_frame = any_thruster_active

	# Flight dynamics
	if current_state == State.FLYING:
		var target_y = 480.0
		if is_instance_valid(target_platform_ref):
			target_y = target_platform_ref.global_position.y
		elif is_instance_valid(last_docked_platform):
			target_y = last_docked_platform.global_position.y

		var height_above_target = target_y - global_position.y
		telemetry_height_above_target = height_above_target

		# Dual-Thruster Force Calculation
		var thrust_x = 0.0
		var thrust_y = 0.0
		
		if left_active and right_active:
			# BOTH ENGINES ACTIVE: Two rocket engines working together (Straight UP or Landing Brake)
			thrust_x = 0.0
			if velocity.y <= 0.0:
				# ASCENDING: Controlled upward propulsion (700 * 1.4 = 980.0 px/s² vs baseline gravity 640.0, net +340 px/s²)
				thrust_y = single_thruster_vertical * 1.4
			else:
				# DESCENDING / LANDING BRAKE: Velocity-aware counter-thrust
				var target_landing_descent_speed = 60.0 # Safe gentle touchdown speed (40..100 px/s)
				if velocity.y > target_landing_descent_speed:
					var excess_vy = velocity.y - target_landing_descent_speed
					# Stronger braking for faster descent, gentler braking for slower descent
					var brake_decel = excess_vy * 3.5
					thrust_y = clampf((active_gravity + active_updraft_y) + brake_decel, 0.0, 1800.0)
				else:
					# Near or below landing speed: scale thrust with downward velocity so it NEVER exceeds gravity (NO UPWARD BOUNCE / HOVER LOCK)
					thrust_y = (active_gravity + active_updraft_y) * clampf(velocity.y / target_landing_descent_speed, 0.0, 1.0)
		elif left_active:
			# LEFT ONLY: Diagonal UP + LEFT (↖) — 700 upward overcomes 640 gravity for climb recovery
			thrust_x -= single_thruster_horizontal
			thrust_y += single_thruster_vertical
		elif right_active:
			# RIGHT ONLY: Diagonal UP + RIGHT (↗) — 700 upward overcomes 640 gravity for climb recovery
			thrust_x += single_thruster_horizontal
			thrust_y += single_thruster_vertical
			
		# Gentle power attenuation for upward ascent when approaching the upper gameplay corridor (>220px above target)
		if velocity.y <= 0.0 and height_above_target > 220.0:
			var excess_h = height_above_target - 220.0
			var ceiling_attenuation = clampf(1.0 - (excess_h / 140.0), 0.35, 1.0)
			thrust_y *= ceiling_attenuation

		telemetry_thrust_x = thrust_x
		telemetry_thrust_y = thrust_y

		telemetry_restoring_force = 0.0

		# 1. HORIZONTAL PHYSICS (Natural thruster force + Planetary Crosswind)
		var net_accel_x = thrust_x + active_wind_x
		if absf(net_accel_x) > 0.01:
			velocity.x += net_accel_x * delta
		else:
			velocity.x = move_toward(velocity.x, 0.0, horizontal_drag * delta)
			
		velocity.x = clampf(velocity.x, -max_horizontal_speed, max_horizontal_speed)
		
		# 2. VERTICAL PHYSICS (Active Planetary Gravity + Updrafts vs Combined Thruster Lift)
		var eff_gravity = active_gravity
		if absf(velocity.y) < 60.0:
			eff_gravity = active_gravity * 0.70 # Natural apex float
			
		velocity.y += (eff_gravity + active_updraft_y) * delta
		velocity.y -= thrust_y * delta
		velocity.y = clampf(velocity.y, max_upward_speed, max_fall_speed)
		
		# 3. BANK TILT ANGLE
		var target_bank_deg = 0.0
		if left_active and right_active:
			target_bank_deg = 0.0
		elif left_active:
			target_bank_deg = -max_tilt_angle_deg
		elif right_active:
			target_bank_deg = max_tilt_angle_deg
		else:
			target_bank_deg = (velocity.x / max_horizontal_speed) * (max_tilt_angle_deg * 0.5)
			
		rotation = lerp_angle(rotation, deg_to_rad(target_bank_deg), tilt_lerp_speed * delta)
		
		# Physical Movement
		var pre_move_vy = velocity.y
		move_and_slide()
		
		# 1. Authoritative Platform Collision Evaluation (Evaluated FIRST)
		_evaluate_physical_collisions(pre_move_vy)
		
		# 2. Dynamic Abyss Death Check (Evaluated only if no safe touchdown occurred)
		if current_state == State.FLYING:
			var pad_ref_y = target_y
			if is_instance_valid(last_docked_platform):
				pad_ref_y = maxf(target_y, last_docked_platform.global_position.y)
			var abyss_limit_y = pad_ref_y + 190.0
			if global_position.y > abyss_limit_y:
				print("[PHYSICS] DEATH TRIGGERED: Fell below flight boundary into solar void (y=%.1f vs limit=%.1f)" % [global_position.y, abyss_limit_y])
				trigger_death("Lost in the Solar Void")
				return
		was_thruster_active_last_frame = any_thruster_active
	
	_update_astronaut_pose(delta)

func _update_astronaut_pose(delta: float) -> void:
	if not is_instance_valid(sprite_node):
		return

	astronaut_anim_time += delta

	# Landing squash / bounce recovery — neutral scale is 1.5 (set in player.tscn)
	sprite_node.scale.y = lerpf(sprite_node.scale.y, 1.5, 10.0 * delta)
	sprite_node.scale.x = lerpf(sprite_node.scale.x, 1.5, 10.0 * delta)

	if current_state == State.ON_PAD or current_state == State.LANDED:
		# ── DOCKED / IDLE ASTRONAUT POSE ──────────────────────────────────────
		idle_time_on_pad += delta
		var breath := sin(astronaut_anim_time * 2.8) * 1.1
		var slow_sway := sin(astronaut_anim_time * 1.4) * 0.045
		
		# Torso gently rises and falls with breathing
		var target_torso_y := breath * 0.85
		var target_head_y := breath * 0.70
		var target_head_rot := sin(astronaut_anim_time * 1.1) * 0.035
		var target_arm_l_rot := slow_sway + sin(astronaut_anim_time * 2.8) * 0.03
		var target_arm_r_rot := -slow_sway - sin(astronaut_anim_time * 2.8 + 0.3) * 0.03
		var target_arm_l_pos := Vector2(0.0, breath * 0.60)
		var target_arm_r_pos := Vector2(0.0, breath * 0.60)
		var target_leg_l_rot := sin(astronaut_anim_time * 1.2) * 0.012
		var target_leg_r_rot := -sin(astronaut_anim_time * 1.2) * 0.012

		# Touchdown landing knee flex recovery
		if landing_squash_timer > 0.0:
			landing_squash_timer = maxf(0.0, landing_squash_timer - delta)
			var shock := landing_squash_timer / 0.35
			target_leg_l_rot -= shock * 0.16
			target_leg_r_rot += shock * 0.16
			target_torso_y += shock * 2.2
			target_head_y += shock * 2.0
			target_arm_l_rot += shock * 0.25
			target_arm_r_rot -= shock * 0.25

		# Natural Idle Fidgets (Wrist computer check / Visor adjust)
		var fidget_cycle := fmod(idle_time_on_pad, 12.0)
		if landing_squash_timer <= 0.0:
			if fidget_cycle > 3.8 and fidget_cycle < 6.8:
				# Wrist Communicator Check: left arm raises to chest, head tilts down to look
				var p := sin((fidget_cycle - 3.8) / 3.0 * PI)
				target_arm_l_rot = lerpf(target_arm_l_rot, -0.62, p)
				target_arm_l_pos = target_arm_l_pos.lerp(Vector2(2.5, -3.0), p)
				target_head_rot = lerpf(target_head_rot, -0.18, p)
			elif fidget_cycle > 8.5 and fidget_cycle < 11.2:
				# Visor / Helmet Adjustment: right hand raises to helmet side
				var p := sin((fidget_cycle - 8.5) / 2.7 * PI)
				target_arm_r_rot = lerpf(target_arm_r_rot, 0.55, p)
				target_arm_r_pos = target_arm_r_pos.lerp(Vector2(-2.0, -3.5), p)
				target_head_rot = lerpf(target_head_rot, 0.12, p)

		if is_instance_valid(torso_node):
			torso_node.position.y = lerpf(torso_node.position.y, target_torso_y, 10.0 * delta)
		if is_instance_valid(head_node):
			head_node.position.y = lerpf(head_node.position.y, target_head_y, 10.0 * delta)
			head_node.rotation = lerp_angle(head_node.rotation, target_head_rot, 7.0 * delta)
		if is_instance_valid(backpack_node):
			backpack_node.position.y = lerpf(backpack_node.position.y, target_torso_y * 0.7, 10.0 * delta)

		if is_instance_valid(left_arm):
			left_arm.rotation = lerp_angle(left_arm.rotation, target_arm_l_rot, 8.0 * delta)
			left_arm.position = left_arm.position.lerp(target_arm_l_pos, 8.0 * delta)
		if is_instance_valid(right_arm):
			right_arm.rotation = lerp_angle(right_arm.rotation, target_arm_r_rot, 8.0 * delta)
			right_arm.position = right_arm.position.lerp(target_arm_r_pos, 8.0 * delta)

		# Legs stay planted firmly on platform deck with organic tension
		if is_instance_valid(left_leg):
			left_leg.rotation = lerp_angle(left_leg.rotation, target_leg_l_rot, 10.0 * delta)
			left_leg.position = Vector2.ZERO
		if is_instance_valid(right_leg):
			right_leg.rotation = lerp_angle(right_leg.rotation, target_leg_r_rot, 10.0 * delta)
			right_leg.position = Vector2.ZERO

	elif current_state == State.FLYING:
		# ── IN-FLIGHT DYNAMIC ASTRONAUT POSE ──────────────────────────────────
		idle_time_on_pad = 0.0
		var horiz_factor := clampf(-velocity.x / 400.0 * 0.35, -0.42, 0.42)
		var vert_factor := clampf(velocity.y / 500.0, -1.0, 1.0)
		
		# Atmospheric & thruster wash flutter (micro-turbulence)
		var flutter_speed := 6.5
		var arm_flutter := sin(astronaut_anim_time * flutter_speed) * 0.04
		var leg_wave_l := sin(astronaut_anim_time * flutter_speed) * 0.09
		var leg_wave_r := sin(astronaut_anim_time * flutter_speed + 2.2) * 0.09

		# Active thruster throttle gripping on arms
		var steer_arm_l := 0.0
		var steer_arm_r := 0.0
		var arm_offset_l := Vector2.ZERO
		var arm_offset_r := Vector2.ZERO

		if mobile_left_active and mobile_right_active:
			steer_arm_l = -0.24
			steer_arm_r = 0.24
			arm_offset_l = Vector2(-1.5, 1.5)
			arm_offset_r = Vector2(1.5, 1.5)
		elif mobile_left_active:
			steer_arm_l = -0.32
			arm_offset_l = Vector2(-2.2, 1.8)
		elif mobile_right_active:
			steer_arm_r = 0.32
			arm_offset_r = Vector2(2.2, 1.8)

		# Vertical reach/brace: reaching slightly up during ascent, extending down for landing
		var arm_vert_reach := -vert_factor * 0.12

		if is_instance_valid(left_arm):
			var target_arm_l = horiz_factor + steer_arm_l + arm_vert_reach + arm_flutter
			left_arm.rotation = lerp_angle(left_arm.rotation, target_arm_l, 11.0 * delta)
			left_arm.position = left_arm.position.lerp(arm_offset_l + Vector2(0.0, -vert_factor * 1.2), 9.0 * delta)
		if is_instance_valid(right_arm):
			var target_arm_r = horiz_factor + steer_arm_r + arm_vert_reach - arm_flutter
			right_arm.rotation = lerp_angle(right_arm.rotation, target_arm_r, 11.0 * delta)
			right_arm.position = right_arm.position.lerp(arm_offset_r + Vector2(0.0, -vert_factor * 1.2), 9.0 * delta)

		# Legs: Spacewalk floating, climb tucking, landing extension, and launch kick
		var leg_tuck := 0.0
		var launch_kick_rot := 0.0
		if launch_kick_timer > 0.0:
			launch_kick_timer = maxf(0.0, launch_kick_timer - delta)
			var kp := launch_kick_timer / 0.35
			launch_kick_rot = -kp * 0.38
			leg_tuck = -kp * 3.5
		elif velocity.y < -50.0:
			leg_tuck = -2.8 # Knees tucked during steep climb
		elif velocity.y > 50.0:
			leg_tuck = 2.0  # Legs extended ready for landing

		if is_instance_valid(left_leg):
			var target_leg_l = horiz_factor - 0.05 + leg_wave_l + launch_kick_rot
			left_leg.rotation = lerp_angle(left_leg.rotation, target_leg_l, 10.0 * delta)
			left_leg.position.y = lerpf(left_leg.position.y, leg_tuck, 9.0 * delta)
		if is_instance_valid(right_leg):
			var target_leg_r = horiz_factor + 0.05 + leg_wave_r + (launch_kick_rot * 0.85)
			right_leg.rotation = lerp_angle(right_leg.rotation, target_leg_r, 10.0 * delta)
			right_leg.position.y = lerpf(right_leg.position.y, leg_tuck * 0.85, 9.0 * delta)

		# Torso & Head respond to flight speed & direction
		if is_instance_valid(torso_node):
			var torso_lean = clampf(velocity.x / 400.0 * 0.08, -0.10, 0.10)
			torso_node.rotation = lerp_angle(torso_node.rotation, torso_lean, 8.0 * delta)
			torso_node.position.y = lerpf(torso_node.position.y, -vert_factor * 0.8, 8.0 * delta)
		if is_instance_valid(head_node):
			var look_ahead := clampf(velocity.x / 350.0 * 0.16, -0.20, 0.20)
			head_node.rotation = lerp_angle(head_node.rotation, look_ahead + sin(astronaut_anim_time * 3.0) * 0.02, 9.0 * delta)
			head_node.position.y = lerpf(head_node.position.y, -vert_factor * 1.0, 8.0 * delta)
		if is_instance_valid(backpack_node):
			backpack_node.position.y = lerpf(backpack_node.position.y, 0.0, 8.0 * delta)

func _evaluate_physical_collisions(impact_vy: float) -> void:
	if current_state != State.FLYING:
		return

	var slide_count = get_slide_collision_count()
	if slide_count == 0:
		return

	# ─── PASS 1: Valid Landing Pad Deck Touchdown (Highest Priority) ──────────
	# Any valid landing pad touchdown always takes precedence over terrain hazards.
	for i in range(slide_count):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		var normal = collision.get_normal()

		var is_platform = false
		if collider:
			if collider.is_in_group("platform") or collider.has_method("is_landing_pad"):
				is_platform = true

		if is_platform:
			# Normal pointing UP (normal.y < -0.55) indicates landing on the top deck!
			if normal.y < -0.55:
				_process_platform_touchdown(collider as Node2D, collision.get_position(), impact_vy)
				if current_state == State.ON_PAD:
					return # Confirmed safe landing!
				elif current_state == State.CRASHED:
					return # Landing failed due to extreme impact speed or tilt crash

	# ─── PASS 2: Terrain Hazard / Obstacle Collision (Instant Crash Death) ────
	# If no safe pad landing occurred, any contact with terrain, rock silhouettes,
	# cliff faces, or non-pad obstacles triggers immediate death.
	for i in range(slide_count):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		var normal = collision.get_normal()

		var is_platform = false
		if collider:
			if collider.is_in_group("platform") or collider.has_method("is_landing_pad"):
				is_platform = true

		if is_platform:
			# Platform contact that was NOT a top deck landing (e.g. side impact or bottom)
			if collider == last_docked_platform and launch_grace_timer > 0.0:
				continue # launch_grace_timer protects ONLY the launch pad itself during takeoff
			if absf(velocity.x) > 380.0 and absf(normal.x) > 0.6:
				velocity = Vector2.ZERO
				print("[PHYSICS] DEATH TRIGGERED: Platform side impact crash (vx=%.0f)" % velocity.x)
				trigger_death("Platform Crash! (Speed: %d px/s)" % int(absf(velocity.x)))
				return
		else:
			# Non-platform collider: Terrain bedrock, cliffs, mountain faces, canyon walls
			# Terrain contact is deadly AT ALL TIMES, even during launch_grace_timer!
			velocity = Vector2.ZERO
			print("[PHYSICS] DEATH TRIGGERED: Terrain contact with %s at %s" % [
				collider.name if collider else "terrain", collision.get_position()
			])
			trigger_death("Crashed into Terrain!")
			return

func test_touchdown(platform: Node2D, hit_pos: Vector2) -> void:
	if current_state != State.FLYING:
		return
	_process_platform_touchdown(platform, hit_pos, velocity.y)

func _process_platform_touchdown(platform: Node2D, hit_pos: Vector2, impact_vy: float) -> void:
	if platform == last_docked_platform and launch_grace_timer > 0.0:
		return # Cannot re-dock on the platform we just launched from during launch grace period
		
	var angle_deg = absf(rad_to_deg(rotation))
	print("[PHYSICS] COLLISION: player -> platform %s (impact_vy=%.1f, angle=%.1f°)" % [
		platform.name, impact_vy, angle_deg
	])
	
	# Only genuinely catastrophic downward impacts kill
	if impact_vy > max_safe_landing_speed:
		velocity = Vector2.ZERO
		print("[PHYSICS] DEATH TRIGGERED: Catastrophic impact speed (vy=%.1f)" % impact_vy)
		trigger_death("Hard Impact! (Speed: %d px/s)" % int(impact_vy))
		return
		
	if angle_deg > max_safe_angle_deg:
		velocity = Vector2.ZERO
		print("[PHYSICS] DEATH TRIGGERED: Severe tilt crash (angle=%.1f°)" % angle_deg)
		trigger_death("Tilted Landing! (Angle: %d°)" % int(angle_deg))
		return
		
	# LANDING CONFIRMED!
	print("[PHYSICS] LANDING CONFIRMED on %s!" % platform.name)
	current_state = State.ON_PAD
	active_platform = platform
	last_docked_platform = platform
	landing_grace_timer = 0.25 # Protection window
	landing_squash_timer = 0.35 # Shock absorption knee flex
	idle_time_on_pad = 0.0
	was_thruster_active_last_frame = true # Prevent instant launch if holding brake during touchdown
	
	velocity = Vector2.ZERO
	rotation = 0.0
	global_position = platform.get_landing_position()
	if is_instance_valid(sprite_node):
		sprite_node.scale = Vector2(1.62, 1.38) # Squash on touchdown (1.5 * 1.08, 1.5 * 0.92)
	
	fuel = max_fuel
	emit_signal("fuel_changed", fuel, max_fuel)
	_update_particles(false, false)
	if sound_manager: sound_manager.play_thruster(false)
	
	var pad_center_x = platform.global_position.x
	var dist_from_center = absf(hit_pos.x - pad_center_x)
	var is_perfect = dist_from_center < 50.0
	
	emit_signal("landed_safely", platform, is_perfect)

func trigger_death(reason: String) -> void:
	if current_state == State.CRASHED or current_state == State.ON_PAD or current_state == State.LANDED:
		return
		
	current_state = State.CRASHED
	velocity = Vector2.ZERO
	_update_particles(false, false)
	if sound_manager:
		sound_manager.play_thruster(false)
		sound_manager.play_crash()
		
	sprite_node.visible = false
	_spawn_death_burst()
	emit_signal("crashed", reason)

func _spawn_death_burst() -> void:
	if crash_particles:
		crash_particles.restart()
		crash_particles.emitting = true

	# 1. Authentic Reference: Large White Hexagonal Impact Clusters
	var hex_offsets = [
		Vector2(0.0, -18.0),
		Vector2(-20.0, -6.0),
		Vector2(22.0, -10.0),
		Vector2(-14.0, 10.0),
		Vector2(16.0, 8.0)
	]
	var hex_radii = [34.0, 28.0, 30.0, 24.0, 26.0]
	for i in range(hex_offsets.size()):
		var hex = Polygon2D.new()
		hex.name = "WhiteHexImpact_%d" % i
		hex.polygon = _create_hex_polygon(hex_radii[i])
		hex.color = Color(1.0, 1.0, 1.0, 0.98)
		hex.position = hex_offsets[i]
		hex.rotation = float(i) * 0.4
		add_child(hex)
		
		var ht = create_tween().set_parallel(true)
		ht.tween_property(hex, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ht.tween_property(hex, "scale", Vector2(0.2, 0.2), 0.26).set_delay(0.12)
		ht.tween_property(hex, "modulate:a", 0.0, 0.26).set_delay(0.12)
		ht.chain().tween_callback(hex.queue_free)

	# 2. Authentic Reference: Tumbling Astronaut Helmet/Pod Shard
	var helmet = Node2D.new()
	helmet.name = "TumblingHelmet"
	var helmet_hull = Polygon2D.new()
	helmet_hull.polygon = _create_hex_polygon(13.0)
	helmet_hull.color = Color(0.92, 0.94, 0.98, 1.0)
	helmet.add_child(helmet_hull)
	
	var visor = Polygon2D.new()
	visor.polygon = PackedVector2Array([Vector2(-6, -4), Vector2(6, -4), Vector2(5, 4), Vector2(-5, 4)])
	visor.color = Color(1.0, 0.75, 0.15, 1.0)
	helmet.add_child(visor)
	helmet.position = Vector2(0.0, -10.0)
	add_child(helmet)
	
	var helmet_tween = create_tween().set_parallel(true)
	helmet_tween.tween_property(helmet, "position", Vector2(75.0, -35.0), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	helmet_tween.tween_property(helmet, "rotation", 4.2, 0.38)
	helmet_tween.chain().tween_property(helmet, "position:y", 25.0, 0.22)
	helmet_tween.parallel().tween_property(helmet, "modulate:a", 0.0, 0.22)
	helmet_tween.chain().tween_callback(helmet.queue_free)

	# 3. Authentic Reference: Dense Upward-Fanning Multicolored Confetti Spray
	var confetti_palette = [
		Color(1.0, 0.18, 0.65, 1.0), # Neon Magenta
		Color(0.12, 0.90, 1.0, 1.0),  # Electric Cyan
		Color(1.0, 0.95, 0.10, 1.0),  # Bright Sun Yellow
		Color(0.20, 0.98, 0.35, 1.0), # Lime Green
		Color(1.0, 0.45, 0.05, 1.0),  # Sunset Orange
		Color(0.72, 0.25, 1.0, 1.0),  # Deep Royal Purple
		Color(1.0, 1.0, 1.0, 1.0)     # Pure White
	]
	
	for col in confetti_palette:
		var emitter = CPUParticles2D.new()
		emitter.name = "ConfettiPlume"
		emitter.emitting = false
		emitter.one_shot = true
		emitter.explosiveness = 0.95
		emitter.amount = 26
		emitter.lifetime = 0.58
		emitter.direction = Vector2(0.0, -1.0)
		emitter.spread = 70.0
		emitter.gravity = Vector2(0.0, 480.0)
		emitter.initial_velocity_min = 240.0
		emitter.initial_velocity_max = 520.0
		emitter.scale_amount_min = 3.5
		emitter.scale_amount_max = 7.0
		emitter.color = col
		add_child(emitter)
		emitter.restart()
		emitter.emitting = true
		
		var clean_e = create_tween()
		clean_e.tween_interval(0.65)
		clean_e.tween_callback(emitter.queue_free)

	# 4. Outward Diagonal Speed Rays (Left, Right, Center Plumes)
	var ray_angles = [Vector2(-0.85, -0.52), Vector2(0.85, -0.52), Vector2(0.0, -1.0)]
	for dir in ray_angles:
		var ray = CPUParticles2D.new()
		ray.name = "SpeedRay"
		ray.emitting = false
		ray.one_shot = true
		ray.explosiveness = 0.98
		ray.amount = 14
		ray.lifetime = 0.45
		ray.direction = dir
		ray.spread = 18.0
		ray.gravity = Vector2(0.0, 200.0)
		ray.initial_velocity_min = 380.0
		ray.initial_velocity_max = 580.0
		ray.scale_amount_min = 4.0
		ray.scale_amount_max = 8.0
		ray.color = Color(1.0, 0.95, 0.7, 1.0)
		add_child(ray)
		ray.restart()
		ray.emitting = true
		
		var clean_r = create_tween()
		clean_r.tween_interval(0.55)
		clean_r.tween_callback(ray.queue_free)

static func _create_hex_polygon(radius: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(6):
		var a = (float(i) / 6.0) * TAU - (PI / 6.0)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts

func _update_particles(left_on: bool, right_on: bool) -> void:
	if left_particles:
		left_particles.emitting = left_on
	if right_particles:
		right_particles.emitting = right_on

func set_left_thrust(active: bool) -> void:
	mobile_left_active = active

func set_right_thrust(active: bool) -> void:
	mobile_right_active = active
