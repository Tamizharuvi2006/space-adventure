extends CharacterBody2D
class_name SolarPlayer

signal landed_safely(platform: Node2D, is_perfect: bool)
signal crashed(reason: String)
signal fuel_changed(current: float, max_val: float)

enum State { ON_PAD, FLYING, LANDED, CRASHED }

# Physics parameters - Mars: Mars Dual-Thruster Flight Model
@export var gravity: float = 640.0
@export var max_fall_speed: float = 520.0
@export var max_upward_speed: float = -420.0

@export var launch_vertical_boost: float = -320.0
@export var launch_horizontal_boost: float = 180.0

# Dual Thruster Authority
@export var single_thruster_vertical: float = 460.0   # Combined = 920 vs gravity 640
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

# Timers for state safety
var launch_grace_timer: float = 0.0
var landing_grace_timer: float = 0.0

# Dual thruster input tracking
var mobile_left_active: bool = false
var mobile_right_active: bool = false

# Active Environmental Modifiers (configured per planet destination)
var active_gravity: float = 640.0
var active_wind_x: float = 0.0
var active_updraft_y: float = 0.0

@onready var left_particles: CPUParticles2D = $LeftJet
@onready var right_particles: CPUParticles2D = $RightJet
@onready var sprite_node: Node2D = $Visuals
@onready var crash_particles: CPUParticles2D = $CrashParticles
@onready var sound_manager: Node = get_node_or_null("/root/SoundManager")

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

	# 1. Inputs: Desktop (A/D/Left/Right + Space shortcut for desktop testing) + Mobile
	var key_l = Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	var key_r = Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
	var key_space = Input.is_key_pressed(KEY_SPACE) # Desktop testing shortcut: fires both thrusters
	
	var want_left = key_l or key_space or mobile_left_active
	var want_right = key_r or key_space or mobile_right_active
	
	var can_fire = fuel > 0.0
	var left_active = want_left and can_fire
	var right_active = want_right and can_fire
	var any_thruster_active = left_active or right_active
	
	# Launch sequence off platform
	if any_thruster_active and (current_state == State.ON_PAD or current_state == State.LANDED):
		current_state = State.FLYING
		last_docked_platform = active_platform
		active_platform = null
		launch_grace_timer = 0.25
		global_position.y -= 10.0
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
		
	# If landed or docked on a moving/swaying platform, anchor cleanly to its position
	if (current_state == State.ON_PAD or current_state == State.LANDED) and is_instance_valid(active_platform):
		global_position = active_platform.get_landing_position()
		velocity = Vector2.ZERO

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
		
		if left_active:
			thrust_x -= single_thruster_horizontal
			thrust_y += single_thruster_vertical
			
		if right_active:
			thrust_x += single_thruster_horizontal
			thrust_y += single_thruster_vertical
			
		# Gentle power attenuation only at extreme heights (>480px above target)
		if height_above_target > 480.0:
			var excess_h = height_above_target - 480.0
			var ceiling_attenuation = clampf(1.0 - (excess_h / 200.0), 0.2, 1.0)
			thrust_y *= ceiling_attenuation

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

func _evaluate_physical_collisions(impact_vy: float) -> void:
	if current_state != State.FLYING:
		return
		
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		var normal = collision.get_normal()
		
		var is_platform = false
		if collider:
			if collider.is_in_group("platform") or collider.has_method("is_landing_pad"):
				is_platform = true
				
		if is_platform:
			# Normal pointing UP means landing on the top surface of a platform!
			if normal.y < -0.55:
				_process_platform_touchdown(collider as Node2D, collision.get_position(), impact_vy)
				return
			else:
				# Side impact with platform
				if absf(velocity.x) > 380.0 and absf(normal.x) > 0.6:
					print("[PHYSICS] DEATH TRIGGERED: Platform side impact crash (vx=%.0f)" % velocity.x)
					trigger_death("Platform Crash! (Speed: %d px/s)" % int(absf(velocity.x)))
					return
		else:
			# Collided with anything other than a landing pad deck (e.g. non-pad terrain, decorative structure)
			if landing_grace_timer <= 0.0 and launch_grace_timer <= 0.0:
				print("[PHYSICS] DEATH TRIGGERED: Collided with non-pad surface: %s" % (collider.name if collider else "unknown"))
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
		print("[PHYSICS] DEATH TRIGGERED: Catastrophic impact speed (vy=%.1f)" % impact_vy)
		trigger_death("Hard Impact! (Speed: %d px/s)" % int(impact_vy))
		return
		
	if angle_deg > max_safe_angle_deg:
		print("[PHYSICS] DEATH TRIGGERED: Severe tilt crash (angle=%.1f°)" % angle_deg)
		trigger_death("Tilted Landing! (Angle: %d°)" % int(angle_deg))
		return
		
	# LANDING CONFIRMED!
	print("[PHYSICS] LANDING CONFIRMED on %s!" % platform.name)
	current_state = State.ON_PAD
	active_platform = platform
	last_docked_platform = platform
	landing_grace_timer = 0.25 # Protection window
	
	velocity = Vector2.ZERO
	rotation = 0.0
	global_position = platform.get_landing_position()
	
	fuel = max_fuel
	emit_signal("fuel_changed", fuel, max_fuel)
	_update_particles(false, false)
	if sound_manager: sound_manager.play_thruster(false)
	
	var pad_center_x = platform.global_position.x
	var dist_from_center = absf(hit_pos.x - pad_center_x)
	var is_perfect = dist_from_center < 50.0
	
	emit_signal("landed_safely", platform, is_perfect)

func trigger_death(reason: String) -> void:
	if current_state == State.CRASHED or landing_grace_timer > 0.0:
		return
		
	current_state = State.CRASHED
	_update_particles(false, false)
	if sound_manager:
		sound_manager.play_thruster(false)
		sound_manager.play_crash()
		
	sprite_node.visible = false
	crash_particles.restart()
	crash_particles.emitting = true
	emit_signal("crashed", reason)

func _update_particles(left_on: bool, right_on: bool) -> void:
	if left_particles:
		left_particles.emitting = left_on
	if right_particles:
		right_particles.emitting = right_on

func set_left_thrust(active: bool) -> void:
	mobile_left_active = active

func set_right_thrust(active: bool) -> void:
	mobile_right_active = active
