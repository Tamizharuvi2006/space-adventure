extends Camera2D
class_name SolarCamera

# ── Explore Sun V6.2 — Smooth Landing Camera Transition (Mars: Mars Style) ──
# Principles:
# 1. FIXED VERTICAL CAMERA HEIGHT:
#    - camera.position.y is strictly locked throughout the entire game.
#    - Never interpolate camera Y, never follow player Y, no vertical lookahead.
#    - No vertical landing movement: terrain and pads remain in stable vertical world coordinates.
# 2. SMOOTH CONTINUOUS HORIZONTAL TRANSITION:
#    - Camera follows a LIVE horizontal target using exponential damping:
#      camera.position.x = lerp(target_x, 1.0 - exp(-smooth_speed * delta))
#    - On landing, the camera gently glides into the new framing over ~0.5–0.8 seconds.
#    - NO instant jump or snap when landing, changing pads, or relaunching.
# 3. DIRECTIONAL COMPOSITION (MARS-STYLE):
#    - Rightward travel / resting with route ahead: player ≈ 38%–42% from left edge.
#    - Leftward travel: player ≈ 58%–62% from left edge.
# 4. LIVE TARGET TRACKING:
#    - No static tweens; if player relaunches during landing glide, the camera immediately
#      follows the new live flight vector smoothly.

@export var follow_target: Node2D
@export var smooth_speed: float = 5.0

# Strictly fixed vertical camera world position
var fixed_world_y: float = 420.0
var default_vertical_offset: float = -65.0

# Current smooth screen fraction (where player sits horizontally on screen)
var current_screen_frac_x: float = 0.40
var target_screen_frac_x: float = 0.40

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

	# ─── 1. Determine Horizontal Directional Composition ─────────────────────
	var travel_dir_x: float = 1.0
	if is_instance_valid(target_platform):
		var dx_to_pad = target_platform.global_position.x - p_pos.x
		if absf(dx_to_pad) > 15.0:
			travel_dir_x = signf(dx_to_pad)

	if absf(p_vel.x) > 30.0:
		travel_dir_x = signf(p_vel.x)

	var desired_frac_x: float = 0.40 if travel_dir_x > 0.0 else 0.60

	# Dynamic velocity lookahead (subtle forward bias during fast flight)
	var vel_offset_x = clampf(p_vel.x / 600.0, -0.05, 0.05)
	target_screen_frac_x = clampf(desired_frac_x - vel_offset_x, 0.35, 0.65)

	# Smoothly interpolate the horizontal screen composition anchor
	var frac_blend = 1.0 - exp(-4.0 * delta)
	current_screen_frac_x = lerpf(current_screen_frac_x, target_screen_frac_x, frac_blend)

	# ─── 2. Smooth Live Horizontal Camera Follow ─────────────────────────────
	var screen_offset_x = (current_screen_frac_x - 0.5) * vp_size.x
	var target_cam_x = p_pos.x - (screen_offset_x / zoom.x)

	# Continuous exponential smoothing (smooth damp) ensures zero jumps
	var cam_blend = 1.0 - exp(-smooth_speed * delta)
	global_position.x = lerpf(global_position.x, target_cam_x, cam_blend)

	# ─── 3. STRICTLY LOCKED VERTICAL CAMERA HEIGHT ───────────────────────────
	# Never interpolate camera Y, never follow player Y. Y is strictly fixed.
	global_position.y = fixed_world_y

	# ─── 4. Stable Scale & Subtle Horizontal Zoom ────────────────────────────
	var dist_to_pad: float = 0.0
	if is_instance_valid(target_platform):
		dist_to_pad = absf(target_platform.global_position.x - p_pos.x)

	var target_zoom_val: float = 1.0
	if dist_to_pad > 650.0:
		var zoom_t = clampf((dist_to_pad - 650.0) / 750.0, 0.0, 1.0)
		target_zoom_val = lerpf(1.0, 0.94, zoom_t)

	var zoom_blend = 1.0 - exp(-2.5 * delta)
	var new_z = lerpf(zoom.x, target_zoom_val, zoom_blend)
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

	# Fixed baseline Y initialized once from starting position
	fixed_world_y = follow_target.global_position.y - 65.0
	global_position.y = fixed_world_y

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func notify_landed(platform: Node2D) -> void:
	add_trauma(0.06)
	current_docked_platform = platform
	# DO NOT change fixed_world_y on landing - vertical camera remains strictly locked!
	# Update target horizontal composition towards the upcoming target platform
	if is_instance_valid(target_platform) and target_platform != platform:
		var dx = target_platform.global_position.x - platform.global_position.x
		target_screen_frac_x = 0.40 if dx >= 0.0 else 0.60

func set_next_target_platform(platform: Node2D) -> void:
	target_platform = platform
	if is_instance_valid(follow_target) and is_instance_valid(target_platform):
		var dx = target_platform.global_position.x - follow_target.global_position.x
		target_screen_frac_x = 0.40 if dx >= 0.0 else 0.60
