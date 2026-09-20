extends SceneTree

const SunZoneData = preload("res://scripts/planet_data.gd")
const SolarBackground = preload("res://scripts/background.gd")
const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")
const SolarHUD = preload("res://scripts/hud.gd")
const SolarCamera = preload("res://scripts/camera_follow.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")

const ARTIFACT_DIR = "C:/Users/aruvi/.gemini/antigravity-ide/brain/f75eeb4b-bf34-4366-b518-afc1bd64e4d0"

func _init() -> void:
	print("=== RUNNING EXPLORE SUN V5.5 / V5.6 VERIFICATION SUITE ===")
	call_deferred("_run_suite")

func _run_suite() -> void:
	var packed = load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate() as SolarMain
	root.add_child(main)
	
	var hud = main.get_node("HUD") as SolarHUD
	var player = main.get_node("Player") as SolarPlayer
	var world_gen = main.get_node("WorldGenerator") as WorldGenerator
	var bg = main.get_node("Background") as SolarBackground
	var camera = main.get_node("Camera2D") as SolarCamera
	
	await create_timer(0.3).timeout
	
	hud.emit_signal("play_game_requested")
	while main.current_state != SolarMain.GameState.PLAYING:
		await create_timer(0.05).timeout
	await create_timer(0.2).timeout
	
	# Spawn pads up to 25 so Pad 19 and 20 are available
	while world_gen.next_platform_idx <= 25:
		world_gen.spawn_next_route_pad()
	
	var pad_19 = world_gen.get_platform_by_index(19)
	var pad_20 = world_gen.get_platform_by_index(20)
	assert(pad_19 != null and pad_20 != null, "Pads 19 & 20 must exist!")
	var view_size = root.get_viewport().get_visible_rect().size

	print("\n--- TEST CASE 1: STATE A — RESTING ON PAD ---")
	player.spawn_on_platform(pad_19)
	main.current_pad = 19
	main._update_target_platform(20)
	world_gen.update_route_visuals(19)
	for _i in range(30):
		await create_timer(0.02).timeout
	print("  Camera Mode: %s, Zoom: %.3f" % [camera.current_mode, camera.current_zoom_factor])
	assert(camera.current_zoom_factor >= 1.05 and camera.current_zoom_factor <= 1.10, "Resting zoom should be ~1.08")
	await _capture("v5_6_cam_state_A_resting.png")
	print("  ✅ TEST A (Resting) PASSED!")

	print("\n--- TEST CASE 2: STATE B — TAKEOFF ---")
	player.current_state = SolarPlayer.State.FLYING
	player.global_position = pad_19.global_position + Vector2(20.0, -40.0)
	player.velocity = Vector2(140.0, -220.0)
	for _i in range(12):
		player.velocity = Vector2(140.0, -200.0) # hold climbing lift
		await create_timer(0.02).timeout
	print("  Camera Mode: %s, Zoom: %.3f" % [camera.current_mode, camera.current_zoom_factor])
	assert(camera.current_mode == SolarCamera.CameraMode.TAKEOFF, "Mode should be TAKEOFF during launch climb")
	assert(camera.current_zoom_factor <= 1.04, "Takeoff zoom should smoothly widen")
	await _capture("v5_6_cam_state_B_takeoff.png")
	print("  ✅ TEST B (Takeoff) PASSED!")

	print("\n--- TEST CASE 3: STATE C — FAST HORIZONTAL EXPEDITION FLIGHT ---")
	player.current_state = SolarPlayer.State.FLYING
	player.global_position = pad_19.global_position + Vector2(350.0, -80.0)
	for _i in range(25):
		player.velocity = Vector2(340.0, -10.0)
		await create_timer(0.02).timeout
	print("  Camera Mode: %s, Zoom: %.3f" % [camera.current_mode, camera.current_zoom_factor])
	assert(camera.current_mode == SolarCamera.CameraMode.FAST_FLIGHT, "Mode should be FAST_FLIGHT")
	assert(camera.current_zoom_factor >= 0.90 and camera.current_zoom_factor <= 0.98, "Fast flight zoom should be ~0.93-0.96")
	await _capture("v5_6_cam_state_C_fast_flight.png")
	print("  ✅ TEST C (Fast Flight) PASSED!")

	print("\n--- TEST CASE 4: STATE D — HIGH ALTITUDE OVERLOOK ---")
	player.current_state = SolarPlayer.State.FLYING
	player.global_position = pad_19.global_position + Vector2(500.0, -280.0)
	for _i in range(25):
		player.velocity = Vector2(120.0, 0.0)
		await create_timer(0.02).timeout
	print("  Camera Mode: %s, Zoom: %.3f" % [camera.current_mode, camera.current_zoom_factor])
	assert(camera.current_mode == SolarCamera.CameraMode.HIGH_ALTITUDE or camera.current_zoom_factor <= 0.97, "High altitude zoom should be active")
	await _capture("v5_6_cam_state_D_high_altitude.png")
	print("  ✅ TEST D (High Altitude) PASSED!")

	print("\n--- TEST CASE 5: STATE E — DESCENT (Downward Lookahead to Pad 20) ---")
	main.current_state = SolarMain.GameState.PLAYING
	player.set_control_enabled(true)
	player.current_state = SolarPlayer.State.FLYING
	player.global_position = pad_20.global_position + Vector2(-550.0, -200.0)
	for _i in range(20):
		player.velocity = Vector2(160.0, 110.0)
		await create_timer(0.02).timeout
	print("  Camera Mode: %s, Zoom: %.3f, Cam Pos: %s" % [camera.current_mode, camera.current_zoom_factor, camera.global_position])
	assert(camera.current_mode == SolarCamera.CameraMode.DESCENT, "Mode should be DESCENT")
	var pad_screen_pos = (pad_20.global_position - camera.global_position) * camera.zoom.x + view_size * 0.5
	print("  Pad 20 screen position during descent: %s (view_size=%s)" % [pad_screen_pos, view_size])
	assert(pad_screen_pos.y > 0 and pad_screen_pos.y < view_size.y, "Pad 20 MUST be visible on-screen during descent!")
	await _capture("v5_6_cam_state_E_descent.png")
	print("  ✅ TEST E (Descent Framing) PASSED!")

	print("\n--- TEST CASE 6: STATE F — FINAL APPROACH (Player + Pad 20 Framed Together) ---")
	main.current_state = SolarMain.GameState.PLAYING
	player.set_control_enabled(true)
	player.current_state = SolarPlayer.State.FLYING
	player.global_position = pad_20.global_position + Vector2(-80.0, -110.0)
	for _i in range(15):
		player.velocity = Vector2(40.0, 20.0)
		await create_timer(0.02).timeout
	print("  Camera Mode: %s, Zoom: %.3f" % [camera.current_mode, camera.current_zoom_factor])
	assert(camera.current_mode == SolarCamera.CameraMode.FINAL_APPROACH, "Mode should be FINAL_APPROACH")
	pad_screen_pos = (pad_20.global_position - camera.global_position) * camera.zoom.x + view_size * 0.5
	print("  Pad 20 screen position during final approach: %s" % [pad_screen_pos])
	assert(pad_screen_pos.y >= view_size.y * 0.40 and pad_screen_pos.y <= view_size.y * 0.90, "Pad 20 must appear in lower-middle viewport!")
	await _capture("v5_6_cam_state_F_final_approach.png")
	print("  ✅ TEST F (Final Approach Framing) PASSED!")

	print("\n--- TEST CASE 7: STATE G — TOUCHDOWN ON PAD 20 ---")
	main.current_state = SolarMain.GameState.PLAYING
	player.set_control_enabled(true)
	player.spawn_on_platform(pad_20)
	main._on_player_landed(pad_20, true)
	for _i in range(30):
		await create_timer(0.02).timeout
	print("  Camera Mode: %s, Zoom: %.3f" % [camera.current_mode, camera.current_zoom_factor])
	assert(camera.current_zoom_factor >= 1.06 and camera.current_zoom_factor <= 1.10, "Landed zoom should be ~1.08")
	assert(main.current_pad == 20, "Pad 20 progression confirmed!")
	await _capture("v5_6_cam_state_G_touchdown_pad20.png")
	print("  ✅ TEST G (Touchdown on Pad 20) PASSED!")

	print("\n--- TEST CASE 8: MISSED PAD 20 BY 150px (Visual Terrain != Safe Landing) ---")
	# Position player 150px past Pad 20 horizontally, falling into terrain/void
	player.current_state = SolarPlayer.State.FLYING
	player.global_position = pad_20.global_position + Vector2(180.0, 30.0)
	player.velocity = Vector2(40.0, 220.0)
	var death_triggered = false
	for _i in range(80):
		await create_timer(0.02).timeout
		if main.current_state == SolarMain.GameState.GAME_OVER:
			death_triggered = true
			break
	print("  Missed Pad 20 Result: Game State = %s (GAME_OVER=%s)" % [main.current_state, death_triggered])
	assert(death_triggered, "Falling onto terrain away from pad MUST trigger GAME OVER!")
	await _capture("v5_6_test_missed_pad_game_over.png")
	print("  ✅ TEST 8 (Visual Terrain Never Safe / Abyss Death) PASSED!")

	print("\n=======================================================")
	print("🎉 ALL V5.5 / V5.6 VERIFICATION TESTS PASSED PERFECTLY!")
	print("=======================================================")
	quit()

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img = root.get_viewport().get_texture().get_image()
	var dest = ARTIFACT_DIR + "/" + filename
	img.save_png(dest)
