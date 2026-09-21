extends Camera2D
class_name SolarCamera

# ── Explore Sun V7.5 — Fixed-Height Mars Composition Camera ──────────────────
# Principles:
# 1. FIXED / NEAR-FIXED VERTICAL COMPOSITION:
#    - The camera has a fixed/near-fixed vertical gameplay height.
#    - The player does NOT cause the camera to continuously move upward/downward.
#    - The WORLD moves around the player.
#    - MAX_VERTICAL_CAMERA_SHIFT = approximately 35–45 px.
#    - Safe player vertical band: 32% → 62% of viewport height.
#      Inside this band: ZERO vertical camera follow.
# 2. HORIZONTAL MOVEMENT IS PRIMARY:
#    - Camera follows horizontally with responsive damping (smooth_speed_x ≈ 6.0).
#    - Next pad is the important target: composed in the 65%–80% screen region.
#    - Next pad is NEVER centered (always stays in forward travel half).
# 3. ASYMMETRIC DAMPING:
#    - Horizontal smoothing is fast (smooth_speed_x ≈ 6.0).
#    - Vertical smoothing is slow and heavily damped (smooth_speed_y ≈ 2.2).
#    - Completely eliminates vertical bouncing, vibrations, and sky reveals.
# 4. TOUCHDOWN & DOCKED SETTLING:
#    - Smooth horizontal and vertical convergence over 0.5s with zero teleport/snaps.

const SunZoneData = preload("res://scripts/planet_data.gd")

@export var follow_target: Node2D
@export var smooth_speed: float = 5.5
@export var smooth_speed_x: float = 6.0
@export var smooth_speed_y: float = 2.2

const MAX_VERTICAL_CAMERA_SHIFT: float = 45.0

# Reference to WorldGenerator for terrain queries
var world_gen: Node2D = null

# Current smooth screen fraction (where player sits horizontally on screen)
var current_screen_frac_x: float = 0.38
var target_screen_frac_x: float = 0.38

# Base vertical anchor for the current station/cluster
var anchor_y: float = 420.0
var target_cam_y: float = 420.0
var default_vertical_offset: float = -45.0

var trauma: float = 0.0
var max_angle: float = 0.02
var max_offset: Vector2 = Vector2(8.0, 6.0)

var target_platform: Node2D = null
var current_docked_platform: Node2D = null
var is_initialized: bool = false

