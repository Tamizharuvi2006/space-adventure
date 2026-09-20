extends Camera2D
class_name SolarCamera

# ── Explore Sun V6 — Directional Composition Camera (Mars: Mars Style) ──────
# Principles:
# 1. Moving Composition Anchor (DO NOT CENTER THE PLAYER):
#    - Player screen position is determined by movement direction and travel corridor.
#    - Rightward travel: player sits at ~38%–42% of viewport width (more space ahead on right).
#    - Leftward travel: player sits at ~58%–62% of viewport width (more space ahead on left).
# 2. Vertical Dynamic Framing:
#    - Ascending: player sits at ~56%–60% of viewport height (more world/terrain visible above).
#    - Descending: player sits at ~40%–44% of viewport height (landing pad & terrain visible below).
#    - Stationary / Docked: player sits at ~54% of viewport height (grounded bedrock below).
# 3. No Immediate Recentering on Landing:
#    - When landed, camera keeps player naturally offset toward the NEXT platform.
# 4. Moderate Dynamic Zoom (0.92 to 1.00):
#    - Widen view slightly for distant jumps without shrinking the astronaut.
# 5. Continuous World Scroll:
#    - Camera composition anchor moves dynamically, making the world scroll through the screen.

@export var follow_target: Node2D
@export var smooth_speed: float = 5.0

# Current smooth screen fraction (where the player appears on screen as 0.0..1.0)
var current_screen_frac: Vector2 = Vector2(0.40, 0.54)
var target_screen_frac: Vector2 = Vector2(0.40, 0.54)

# Rest vertical offset compatibility
var default_vertical_offset: float = -40.0

var trauma: float = 0.0
var max_angle: float = 0.02
var max_offset: Vector2 = Vector2(8.0, 6.0)

var target_platform: Node2D = null
var is_initialized: bool = false

func _ready() -> void:
	zoom = Vector2.ONE

