extends SceneTree

const SunZoneData = preload("res://scripts/planet_data.gd")
const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")
const SolarPlatform = preload("res://scripts/platform.gd")
const SolarHUD = preload("res://scripts/hud.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")
const SolarCamera = preload("res://scripts/camera_follow.gd")

var current_main: SolarMain = null

func _init() -> void:
	print("\n=======================================================")
	print("   TEST V7.4: DESCENT LOOK-AHEAD CAMERA & LANDER SUITE ")
	print("=======================================================\n")
	call_deferred("_run_all_tests")

func _spawn_fresh_game_instance() -> SolarMain:
	Engine.time_scale = 1.0
	if is_instance_valid(current_main):
		root.remove_child(current_main)
		current_main.queue_free()
		current_main = null
		
	var packed = load("res://scenes/main.tscn") as PackedScene
	var inst = packed.instantiate() as SolarMain
	root.add_child(inst)
	current_main = inst
	return inst

func _run_all_tests() -> void:
	# Clear save file to start clean at Pad 1
	var save_path = "user://explore_sun_save.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	var game = _spawn_fresh_game_instance()
	await process_frame
	await process_frame
	
	var hud = game.hud
	var player = game.player
	var world_gen = game.world_gen
	var camera = game.camera
	var vp_size = game.get_viewport().get_visible_rect().size
	
	# Start game
	hud.emit_signal("play_game_requested")
	while game.current_state != SolarMain.GameState.PLAYING:
		await physics_frame
	await physics_frame
	
	# -------------------------------------------------------------------------
	# TEST 1: Explorer Lander Visual Hierarchy & Footpad Alignment
	# -------------------------------------------------------------------------
	print("--- TEST 1: Planetary Explorer Lander Visual Hierarchy ---")
	var visuals = player.get_node("Visuals")
	assert(visuals.has_node("Head") or visuals.has_node("LanderHull"), "Explorer must have Head!")
	assert(visuals.has_node("Torso") or visuals.has_node("CockpitDome"), "Explorer must have Torso!")
	assert(visuals.has_node("Backpack") or visuals.has_node("SensorMast"), "Explorer must have Backpack equipment!")
	assert((visuals.has_node("LeftLeg") and visuals.has_node("RightLeg")) or (visuals.has_node("LeftLegFront") and visuals.has_node("RightLegFront")), "Explorer must have legs!")
	
	# Verify collision capsule preserves landing clearance
	var col_shape = player.get_node("CollisionShape2D") as CollisionShape2D
	assert(col_shape != null and col_shape.shape is CapsuleShape2D, "CapsuleShape2D collision must be preserved!")
	print("  ✅ TEST 1 PASSED: Planetary explorer lander visual structure and collision verified.")

	# -------------------------------------------------------------------------
	# TEST 2: High Pad Ascent: Minimal Vertical Chasing
	# -------------------------------------------------------------------------
	print("\n--- TEST 2: High Pad Ascent: Minimal Vertical Chasing ---")
	var pad_1 = world_gen.get_platform_by_index(1)
	player.global_position = pad_1.get_landing_position()
	player.velocity = Vector2.ZERO
	camera.snap_to_target()
	for _f in range(10): await physics_frame
	
	var initial_cam_y = camera.global_position.y
	var initial_player_y = player.global_position.y
	
	# Launch straight upward
	player.global_position.y -= 15.0
	player.current_state = SolarPlayer.State.FLYING
	player.launch_grace_timer = 1.0
	player.velocity = Vector2(50.0, -320.0) # Ascending fast
	
	for _f in range(20):
		await process_frame
		
	var player_climbed = initial_player_y - player.global_position.y
	var cam_climbed = initial_cam_y - camera.global_position.y
	
	# Camera climb ratio should be conservative (< 0.45 of player climb), letting player rise into sky
	var climb_ratio = cam_climbed / maxf(player_climbed, 1.0)
	assert(climb_ratio < 0.45, "Camera must NOT aggressively follow player vertically on ascent! (ratio=%.2f)" % climb_ratio)
	print("  ✅ TEST 2 PASSED: Ascent maintains wide Mars view without vertical chasing (ratio=%.2f)." % climb_ratio)

	# -------------------------------------------------------------------------
	# TEST 3: Descent Look-Ahead: Dynamic Lower Terrain Reveal
	# -------------------------------------------------------------------------
	print("\n--- TEST 3: Descent Look-Ahead: Reveals Lower Terrain ---")
	# Put player into an airborne descent
	player.current_state = SolarPlayer.State.FLYING
	player.launch_grace_timer = 1.0
	player.velocity = Vector2(80.0, 380.0) # Falling fast
	var pre_fall_cam_y = camera.global_position.y
	
	for _f in range(25):
		await process_frame
		
	var cam_fall_drift = camera.global_position.y - pre_fall_cam_y
	assert(cam_fall_drift >= 5.0 and cam_fall_drift <= 45.0, "Camera descent shift must be controlled and bounded <= 45px! (drift=%.1f)" % cam_fall_drift)
	
	# Verify player stays inside comfortable safe zone (< 75% screen height)
	var p_screen_y = (player.global_position.y - camera.global_position.y) * camera.zoom.y + vp_size.y * 0.5
	var p_frac = p_screen_y / vp_size.y
	assert(p_frac < 0.75, "Player must remain above bottom safe margin during descent!")
	print("  ✅ TEST 3 PASSED: Downward look-ahead smoothly expands lower view (drift=%.1fpx, player at %.1f%%)." % [cam_fall_drift, p_frac * 100.0])

	# -------------------------------------------------------------------------
	# TEST 4: Next Pad Visibility Constraint When Dropping
	# -------------------------------------------------------------------------
	print("\n--- TEST 4: Next Pad Visibility Constraint ---")
	var pad_2 = world_gen.get_platform_by_index(2)
	assert(is_instance_valid(pad_2), "Pad 2 must exist!")
	camera.set_next_target_platform(pad_2)
	
	# Simulate approach to pad 2
	for _f in range(30):
		await process_frame
		
	var pad_screen_y = (pad_2.global_position.y - camera.global_position.y) * camera.zoom.y + vp_size.y * 0.5
	var pad_frac = pad_screen_y / vp_size.y
	assert(pad_frac >= 0.15 and pad_frac <= 0.78, "Upcoming landing pad must be revealed well before touchdown! (pad=%.1f%%)" % (pad_frac * 100.0))
	print("  ✅ TEST 4 PASSED: Upcoming pad smoothly framed in lower-middle zone (%.1f%%)." % (pad_frac * 100.0))

	# -------------------------------------------------------------------------
	# TEST 5: Smooth Touchdown Settling (Zero Jumps)
	# -------------------------------------------------------------------------
	print("\n--- TEST 5: Smooth Touchdown Settling ---")
	player.spawn_on_platform(pad_2)
	game._on_player_landed(pad_2, true)
	
	var cam_pos_at_landing = camera.global_position
	# Measure position delta per frame over 15 frames - should be smooth and continuous, no teleport
	var max_step_y = 0.0
	var prev_y = camera.global_position.y
	for _f in range(15):
		await process_frame
		var step = absf(camera.global_position.y - prev_y)
		max_step_y = maxf(max_step_y, step)
		prev_y = camera.global_position.y
		
	assert(max_step_y < 15.0, "Camera settling on landing must be smooth with no sudden snaps! (max_step=%.1f)" % max_step_y)
	print("  ✅ TEST 5 PASSED: Touchdown settles continuously with zero camera jumps (max_step=%.1fpx)." % max_step_y)

	# -------------------------------------------------------------------------
	# TEST 6: Zero Camera Shake / Vibration During Normal Flight
	# -------------------------------------------------------------------------
	print("\n--- TEST 6: Stable Flight (Zero Shake / Vibration) ---")
	player.current_state = SolarPlayer.State.FLYING
	player.velocity = Vector2(120.0, -80.0)
	
	# Run 20 frames of normal flying
	for _f in range(20):
		await process_frame
		assert(camera.trauma == 0.0, "Trauma must remain exactly 0.0 during normal flight!")
		assert(camera.offset == Vector2.ZERO, "Camera offset must remain Vector2.ZERO during normal flight!")
		assert(camera.rotation == 0.0, "Camera rotation must remain 0.0 during normal flight!")
		
	print("  ✅ TEST 6 PASSED: Normal flight has zero camera shake, vibration, or jitter.")

	# -------------------------------------------------------------------------
	# TEST 7: Impact Shake Isolated to Crash / Death
	# -------------------------------------------------------------------------
	print("\n--- TEST 7: Impact Shake Isolated to Death Event ---")
	camera.add_trauma(0.55) # Crash trauma
	assert(camera.trauma > 0.0, "Crash adds controlled impact trauma.")
	
	# Over 35 frames, trauma decays completely to zero
	for _f in range(35):
		await process_frame
		
	assert(camera.trauma == 0.0, "Trauma must decay quickly to zero after impact!")
	assert(camera.offset == Vector2.ZERO, "Offset must return to Vector2.ZERO after decay!")
	print("  ✅ TEST 7 PASSED: Impact shake is brief and safely decays back to zero.")

	print("\n=======================================================")
	print("   ALL 7 V7.4 DESCENT & LANDER TESTS PASSED! 🎉       ")
	print("=======================================================\n")
	quit(0)