func _ready() -> void:
	zoom = Vector2.ONE
	world_gen = get_node_or_null("../WorldGenerator")

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

	var is_crashed = false
	var is_docked = false
	if "current_state" in follow_target:
		is_crashed = (follow_target.current_state == SolarPlayer.State.CRASHED)
		is_docked = (follow_target.current_state == SolarPlayer.State.ON_PAD or follow_target.current_state == SolarPlayer.State.LANDED)
	elif is_instance_valid(current_docked_platform):
		is_docked = (p_pos.distance_to(current_docked_platform.global_position) < 80.0)

	if is_crashed:
		# Freeze camera at impact position during slow-motion explosion
		if trauma > 0.0:
			trauma = maxf(0.0, trauma - delta * 3.5)
			if trauma < 0.01:
				trauma = 0.0
				offset = Vector2.ZERO
				rotation = 0.0
			else:
				var shake_amount = trauma * trauma
				offset.x = randf_range(-1.0, 1.0) * max_offset.x * shake_amount
				offset.y = randf_range(-1.0, 1.0) * max_offset.y * shake_amount
				rotation = randf_range(-1.0, 1.0) * max_angle * shake_amount
		else:
			offset = Vector2.ZERO
			rotation = 0.0
		return

	# ─── 1. HORIZONTAL FOLLOW & NEXT PAD COMPOSITION ─────────────────────────
	# Principle: Horizontal follow is primary. Camera smoothly travels forward
	# to reveal the next pad deck and surrounding terrain in the 65%–80% screen region.
	var travel_dir_x: float = 1.0
	var pad_x: float = p_pos.x + 400.0
	var has_next_pad: bool = false
	if is_instance_valid(target_platform):
		pad_x = target_platform.global_position.x
		var dx_to_pad = pad_x - p_pos.x
		if absf(dx_to_pad) > 20.0:
			travel_dir_x = signf(dx_to_pad)
		has_next_pad = true
	elif absf(p_vel.x) > 60.0:
		travel_dir_x = signf(p_vel.x)

	# Desired baseline player screen fraction (0.38 for rightward, 0.62 for leftward)
	var desired_frac_x: float = 0.38 if travel_dir_x > 0.0 else 0.62
	var vel_offset_x = clampf(p_vel.x / 1400.0, -0.03, 0.03)
	target_screen_frac_x = clampf(desired_frac_x - vel_offset_x, 0.35, 0.65)

	var frac_blend = 1.0 - exp(-3.5 * delta)
	current_screen_frac_x = lerpf(current_screen_frac_x, target_screen_frac_x, frac_blend)

	# Baseline camera X placing player at current_screen_frac_x
	var base_cam_x = p_pos.x - (current_screen_frac_x - 0.5) * (vp_size.x / zoom.x)
	var target_cam_x = base_cam_x

	# If next pad is ahead, blend camera X toward next pad so it enters 65%–80% screen area
	if has_next_pad:
		var pad_screen_x = (pad_x - base_cam_x) * zoom.x + vp_size.x * 0.5
		if travel_dir_x > 0.0:
			# Pad is to our right. If it's too far right (> 80%), shift camera right to reveal it
			if pad_screen_x > vp_size.x * 0.80:
				var pull_x = (pad_screen_x - vp_size.x * 0.80) / zoom.x
				# Limit shift so player never gets pushed past 26% from left edge
				var max_player_push = (current_screen_frac_x - 0.26) * (vp_size.x / zoom.x)
				target_cam_x += minf(pull_x, max_player_push)
			# Never let next pad be centered: pad must stay >= 56% screen width
			elif pad_screen_x < vp_size.x * 0.56:
				var push_back = (vp_size.x * 0.56 - pad_screen_x) / zoom.x
				target_cam_x -= push_back
		else:
			# Pad is to our left (leftward travel)
			if pad_screen_x < vp_size.x * 0.20:
				var pull_x = (vp_size.x * 0.20 - pad_screen_x) / zoom.x
				var max_player_push = (0.74 - current_screen_frac_x) * (vp_size.x / zoom.x)
				target_cam_x -= minf(pull_x, max_player_push)
			elif pad_screen_x > vp_size.x * 0.44:
				var push_back = (pad_screen_x - vp_size.x * 0.44) / zoom.x
				target_cam_x += push_back

	# ─── 2. FIXED / NEAR-FIXED VERTICAL COMPOSITION ──────────────────────────
	# Principle: Camera has a fixed/near-fixed vertical height.
	# The world moves around the player.
	# Vertical movement is ONLY a small corrective movement (capped at 45px).
	var base_route_y = anchor_y
	if is_instance_valid(current_docked_platform) and is_instance_valid(target_platform):
		var x1 = current_docked_platform.global_position.x
		var x2 = target_platform.global_position.x
		var y1 = current_docked_platform.global_position.y - 45.0
		var y2 = target_platform.global_position.y - 45.0
		var span = x2 - x1
		if absf(span) > 60.0:
			var t_prog = clampf((p_pos.x - x1) / span, 0.0, 1.0)
			# S-curve smoothstep across the route span
			var s_prog = t_prog * t_prog * (3.0 - 2.0 * t_prog)
			base_route_y = lerpf(y1, y2, s_prog)
		else:
			base_route_y = y2
	elif is_instance_valid(current_docked_platform):
		base_route_y = current_docked_platform.global_position.y - 45.0
	elif is_instance_valid(target_platform):
		base_route_y = target_platform.global_position.y - 45.0

	var vert_correction: float = 0.0
	if is_docked:
		# When docked: gently settle at the platform baseline
		target_cam_y = base_route_y
	else:
		# Airborne: check player screen position relative to base_route_y
		var player_screen_y = (p_pos.y - base_route_y) * zoom.y + vp_size.y * 0.5

		# Safe band: 32% to 62% of viewport height
		# NORMAL flight inside safe band: ZERO vertical camera adjustment!
		if player_screen_y < vp_size.y * 0.30:
			# Player climbs into high stratosphere: small corrective lift
			var excess_up = (vp_size.y * 0.30 - player_screen_y) / zoom.y
			vert_correction -= clampf(excess_up * 0.35, 0.0, 35.0)
		elif player_screen_y > vp_size.y * 0.62:
			# Player drops below lower comfort limit: small corrective lower
			var excess_down = (player_screen_y - vp_size.y * 0.62) / zoom.y
			vert_correction += clampf(excess_down * 0.35, 0.0, 35.0)

		# Small, controlled descent lookahead when falling fast (max 20px)
		if p_vel.y > 40.0:
			var descent_t = clampf((p_vel.y - 40.0) / 400.0, 0.0, 1.0)
			vert_correction += descent_t * 20.0

		# Strict cap: total vertical camera shift never exceeds 45px!
		vert_correction = clampf(vert_correction, -MAX_VERTICAL_CAMERA_SHIFT, MAX_VERTICAL_CAMERA_SHIFT)
		target_cam_y = base_route_y + vert_correction

	# ─── 3. Asymmetric Continuous Follow (Damped Exponential) ────────────────
	# Horizontal smoothing (fast, responsive) vs Vertical smoothing (slow, stable)
	# This prevents the camera from ever bouncing or vibrating vertically.
	var blend_x = 1.0 - exp(-smooth_speed_x * delta)
	var blend_y = 1.0 - exp(-smooth_speed_y * delta)
	global_position.x = lerpf(global_position.x, target_cam_x, blend_x)
	global_position.y = lerpf(global_position.y, target_cam_y, blend_y)

	# ─── 4. Stable Scale & Subtle Horizontal Zoom ────────────────────────────
	var dist_to_pad: float = 0.0
	if is_instance_valid(target_platform):
		dist_to_pad = absf(target_platform.global_position.x - p_pos.x)

	var target_zoom_val: float = 1.0
	if dist_to_pad > 700.0:
		var zoom_t = clampf((dist_to_pad - 700.0) / 700.0, 0.0, 1.0)
		target_zoom_val = lerpf(1.0, 0.95, zoom_t)

	var zoom_blend = 1.0 - exp(-2.5 * delta)
	var new_z = lerpf(zoom.x, target_zoom_val, zoom_blend)
	zoom = Vector2(new_z, new_z)

	# ─── 5. Screen Shake Trauma ──────────────────────────────────────────────
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - delta * 3.5)
		if trauma < 0.01:
			trauma = 0.0
			offset = Vector2.ZERO
			rotation = 0.0
		else:
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

	current_screen_frac_x = 0.38 if travel_dir_x > 0.0 else 0.62
	target_screen_frac_x = current_screen_frac_x

	var screen_offset_x = (current_screen_frac_x - 0.5) * vp_size.x
	global_position.x = follow_target.global_position.x - (screen_offset_x / zoom.x)

	anchor_y = follow_target.global_position.y - 45.0
	target_cam_y = anchor_y
	global_position.y = anchor_y

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func notify_landed(platform: Node2D) -> void:
	add_trauma(0.06)
	current_docked_platform = platform
	anchor_y = platform.global_position.y - 45.0
	if is_instance_valid(target_platform) and target_platform != platform:
		var dx = target_platform.global_position.x - platform.global_position.x
		target_screen_frac_x = 0.38 if dx >= 0.0 else 0.62

func set_next_target_platform(platform: Node2D) -> void:
	target_platform = platform
	if is_instance_valid(follow_target) and is_instance_valid(target_platform):
		var dx = target_platform.global_position.x - follow_target.global_position.x
		target_screen_frac_x = 0.38 if dx >= 0.0 else 0.62
