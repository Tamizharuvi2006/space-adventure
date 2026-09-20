extends Camera2D
class_name SolarCamera

# ── Explore Sun V5.9 — Mars: Mars Style Camera Composition ───────────────────
# Principles:
# 1. Wide Travelling Gameplay View:
#    - Player + Current Terrain + Next Pad + Surrounding Landscape visible together.
# 2. Prioritizes Travel Corridor (Forward Framing):
#    - Player sits at ~35%–45% from left when traveling right (giving more space ahead).
#    - Mirrored when traveling left.
# 3. Dynamic Destination Influence:
#    - Blends player position with next pad position so destination is readable well before landing.
#    - Destination pull is clamped so distant pads don't yank the camera away.
# 4. Moderate Dynamic Zoom (Horizontal World > Vertical Sky):
#    - Baseline zoom = 1.00.
#    - Farther pads gently zoom to ~0.90–0.94, revealing wider horizontal corridor without shrinking player.
# 5. Landing Corridor Framing:
#    - Touchdown and approach bring player, destination pad, and surrounding bedrock into lower-middle view.
# 6. Mobile Landscape Viewport Adaptability:
#    - Viewport-relative calculations supporting 16:9, 18:9, 19.5:9, 20:9, and tablets.

@export var follow_target: Node2D
@export var smooth_speed: float = 5.5

# Rest vertical offset so docked player + platform sit at ~55% screen height
const REST_VERTICAL_OFFSET: float = -40.0
var default_vertical_offset: float = -40.0

# Secondary velocity lookahead
const LOOK_AHEAD_X: float = 0.08
const LOOK_AHEAD_Y: float = 0.06
const MAX_LOOK_X: float = 35.0
const MAX_LOOK_Y: float = 25.0

var trauma: float = 0.0
var max_angle: float = 0.02
var max_offset: Vector2 = Vector2(8.0, 6.0)

var current_vel_look: Vector2 = Vector2.ZERO
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

	# ─── 1. Forward Travel Direction & Framing Bias ──────────────────────────
	# Player sits at ~38%–42% from left when traveling right (more world space ahead).
	# When traveling left, mirrored.
	var travel_dir_x: float = 1.0
	if is_instance_valid(target_platform):
		var dx_to_pad = target_platform.global_position.x - p_pos.x
		if absf(dx_to_pad) > 10.0:
			travel_dir_x = signf(dx_to_pad)
	if absf(p_vel.x) > 25.0:
		travel_dir_x = signf(p_vel.x)

	# ─── 2. Destination Influence (Next Pad Weighted Pull) ───────────────────
	# camera_target = player * 0.65 + next_pad * 0.35 (clamped)
	var dest_offset = Vector2.ZERO
	var dist_to_pad: float = 0.0
	
	if is_instance_valid(target_platform):
		var pad_pos = target_platform.global_position
		var to_pad = pad_pos - p_pos
		dist_to_pad = to_pad.length()

		# Horizontal destination pull:
		# Shifts camera ahead so next pad enters view well before arrival
		var max_pull_x = vp_size.x * 0.24 # ~300px max pull on 1280w
		var pull_x = clampf(to_pad.x * 0.24, -max_pull_x, max_pull_x)

		# Vertical destination pull:
		# Keeps next pad and landing terrain visible when player climbs or descends
		var max_pull_y = vp_size.y * 0.18 # ~130px max pull on 720h
		var pull_y = clampf(to_pad.y * 0.22, -max_pull_y, max_pull_y)

		# If player has missed the pad and is falling into abyss, fade out vertical pull
		if p_pos.y > pad_pos.y + 60.0:
			var fall_t = clampf((p_pos.y - (pad_pos.y + 60.0)) / 120.0, 0.0, 1.0)
			pull_y = lerpf(pull_y, 0.0, fall_t)

		dest_offset = Vector2(pull_x, pull_y)

	# ─── 3. Secondary Velocity Lookahead ─────────────────────────────────────
	var target_look_x: float = clampf(p_vel.x * LOOK_AHEAD_X, -MAX_LOOK_X, MAX_LOOK_X)
	var target_look_y: float = clampf(p_vel.y * LOOK_AHEAD_Y, -MAX_LOOK_Y, MAX_LOOK_Y)

	current_vel_look.x = lerpf(current_vel_look.x, target_look_x, 4.0 * delta)
	current_vel_look.y = lerpf(current_vel_look.y, target_look_y, 4.0 * delta)

	# ─── 4. Moderate Dynamic Zoom (Wider Horizontal Corridor) ────────────────
	# Baseline zoom: 1.00
	# Distant destination: gently zoom to ~0.90–0.93 so next pad is visible ahead
	var target_zoom_val: float = 1.0
	if dist_to_pad > 550.0:
		var zoom_t = clampf((dist_to_pad - 550.0) / 750.0, 0.0, 1.0)
		target_zoom_val = lerpf(1.0, 0.91, zoom_t)
	
	var current_z = zoom.x
	var new_z = lerpf(current_z, target_zoom_val, 2.5 * delta)
	zoom = Vector2(new_z, new_z)

	# ─── 5. Desired Camera Position & Smooth Follow ──────────────────────────
	var desired_pos = Vector2(
		p_pos.x + dest_offset.x + current_vel_look.x,
		p_pos.y + default_vertical_offset + dest_offset.y + current_vel_look.y
	)

	global_position.x = lerpf(global_position.x, desired_pos.x, smooth_speed * delta)
	global_position.y = lerpf(global_position.y, desired_pos.y, smooth_speed * delta)

	# ─── 6. Screen Shake Trauma ──────────────────────────────────────────────
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
	var p_pos = follow_target.global_position
	var dest_pull_x = 0.0
	var dest_pull_y = 0.0
	if is_instance_valid(target_platform):
		var vp_size = get_viewport_rect().size
		if vp_size.x <= 0.0:
			vp_size = Vector2(1280.0, 720.0)
		var to_pad = target_platform.global_position - p_pos
		dest_pull_x = clampf(to_pad.x * 0.24, -vp_size.x * 0.24, vp_size.x * 0.24)
		dest_pull_y = clampf(to_pad.y * 0.22, -vp_size.y * 0.18, vp_size.y * 0.18)

	global_position = Vector2(p_pos.x + dest_pull_x, p_pos.y + default_vertical_offset + dest_pull_y)
	current_vel_look = Vector2.ZERO

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func notify_landed(_platform: Node2D) -> void:
	add_trauma(0.06)

func set_next_target_platform(platform: Node2D) -> void:
	target_platform = platform