func _process(delta: float) -> void:
	if not is_instance_valid(follow_target):
		return

	var vp_size = get_viewport_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = Vector2(1280.0, 720.0)

	var p_pos = follow_target.global_position
	var p_vel = Vector2.ZERO
	if "velocity" in follow_target:
		p_vel = follow_target.velocity

	if not is_initialized:
		snap_to_target()
		is_initialized = true

	# ─── 1. Determine Horizontal Travel Direction & Desired Screen Frac ─────
	var travel_dir_x: float = 1.0
	if is_instance_valid(target_platform):
		var dx_to_pad = target_platform.global_position.x - p_pos.x
		if absf(dx_to_pad) > 15.0:
			travel_dir_x = signf(dx_to_pad)
	
	# Flight velocity reinforces or reverses travel direction
	if absf(p_vel.x) > 30.0:
		travel_dir_x = signf(p_vel.x)

	# Base horizontal fraction: 40% when moving right, 60% when moving left
	var desired_x: float = 0.40 if travel_dir_x > 0.0 else 0.60

	# Dynamic velocity lookahead modifies the screen composition:
	# Faster horizontal flight pushes player slightly further back, giving MORE corridor ahead
	var vel_offset_x = clampf(p_vel.x / 500.0, -0.06, 0.06)
	desired_x = clampf(desired_x - vel_offset_x, 0.34, 0.66)

	# ─── 2. Determine Vertical Desired Screen Frac ────────────────────────────
	# Ascent: player at ~57% height (reveal upcoming peaks and terrain above)
	# Descent: player at ~42% height (reveal landing pad and ground below)
	# Stationary/Docked: ~54% height (grounded)
	var desired_y: float = 0.54
	if p_vel.y < -30.0:
		# Ascending
		var climb_t = clampf(-p_vel.y / 300.0, 0.0, 1.0)
		desired_y = lerpf(0.54, 0.60, climb_t)
	elif p_vel.y > 30.0:
		# Descending
		var fall_t = clampf(p_vel.y / 300.0, 0.0, 1.0)
		desired_y = lerpf(0.54, 0.42, fall_t)

	target_screen_frac = Vector2(desired_x, desired_y)

	# Smoothly interpolate the composition anchor
	current_screen_frac.x = lerpf(current_screen_frac.x, target_screen_frac.x, 5.0 * delta)
	current_screen_frac.y = lerpf(current_screen_frac.y, target_screen_frac.y, 5.0 * delta)

	# ─── 3. Moderate Dynamic Zoom ────────────────────────────────────────────
	# Baseline zoom 1.00; for long jumps, gently zoom to ~0.92–0.95
	var dist_to_pad: float = 0.0
	if is_instance_valid(target_platform):
		dist_to_pad = p_pos.distance_to(target_platform.global_position)

	var target_zoom_val: float = 1.0
	if dist_to_pad > 550.0:
		var zoom_t = clampf((dist_to_pad - 550.0) / 750.0, 0.0, 1.0)
		target_zoom_val = lerpf(1.0, 0.92, zoom_t)

	var new_z = lerpf(zoom.x, target_zoom_val, 2.5 * delta)
	zoom = Vector2(new_z, new_z)

	# ─── 4. Compute World Camera Position From Screen Composition Anchor ─────
	# Screen position of player = (player_world - cam_world) * zoom + vp_size * 0.5
	# => cam_world = player_world - (screen_offset_from_center / zoom)
	var screen_offset_from_center = Vector2(
		(current_screen_frac.x - 0.5) * vp_size.x,
		(current_screen_frac.y - 0.5) * vp_size.y
	)

	var target_cam_pos = p_pos - (screen_offset_from_center / zoom)

	# Smooth follow to desired composition
	global_position.x = lerpf(global_position.x, target_cam_pos.x, smooth_speed * delta)
	global_position.y = lerpf(global_position.y, target_cam_pos.y, smooth_speed * delta)

	# ─── 5. Screen Shake Trauma ──────────────────────────────────────────────
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - delta * 2.5)
		var shake_amount = trauma * trauma
		offset.x = randf_range(-1.0, 1.0) * max_offset.x * shake_amount
		offset.y = randf_range(-1.0, 1.0) * max_offset.y * shake_amount
		rotation = randf_range(-1.0, 1.0) * max_angle * shake_amount
	else:
		offset = Vector2.ZERO
		rotation = 0.0

func snap_to_target() -> void:
	if not is_instance_valid(follow_target):
		return
	var vp_size = get_viewport_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = Vector2(1280.0, 720.0)
	
	var travel_dir_x: float = 1.0
	if is_instance_valid(target_platform):
		var dx = target_platform.global_position.x - follow_target.global_position.x
		if absf(dx) > 15.0:
			travel_dir_x = signf(dx)
	
	current_screen_frac = Vector2(0.40 if travel_dir_x > 0.0 else 0.60, 0.54)
	target_screen_frac = current_screen_frac

	var screen_offset_from_center = Vector2(
		(current_screen_frac.x - 0.5) * vp_size.x,
		(current_screen_frac.y - 0.5) * vp_size.y
	)
	global_position = follow_target.global_position - (screen_offset_from_center / zoom)

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func notify_landed(platform: Node2D) -> void:
	add_trauma(0.06)
	# Retain direction bias towards next platform - no recentering
	if is_instance_valid(target_platform) and target_platform != platform:
		var dx = target_platform.global_position.x - platform.global_position.x
		target_screen_frac.x = 0.40 if dx >= 0.0 else 0.60
	target_screen_frac.y = 0.54

func set_next_target_platform(platform: Node2D) -> void:
	target_platform = platform
	if is_instance_valid(follow_target) and is_instance_valid(target_platform):
		var dx = target_platform.global_position.x - follow_target.global_position.x
		target_screen_frac.x = 0.40 if dx >= 0.0 else 0.60
