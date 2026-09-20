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
	print("=== RUNNING EXPLORE SUN REFERENCE-FAITHFUL CAMERA SUITE ===")
	call_deferred("_run_suite")

func _ensure_playing(main: SolarMain, hud: SolarHUD, player: SolarPlayer) -> void:
	main.current_state = SolarMain.GameState.PLAYING
	player.set_control_enabled(true)
	player.current_state = SolarPlayer.State.FLYING
	hud.game_over_menu.visible = false
	hud.gameplay_hud.visible = true

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
	
	# Pre-spawn pads up to 25
	while world_gen.next_platform_idx <= 25:
		world_gen.spawn_next_route_pad()
	
	var pad_20 = world_gen.get_platform_by_index(20)
	var pad_21 = world_gen.get_platform_by_index(21)
	assert(pad_20 != null and pad_21 != null, "Pads 20 and 21 must exist!")
	var view_size = root.get_viewport().get_visible_rect().size

	print("\n--- TEST A: PLAYER SITTING ON PAD 20 ---")
	main.current_state = SolarMain.GameState.PLAYING
	player.set_control_enabled(true)
	player.spawn_on_platform(pad_20)
	main.current_pad = 20
	main._update_target_platform(21)
	camera.global_position = player.global_position + Vector2(0.0, camera.default_vertical_offset)
	for _i in range(25):
		await create_timer(0.02).timeout
	print("  Player Pos: %s, Camera Pos: %s" % [player.global_position, camera.global_position])
	assert(absf(camera.global_position.x - player.global_position.x) < 40.0, "Camera should be centered on player horizontally")
	assert(absf(camera.global_position.y - (player.global_position.y + camera.default_vertical_offset)) < 25.0, "Camera should be comfortably framed on player vertically")
	await _capture("ref_cam_test_A_docked_pad20.png")
	print("  ✅ TEST A (Sitting on Pad 20) PASSED!")

	print("\n--- TEST B: VERTICAL TAKEOFF (Camera Follows Upward) ---")
	_ensure_playing(main, hud, player)
	var initial_cam_y = camera.global_position.y
	player.global_position = pad_20.global_position + Vector2(0.0, -120.0)
	for _i in range(30):
		player.velocity = Vector2(0.0, -260.0)
		player.global_position.y -= 260.0 * 0.02
		await create_timer(0.02).timeout
	print("  Initial Cam Y: %.1f, New Cam Y: %.1f, Player Y: %.1f" % [initial_cam_y, camera.global_position.y, player.global_position.y])
	assert(camera.global_position.y < initial_cam_y - 80.0, "Camera MUST smoothly follow player upward during ascent!")
	await _capture("ref_cam_test_B_vertical_takeoff.png")
	print("  ✅ TEST B (Camera Follows Upward) PASSED!")

	print("\n--- TEST C: HORIZONTAL FLIGHT (Camera Follows Horizontally) ---")
	_ensure_playing(main, hud, player)
	var initial_cam_x = camera.global_position.x
	player.global_position.y = pad_20.global_position.y - 180.0
	for _i in range(30):
		player.velocity = Vector2(300.0, 0.0)
		player.global_position.x += 300.0 * 0.02
		await create_timer(0.02).timeout
	print("  Initial Cam X: %.1f, New Cam X: %.1f, Player X: %.1f" % [initial_cam_x, camera.global_position.x, player.global_position.x])
	assert(camera.global_position.x > initial_cam_x + 120.0, "Camera MUST smoothly follow player horizontally!")
	await _capture("ref_cam_test_C_horizontal_flight.png")
	print("  ✅ TEST C (Horizontal Follow) PASSED!")

	print("\n--- TEST D: HIGH ALTITUDE (Camera Follows High Altitude) ---")
	_ensure_playing(main, hud, player)
	player.global_position = Vector2(pad_20.global_position.x + 350.0, pad_20.global_position.y - 450.0)
	for _i in range(35):
		player.velocity = Vector2(100.0, -20.0)
		await create_timer(0.02).timeout
	print("  Player Y: %.1f, Camera Y: %.1f" % [player.global_position.y, camera.global_position.y])
	assert(camera.global_position.y < pad_20.global_position.y - 350.0, "Camera MUST follow high altitude continuously!")
	await _capture("ref_cam_test_D_high_altitude.png")
	print("  ✅ TEST D (High Altitude Tracking) PASSED!")

	print("\n--- TEST E: DESCENT (Camera Follows Downward) ---")
	_ensure_playing(main, hud, player)
	var high_cam_y = camera.global_position.y
	player.global_position = Vector2(pad_20.global_position.x + 450.0, pad_20.global_position.y - 280.0)
	for _i in range(35):
		player.velocity = Vector2(120.0, 160.0)
		player.global_position += player.velocity * 0.02
		await create_timer(0.02).timeout
	print("  High Cam Y: %.1f, Descent Cam Y: %.1f, Player Y: %.1f" % [high_cam_y, camera.global_position.y, player.global_position.y])
	assert(camera.global_position.y > high_cam_y + 120.0, "Camera MUST smoothly follow downward during descent!")
	await _capture("ref_cam_test_E_descent_downward.png")
	print("  ✅ TEST E (Descent Follow Downward) PASSED!")

	print("\n--- TEST F: APPROACHING PAD 21 (Pad 21 Naturally Enters Viewport) ---")
	_ensure_playing(main, hud, player)
	player.global_position = pad_21.global_position + Vector2(-260.0, -120.0)
	for _i in range(30):
		player.velocity = Vector2(90.0, 50.0)
		await create_timer(0.02).timeout
	var pad_21_screen = (pad_21.global_position - camera.global_position) + view_size * 0.5
	print("  Pad 21 Screen Pos: %s in Viewport %s" % [pad_21_screen, view_size])
	assert(pad_21_screen.x > 0 and pad_21_screen.x < view_size.x, "Pad 21 must be on-screen horizontally!")
	assert(pad_21_screen.y > 0 and pad_21_screen.y < view_size.y, "Pad 21 must be on-screen vertically!")
	await _capture("ref_cam_test_F_approach_pad21.png")
	print("  ✅ TEST F (Pad 21 Naturally in Viewport) PASSED!")

	print("\n--- TEST G: MISSED PAD 21 TOWARD TERRAIN (Camera Follows Player Downward) ---")
	_ensure_playing(main, hud, player)
	var pre_fall_cam_y = camera.global_position.y
	player.global_position = pad_21.global_position + Vector2(180.0, -40.0)
	for _i in range(25):
		player.velocity = Vector2(20.0, 120.0)
		player.global_position += player.velocity * 0.02
		await create_timer(0.02).timeout
	print("  Pre-fall Cam Y: %.1f, Current Cam Y: %.1f, Player Y: %.1f" % [pre_fall_cam_y, camera.global_position.y, player.global_position.y])
	assert(camera.global_position.y > pre_fall_cam_y + 30.0, "Camera must continue following player downward even away from pad!")
	await _capture("ref_cam_test_G_missed_pad_camera_follows.png")
	print("  ✅ TEST G (Camera Follows Player Away From Pad) PASSED!")

	print("\n--- TEST H: TERRAIN LANDING VISIBILITY (Landing Location Fully Visible) ---")
	_ensure_playing(main, hud, player)
	player.global_position = pad_21.global_position + Vector2(180.0, 40.0)
	player.velocity = Vector2.ZERO
	for _i in range(25):
		await create_timer(0.02).timeout
	var player_screen = (player.global_position - camera.global_position) + view_size * 0.5
	print("  Player Screen Position on Terrain: %s" % [player_screen])
	assert(player_screen.y >= view_size.y * 0.40 and player_screen.y <= view_size.y * 0.70, "Player on terrain must be clearly visible and framed in viewport!")
	await _capture("ref_cam_test_H_terrain_landing_visible.png")
	print("  ✅ TEST H (Terrain Landing Location Fully Visible) PASSED!")

	print("\n--- TEST I: LAUNCHING AGAIN FROM TERRAIN ---")
	_ensure_playing(main, hud, player)
	for _i in range(25):
		player.velocity = Vector2(120.0, -180.0)
		player.global_position += player.velocity * 0.02
		await create_timer(0.02).timeout
	print("  Relaunch Cam Pos: %s, Player Pos: %s" % [camera.global_position, player.global_position])
	assert(camera.global_position.y < player.global_position.y + 20.0, "Camera tracks new flight trajectory from terrain!")
	await _capture("ref_cam_test_I_relaunch_from_terrain.png")
	print("  ✅ TEST I (Camera Follows Relaunch From Terrain) PASSED!")

	print("\n=======================================================")
	print("🎉 ALL REFERENCE CAMERA SCENARIOS (A THROUGH I) PASSED!")
	print("=======================================================")
	quit()

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img = root.get_viewport().get_texture().get_image()
	var dest = ARTIFACT_DIR + "/" + filename
	img.save_png(dest)
