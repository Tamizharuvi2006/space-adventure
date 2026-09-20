extends Camera2D
class_name SolarCamera

# ── Explore Sun V6.3 — Mars-Style Gameplay Composition Camera ────────────────
# Principles:
# 1. UNIFIED GAMEPLAY COMPOSITION (NOT A "FOLLOW PLAYER" CAMERA):
#    - Composes PLAYER + UPCOMING TERRAIN + NEXT PAD together in the visible frame.
#    - Player moves dynamically through the viewport (lower-middle on climb, upper-middle on descent).
#    - Player is NEVER artificially locked to the exact center.
# 2. HORIZONTAL DIRECTIONAL TRAVEL COMPOSITION:
#    - Rightward travel / resting with route ahead: player sits at ~38%–42% from left edge.
#    - Leftward travel: player sits at ~58%–62% from left edge.
#    - Always reveals generous forward space in travel direction.
# 3. DAMPED VERTICAL ENVELOPE (PARTIAL TRACKING):
#    - When player rises 300px, camera rises only ~80–110px (ratio ~0.32).
#    - Player visibly rises through the sky on screen, while the world scrolls gently.
# 4. NEXT PAD VISIBILITY BAND (25% → 75% Viewport Height):
#    - Keeps the upcoming pad safely within the vertical visibility band.
# 5. TERRAIN OCCLUSION PROTECTION:
#    - If a mountain peak exists between player and next pad, camera gently lifts framing
#      so the next pad remains readable above the terrain.
# 6. SMOOTH CONTINUOUS TRANSITIONS (NO SNAPPING):
#    - Camera follows a LIVE target recalculated every frame using exponential damping.
#    - On landing, camera glides into the new docked composition over ~0.5–0.8 seconds.
#    - If player relaunches during transition, camera immediately tracks the new flight path.

const SunZoneData = preload("res://scripts/planet_data.gd")

@export var follow_target: Node2D
@export var smooth_speed: float = 4.8

# Reference to WorldGenerator for terrain queries
var world_gen: Node2D = null

# Current smooth screen fraction (where player sits horizontally on screen)
var current_screen_frac_x: float = 0.40
var target_screen_frac_x: float = 0.40

# Base vertical anchor for the current station/cluster
var anchor_y: float = 420.0
var default_vertical_offset: float = -65.0

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

	# ─── 1. Horizontal Directional Travel Composition ────────────────────────
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

	var screen_offset_x = (current_screen_frac_x - 0.5) * vp_size.x
	var target_cam_x = p_pos.x - (screen_offset_x / zoom.x)

	# ─── 2. Damped Vertical Envelope & Gameplay Composition ──────────────────
	# Determine station anchor Y
	if is_instance_valid(current_docked_platform):
		anchor_y = current_docked_platform.global_position.y - 45.0
	elif is_instance_valid(target_platform):
		anchor_y = target_platform.global_position.y - 45.0
	elif not is_initialized:
		anchor_y = p_pos.y - 45.0

	# Partial damped tracking: when player rises 300px, camera rises only ~96px (ratio 0.32)
	# Player visibly climbs into the upper sky while terrain scrolls gently
	var player_dy = p_pos.y - anchor_y
	var target_cam_y = anchor_y + (player_dy * 0.32)

	# Next pad vertical visibility band (25% → 75% Viewport Height)
	if is_instance_valid(target_platform):
		var pad_pos = target_platform.global_position
		var pad_screen_y = (pad_pos.y - target_cam_y) * zoom.y + vp_size.y * 0.5
		var top_safe_y = vp_size.y * 0.25
		var bot_safe_y = vp_size.y * 0.75

		if pad_screen_y < top_safe_y:
			target_cam_y -= (top_safe_y - pad_screen_y) / zoom.y
		elif pad_screen_y > bot_safe_y:
			target_cam_y += (pad_screen_y - bot_safe_y) / zoom.y

		# Terrain Occlusion Protection: check terrain peak between player and next pad
		if is_instance_valid(world_gen) and world_gen.has_method("get_terrain_surface_y"):
			var mid_x = (p_pos.x + pad_pos.x) * 0.5
			var zone_idx = 0
			if is_instance_valid(current_docked_platform) and "platform_index" in current_docked_platform:
				zone_idx = SunZoneData.get_zone_index(current_docked_platform.platform_index)
			var crest_y = world_gen.get_terrain_surface_y(mid_x, zone_idx)
			
			# If mountain ridge crest is high, lift camera slightly so next pad is clearly visible
			if crest_y < pad_pos.y - 20.0:
				var crest_screen_y = (crest_y - target_cam_y) * zoom.y + vp_size.y * 0.5
				if crest_screen_y < vp_size.y * 0.40:
					target_cam_y -= (vp_size.y * 0.40 - crest_screen_y) * 0.35 / zoom.y

	# ─── 3. Smooth Continuous Follow (Every Frame, No Snapping) ──────────────
	var cam_blend = 1.0 - exp(-smooth_speed * delta)
	global_position.x = lerpf(global_position.x, target_cam_x, cam_blend)
	global_position.y = lerpf(global_position.y, target_cam_y, cam_blend)

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

	anchor_y = follow_target.global_position.y - 45.0
	global_position.y = anchor_y

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func notify_landed(platform: Node2D) -> void:
	add_trauma(0.06)
	current_docked_platform = platform
	# DO NOT snap position! Camera will smoothly glide to the new docked composition
	if is_instance_valid(target_platform) and target_platform != platform:
		var dx = target_platform.global_position.x - platform.global_position.x
		target_screen_frac_x = 0.40 if dx >= 0.0 else 0.60

func set_next_target_platform(platform: Node2D) -> void:
	target_platform = platform
	if is_instance_valid(follow_target) and is_instance_valid(target_platform):
		var dx = target_platform.global_position.x - follow_target.global_position.x
		target_screen_frac_x = 0.40 if dx >= 0.0 else 0.60
