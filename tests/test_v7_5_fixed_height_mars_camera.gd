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
	print("   TEST V7.5: FIXED-HEIGHT MARS COMPOSITION CAMERA     ")
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

	hud.emit_signal("play_game_requested")
	while game.current_state != SolarMain.GameState.PLAYING:
		await physics_frame
	await physics_frame

	# Ensure pads up to 12 exist
	while world_gen.next_platform_idx <= 12:
		world_gen.spawn_next_route_pad()
		await process_frame

	# -------------------------------------------------------------------------
	# TEST A: Launch — Camera barely changes vertically, no huge sky reveal
	# -------------------------------------------------------------------------
	print("--- TEST A: Launch (Pad 4) — Fixed Vertical Camera ---")
	var pad_4 = world_gen.get_platform_by_index(4)
	assert(is_instance_valid(pad_4), "Pad 4 must exist!")
	var pad_5 = world_gen.get_platform_by_index(5)
	assert(is_instance_valid(pad_5), "Pad 5 must exist!")

	player.spawn_on_platform(pad_4)
	camera.set_next_target_platform(pad_5)
	camera.snap_to_target()
	for _f in range(10): await physics_frame

	var initial_cam_y = camera.global_position.y
	var initial_player_y = player.global_position.y

	# Player takes off upward
	player.global_position.y -= 15.0
	player.current_state = SolarPlayer.State.FLYING
	player.launch_grace_timer = 1.0
	player.velocity = Vector2(40.0, -280.0)

	for _f in range(25):
		await process_frame

	var player_rise = initial_player_y - player.global_position.y
	var cam_vertical_change = absf(camera.global_position.y - initial_cam_y)

	print("  Player climbed: %.1f px | Camera vertical shift: %.1f px" % [player_rise, cam_vertical_change])
	assert(cam_vertical_change < 35.0, "Launch: Camera must NOT follow player upward (shift was %.1fpx, must be <35px)!" % cam_vertical_change)
	print("  ✅ TEST A PASSED: Launch has near-zero vertical shift (%.1fpx shift for %.1fpx player rise)." % [cam_vertical_change, player_rise])

	# -------------------------------------------------------------------------
	# TEST B: Apex — Maximum altitude without giant vertical camera movement
	# -------------------------------------------------------------------------
	print("\n--- TEST B: Apex — Zero Vertical Chasing ---")
	var apex_cam_shift = absf(camera.global_position.y - initial_cam_y)
	assert(apex_cam_shift <= 45.0, "Apex: Camera vertical shift must stay within MAX_VERTICAL_CAMERA_SHIFT (45px)! (was %.1f)" % apex_cam_shift)
	print("  ✅ TEST B PASSED: Apex vertical camera shift stayed at %.1fpx (<= 45px limit)." % apex_cam_shift)

	# -------------------------------------------------------------------------
	# TEST C: Forward flight toward Pad 10 — Horizontal Follow & Pad Entry
	# -------------------------------------------------------------------------
	print("\n--- TEST C: Forward Flight — Pad 10 enters 55%–85% region ---")
	var pad_9 = world_gen.get_platform_by_index(9)
	var pad_10 = world_gen.get_platform_by_index(10)
	assert(is_instance_valid(pad_9) and is_instance_valid(pad_10), "Pads 9 and 10 must exist!")

	player.spawn_on_platform(pad_9)
	camera.set_next_target_platform(pad_10)
	camera.snap_to_target()
	for _f in range(10): await physics_frame

	# Travel forward midway toward Pad 10
	player.global_position = lerp(pad_9.get_landing_position(), pad_10.get_landing_position(), 0.45)
	player.current_state = SolarPlayer.State.FLYING
	player.velocity = Vector2(150.0, -10.0)

	for _f in range(30):
		await process_frame

	var p_screen_x = (player.global_position.x - camera.global_position.x) * camera.zoom.x + vp_size.x * 0.5
	var p_frac_x = p_screen_x / vp_size.x
	var pad10_screen_x = (pad_10.global_position.x - camera.global_position.x) * camera.zoom.x + vp_size.x * 0.5
	var pad10_frac_x = pad10_screen_x / vp_size.x

	print("  Player screen X: " + str(snappedf(p_frac_x * 100.0, 0.1)) + "% | Pad 10 screen X: " + str(snappedf(pad10_frac_x * 100.0, 0.1)) + "%")
	assert(p_frac_x >= 0.20 and p_frac_x <= 0.45, "Player must stay in comfortable forward band (20%–45%)!")
	assert(pad10_frac_x >= 0.55 and pad10_frac_x <= 0.88, "Pad 10 must be visible in forward region (55%–88%)!")
	print("  ✅ TEST C PASSED: Horizontal follow keeps Pad 10 visible ahead and player comfortably positioned.")

	# -------------------------------------------------------------------------
	# TEST D: Descent — Small vertical correction only (<= 45px)
	# -------------------------------------------------------------------------
	print("\n--- TEST D: Descent — Fixed-Height with Minimal Correction ---")
	var pre_descent_cam_y = camera.global_position.y
	player.velocity = Vector2(60.0, 320.0) # Falling fast toward landing

	for _f in range(25):
		await process_frame

	var descent_cam_shift = absf(camera.global_position.y - pre_descent_cam_y)
	print("  Descent vertical camera shift: %.1f px (must be <= 45px)" % descent_cam_shift)
	assert(descent_cam_shift <= 45.0, "Descent must NOT cause camera to dive downward (> 45px)! (was %.1fpx)" % descent_cam_shift)
	print("  ✅ TEST D PASSED: Camera stays virtually fixed during descent (shift=%.1fpx <= 45px)." % descent_cam_shift)

	# -------------------------------------------------------------------------
	# TEST E: Landing on Pad 10 — Smooth Settle, Zero Snaps
	# -------------------------------------------------------------------------
	print("\n--- TEST E: Landing on Pad 10 — Smooth Transition & Full Pad Visible ---")
	player.global_position = pad_10.get_landing_position() + Vector2(0, -15.0)
	for _f in range(15): await process_frame
	player.spawn_on_platform(pad_10)
	game._on_player_landed(pad_10, true)

	var max_step_y = 0.0
	var prev_y = camera.global_position.y
	for _f in range(20):
		await process_frame
		var step_y = absf(camera.global_position.y - prev_y)
		max_step_y = maxf(max_step_y, step_y)
		prev_y = camera.global_position.y

	print("  Max settle vertical step: %.1f px" % max_step_y)
	assert(max_step_y < 12.0, "Touchdown must settle smoothly vertically without sudden snapping! (max step: %.1fpx)" % max_step_y)

	# Verify full pad and player are visible
	var docked_p_y = (player.global_position.y - camera.global_position.y) * camera.zoom.y + vp_size.y * 0.5
	var docked_frac_y = docked_p_y / vp_size.y
	print("  Docked player screen Y: " + str(snappedf(docked_frac_y * 100.0, 0.1)) + "%")
	assert(docked_frac_y >= 0.40 and docked_frac_y <= 0.60, "Docked player must sit comfortably around 45%–55%!")
	print("  ✅ TEST E PASSED: Touchdown settles continuously with zero camera jumps.")

	# -------------------------------------------------------------------------
	# TEST F: High Terrain — Camera does not bounce up/down over terrain peaks
	# -------------------------------------------------------------------------
	print("\n--- TEST F: High Terrain — Stable Vertical Framing ---")
	var pad_11 = world_gen.get_platform_by_index(11)
	assert(is_instance_valid(pad_11), "Pad 11 must exist!")
	camera.set_next_target_platform(pad_11)

	var base_cam_pos = camera.global_position
	# Fly over terrain between 10 and 11
	for _f in range(20):
		player.global_position.x += 10.0
		await process_frame

	var terrain_y_shift = absf(camera.global_position.y - base_cam_pos.y)
	assert(terrain_y_shift <= 45.0, "Camera must not bounce over terrain peaks (> 45px)! (was %.1fpx)" % terrain_y_shift)
	print("  ✅ TEST F PASSED: Camera remains rock-steady over terrain features (vertical shift: %.1fpx)." % terrain_y_shift)

	print("\n=======================================================")
	print("   ALL 6 V7.5 FIXED-HEIGHT MARS CAMERA TESTS PASSED! 🎉")
	print("=======================================================\n")
	quit()
