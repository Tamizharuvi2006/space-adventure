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
	print("=== RUNNING V5.7 CAMERA SUITE: PLAYER-STABLE WORLD-TRACKING ===")
	call_deferred("_run_suite")

func _ensure_flying(main: SolarMain, hud: SolarHUD, player: SolarPlayer) -> void:
	main.current_state = SolarMain.GameState.PLAYING
	player.set_control_enabled(true)
	player.current_state = SolarPlayer.State.FLYING
	player.last_docked_platform = null
	player.set_physics_process(false)
	hud.game_over_menu.visible = false
	hud.gameplay_hud.visible = true

func _run_suite() -> void:
	var packed = load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate() as SolarMain
	root.add_child(main)
	
	var hud = main.get_node("HUD") as SolarHUD
	var player = main.get_node("Player") as SolarPlayer
	var world_gen = main.get_node("WorldGenerator") as WorldGenerator
	var camera = main.get_node("Camera2D") as SolarCamera
	
	await create_timer(0.3).timeout
	
	hud.emit_signal("play_game_requested")
	while main.current_state != SolarMain.GameState.PLAYING:
		await create_timer(0.05).timeout
	await create_timer(0.2).timeout
	
	while world_gen.next_platform_idx <= 10:
		world_gen.spawn_next_route_pad()
	
	var pad_0 = world_gen.get_platform_by_index(0)
	var pad_1 = world_gen.get_platform_by_index(1)
	assert(pad_0 != null and pad_1 != null, "Pads 0 and 1 must exist!")
	var view_size = root.get_viewport().get_visible_rect().size
	
	print("\n=======================================================")
	print("PART 1: NUMERICAL DEBUG TEST (Player World vs Screen)")
	print("=======================================================")
	
	# 1. STATIONARY ON PAD
	player.spawn_on_platform(pad_0)
	camera.snap_to_target()
	for _i in range(20):
		await create_timer(0.02).timeout
	
	var p_screen = (player.global_position - camera.global_position) + view_size * 0.5
	print("\n[1. STATIONARY]")
	print("  PLAYER WORLD: %s" % player.global_position)
	print("  CAMERA WORLD: %s" % camera.global_position)
	print("  PLAYER SCREEN: %s (Center = %s)" % [p_screen, view_size * 0.5])
	assert(absf(p_screen.x - view_size.x * 0.5) < 10.0, "Player must be centered horizontally")
	assert(absf(p_screen.y - (view_size.y * 0.5 - camera.default_vertical_offset)) < 15.0, "Player must be at rest height")
	await _capture("test_v5_7_A_stationary.png")
	
	# 2. MOVE RIGHT 500 PX
	print("\n[2. MOVE RIGHT 500 PX]")
	_ensure_flying(main, hud, player)
	var start_pos = player.global_position
	for _i in range(40):
		player.velocity = Vector2(300.0, 0.0)
		player.global_position.x += 300.0 * 0.02
		await create_timer(0.02).timeout
	
	p_screen = (player.global_position - camera.global_position) + view_size * 0.5
	var pad0_screen = (pad_0.global_position - camera.global_position) + view_size * 0.5
	print("  PLAYER WORLD: %s (delta X = +%.1f)" % [player.global_position, player.global_position.x - start_pos.x])
	print("  CAMERA WORLD: %s" % camera.global_position)
	print("  PLAYER SCREEN: %s" % p_screen)
	print("  PAD 0 SCREEN: %s (World moved LEFT)" % pad0_screen)
	assert(player.global_position.x > start_pos.x + 200.0, "Player moved right in world")
	assert(absf(p_screen.x - view_size.x * 0.5) < 60.0, "Player screen X must remain near center!")
	assert(pad0_screen.x < view_size.x * 0.5 - 150.0, "Pad 0 must have moved left on screen!")
	await _capture("test_v5_7_B_right_flight.png")
	
	# 3. RISE 500 PX (UPWARD FLIGHT)
	print("\n[3. RISE 500 PX (UPWARD)]")
	_ensure_flying(main, hud, player)
	var pre_climb_p_y = player.global_position.y
	for _i in range(55):
		player.velocity = Vector2(50.0, -320.0)
		player.global_position += player.velocity * 0.02
		await create_timer(0.02).timeout
	
	p_screen = (player.global_position - camera.global_position) + view_size * 0.5
	pad0_screen = (pad_0.global_position - camera.global_position) + view_size * 0.5
	print("  PLAYER WORLD: %s (delta Y = %.1f)" % [player.global_position, player.global_position.y - pre_climb_p_y])
	print("  CAMERA WORLD: %s" % camera.global_position)
	print("  PLAYER SCREEN: %s" % p_screen)
	print("  PAD 0 SCREEN: %s (Ground moved DOWN)" % pad0_screen)
	assert(player.global_position.y < pre_climb_p_y - 300.0, "Player rose in world")
	assert(absf(p_screen.y - view_size.y * 0.5) < 70.0, "Player screen Y must remain near center!")
	assert(pad0_screen.y > view_size.y - 20.0, "Pad 0 / Ground moved DOWN and exited screen bottom!")
	await _capture("test_v5_7_C_upward_flight.png")
	
	# 4. DESCEND (DOWNWARD FLIGHT TOWARD PAD 1)
	print("\n[4. DESCEND (DOWNWARD FLIGHT)]")
	_ensure_flying(main, hud, player)
	player.global_position = Vector2(pad_1.global_position.x - 220.0, pad_1.global_position.y - 280.0)
	camera.global_position = player.global_position + Vector2(0.0, camera.default_vertical_offset)
	for _i in range(35):
		player.velocity = Vector2(140.0, 240.0)
		player.global_position += player.velocity * 0.02
		await create_timer(0.02).timeout
	
	p_screen = (player.global_position - camera.global_position) + view_size * 0.5
	var pad1_screen = (pad_1.global_position - camera.global_position) + view_size * 0.5
	print("  PLAYER WORLD: %s" % player.global_position)
	print("  CAMERA WORLD: %s" % camera.global_position)
	print("  PLAYER SCREEN: %s" % p_screen)
	print("  PAD 1 SCREEN: %s (Landing Pad moved UP into view)" % pad1_screen)
	assert(absf(p_screen.x - view_size.x * 0.5) < 60.0, "Player screen X must remain near center!")
	assert(absf(p_screen.y - view_size.y * 0.5) < 70.0, "Player screen Y must remain near center!")
	assert(pad1_screen.y > 0 and pad1_screen.y < view_size.y, "Pad 1 must be on-screen vertically!")
	await _capture("test_v5_7_D_downward_flight.png")
	
	# 5. LANDING ON PAD 1
	print("\n[5. LANDING ON PAD 1]")
	player.spawn_on_platform(pad_1)
	player.velocity = Vector2.ZERO
	for _i in range(25):
		await create_timer(0.02).timeout
	
	p_screen = (player.global_position - camera.global_position) + view_size * 0.5
	pad1_screen = (pad_1.global_position - camera.global_position) + view_size * 0.5
	print("  PLAYER WORLD: %s" % player.global_position)
	print("  CAMERA WORLD: %s" % camera.global_position)
	print("  PLAYER SCREEN: %s" % p_screen)
	print("  PAD 1 SCREEN: %s" % pad1_screen)
	assert(absf(p_screen.x - view_size.x * 0.5) < 15.0, "Player landed centered")
	assert(pad1_screen.y > view_size.y * 0.45 and pad1_screen.y < view_size.y * 0.70, "Pad 1 framed comfortably in lower-middle")
	await _capture("test_v5_7_E_landing.png")
	
	# 6. MISSED LANDING (FALLING TOWARD CANYON DEPTHS)
	print("\n[6. MISSED LANDING]")
	_ensure_flying(main, hud, player)
	player.global_position = Vector2(pad_1.global_position.x + 220.0, pad_1.global_position.y + 60.0)
	for _i in range(35):
		player.velocity = Vector2(30.0, 220.0)
		player.global_position += player.velocity * 0.02
		await create_timer(0.02).timeout
	
	p_screen = (player.global_position - camera.global_position) + view_size * 0.5
	pad1_screen = (pad_1.global_position - camera.global_position) + view_size * 0.5
	print("  PLAYER WORLD: %s" % player.global_position)
	print("  CAMERA WORLD: %s" % camera.global_position)
	print("  PLAYER SCREEN: %s" % p_screen)
	print("  PAD 1 SCREEN: %s (Pad moved UP out of frame)" % pad1_screen)
	assert(absf(p_screen.x - view_size.x * 0.5) < 60.0, "Player continues tracked near center")
	assert(absf(p_screen.y - view_size.y * 0.5) < 70.0, "Camera continues following player down")
	assert(pad1_screen.y < view_size.y * 0.5, "Pad 1 moved UP on screen as player plunged!")
	await _capture("test_v5_7_F_missed_landing.png")
	
	print("\n=======================================================")
	print("🎉 ALL V5.7 REQUIREMENTS FULLY VERIFIED & PASSED!")
	print("=======================================================")
	quit()

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img = root.get_viewport().get_texture().get_image()
	var dest = ARTIFACT_DIR + "/" + filename
	img.save_png(dest)
