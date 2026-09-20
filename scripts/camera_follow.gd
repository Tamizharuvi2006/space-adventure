extends Camera2D
class_name SolarCamera

# ── Explore Sun V6.1 — Fixed-Height Horizontal Side-Scrolling Camera ─────────
# Principles:
# 1. FIXED VERTICAL CAMERA HEIGHT:
#    - Camera Y does NOT follow player.global_position.y.
#    - No vertical camera tracking, no vertical lookahead, no vertical deadzone.
#    - When astronaut rises: PLAYER moves UP on screen, CAMERA Y STAYS FIXED.
#    - When astronaut falls: PLAYER moves DOWN on screen, CAMERA Y STAYS FIXED.
#    - Pads and terrain remain in the exact same vertical screen position during flight.
# 2. HORIZONTAL MOVEMENT WITH DIRECTIONAL TRAVEL COMPOSITION:
#    - Camera X smoothly tracks travel direction.
#    - Rightward travel: player sits at ~38%–42% of viewport width (more space ahead on right).
#    - Leftward travel: player sits at ~58%–62% of viewport width (more space ahead on left).
# 3. NO RECENTERING ON LANDING:
#    - When landed, the player remains naturally offset at ~40% with the forward path ahead.
# 4. FIXED VERTICAL SCALE:
#    - No vertical zoom compensation.
#    - Subtle horizontal zoom adjustment (0.94 to 1.00) only for distant jumps.

@export var follow_target: Node2D
@export var smooth_speed: float = 5.0

# Fixed vertical camera world position
var fixed_world_y: float = 420.0

# Current smooth screen fraction (where player sits horizontally on screen)
var current_screen_frac_x: float = 0.40
var target_screen_frac_x: float = 0.40

# Compatibility with main.gd / HUD
var default_vertical_offset: float = -65.0

var trauma: float = 0.0
var max_angle: float = 0.02
var max_offset: Vector2 = Vector2(8.0, 6.0)

var target_platform: Node2D = null
var current_docked_platform: Node2D = null
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

	# ─── 1. Horizontal Travel Direction & Screen Composition ─────────────────
	# Default: player at 40% when heading right, 60% when heading left
	var travel_dir_x: float = 1.0
	if is_instance_valid(target_platform):
		var dx_to_pad = target_platform.global_position.x - p_pos.x
		if absf(dx_to_pad) > 15.0:
			travel_dir_x = signf(dx_to_pad)

	if absf(p_vel.x) > 30.0:
		travel_dir_x = signf(p_vel.x)

	var desired_frac_x: float = 0.40 if travel_dir_x > 0.0 else 0.60

	# Dynamic velocity lookahead (shifts composition slightly forward during fast cruise)
	var vel_offset_x = clampf(p_vel.x / 600.0, -0.05, 0.05)
	target_screen_frac_x = clampf(desired_frac_x - vel_offset_x, 0.35, 0.65)

	# Smoothly interpolate the horizontal screen composition anchor
	current_screen_frac_x = lerpf(current_screen_frac_x, target_screen_frac_x, 4.0 * delta)

	# ─── 2. Horizontal Camera Position ───────────────────────────────────────
	var screen_offset_x = (current_screen_frac_x - 0.5) * vp_size.x
	var target_cam_x = p_pos.x - (screen_offset_x / zoom.x)
	global_position.x = lerpf(global_position.x, target_cam_x, smooth_speed * delta)

	# ─── 3. STRICTLY FIXED VERTICAL CAMERA HEIGHT ────────────────────────────
	# Camera Y NEVER follows player Y during gameplay.
	# The player moves vertically on screen; camera Y is locked.
	global_position.y = fixed_world_y

	# ─── 4. Stable Scale & Subtle Horizontal Zoom ────────────────────────────
	var dist_to_pad: float = 0.0
	if is_instance_valid(target_platform):
		dist_to_pad = absf(target_platform.global_position.x - p_pos.x)

	var target_zoom_val: float = 1.0
	if dist_to_pad > 650.0:
		var zoom_t = clampf((dist_to_pad - 650.0) / 750.0, 0.0, 1.0)
		target_zoom_val = lerpf(1.0, 0.94, zoom_t)

	var new_z = lerpf(zoom.x, target_zoom_val, 2.5 * delta)
	zoom = Vector2(new_z, new_z)

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

	current_screen_frac_x = 0.40 if travel_dir_x > 0.0 else 0.60
	target_screen_frac_x = current_screen_frac_x

	var screen_offset_x = (current_screen_frac_x - 0.5) * vp_size.x
	global_position.x = follow_target.global_position.x - (screen_offset_x / zoom.x)

	# Initialize fixed Y to comfortable baseline
	fixed_world_y = follow_target.global_position.y - 65.0
	global_position.y = fixed_world_y

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func notify_landed(platform: Node2D) -> void:
	add_trauma(0.06)
	current_docked_platform = platform
	# When landed, update fixed vertical height to this platform's baseline
	if is_instance_valid(platform):
		fixed_world_y = platform.global_position.y - 65.0

	# Keep directional offset towards next platform
	if is_instance_valid(target_platform) and target_platform != platform:
		var dx = target_platform.global_position.x - platform.global_position.x
		target_screen_frac_x = 0.40 if dx >= 0.0 else 0.60

func set_next_target_platform(platform: Node2D) -> void:
	target_platform = platform
	if is_instance_valid(follow_target) and is_instance_valid(target_platform):
		var dx = target_platform.global_position.x - follow_target.global_position.x
		target_screen_frac_x = 0.40 if dx >= 0.0 else 0.60
