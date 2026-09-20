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
	print("=== RUNNING V6.1 FIXED-HEIGHT CAMERA TEST SUITE ===")
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
	
	while world_gen.next_platform_idx <= 15:
		world_gen.spawn_next_route_pad()
	
	var pad_10 = world_gen.get_platform_by_index(10)
	var pad_11 = world_gen.get_platform_by_index(11)
	assert(pad_10 != null and pad_11 != null, "Platforms 10 and 11 must exist!")
	var view_size = root.get_viewport().get_visible_rect().size
	
	var step_frames = func(count: int, move_vel: Vector2 = Vector2.ZERO):
		for _i in range(count):
			if move_vel != Vector2.ZERO:
				player.global_position += move_vel * 0.02
			await create_timer(0.02).timeout

	# ─── A. PLAYER RESTING ON PAD 10 ─────────────────────────────────────────
	print("\n--- A. Player Resting on Pad 10 ---")
	main.current_pad = 10
	camera.set_next_target_platform(pad_11)
	player.set_target_platform(pad_11)
	player.spawn_on_platform(pad_10)
	camera.snap_to_target()
	await step_frames.call(25)
	
	var baseline_cam_y = camera.global_position.y
	var p_screen_a = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	var pad10_screen_a = (pad_10.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Camera Y: %.2f, Player Screen: %s, Pad 10 Screen: %s" % [baseline_cam_y, p_screen_a, pad10_screen_a])
	assert(p_screen_a.x / view_size.x >= 0.35 and p_screen_a.x / view_size.x <= 0.45, "Player framed at ~40% from left on resting pad!")
	await _capture("v6_1_A_resting_pad10.png")

	# ─── B. PLAYER RISES VERTICALLY 300PX ────────────────────────────────────
	print("\n--- B. Player Rises Vertically 300px ---")
	_ensure_flying(main, hud, player)
	var resting_pos = player.global_position
	player.global_position = resting_pos + Vector2(0.0, -300.0)
	player.velocity = Vector2(0.0, -180.0)
	await step_frames.call(25)
	
	var cam_y_b = camera.global_position.y
	var p_screen_b = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	var pad10_screen_b = (pad_10.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Camera Y: %.2f (delta: %.2f), Player Screen Y: %.2f, Pad 10 Screen Y: %.2f" % [cam_y_b, cam_y_b - baseline_cam_y, p_screen_b.y, pad10_screen_b.y])
	# Camera Y MUST BE IDENTICAL to baseline!
	assert(is_equal_approx(cam_y_b, baseline_cam_y), "Camera Y MUST BE IDENTICAL when player rises 300px!")
	# Pad 10 MUST BE in the EXACT same screen position!
	assert(absf(pad10_screen_b.y - pad10_screen_a.y) < 1.0, "Pad 10 screen Y remains completely unchanged!")
	# Player is 300px higher on screen!
	assert(p_screen_b.y < p_screen_a.y - 250.0, "Player moved upward on screen!")
	await _capture("v6_1_B_rise_300px.png")

	# ─── C. PLAYER FALLS 300PX (BACK TO LEVEL / LOWER) ───────────────────────
	print("\n--- C. Player Falls 300px ---")
	player.global_position = resting_pos + Vector2(0.0, 100.0)
	player.velocity = Vector2(0.0, 200.0)
	await step_frames.call(25)
	
	var cam_y_c = camera.global_position.y
	var p_screen_c = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	var pad10_screen_c = (pad_10.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Camera Y: %.2f (delta: %.2f), Player Screen Y: %.2f, Pad 10 Screen Y: %.2f" % [cam_y_c, cam_y_c - baseline_cam_y, p_screen_c.y, pad10_screen_c.y])
	# Camera Y MUST STILL BE IDENTICAL!
	assert(is_equal_approx(cam_y_c, baseline_cam_y), "Camera Y MUST BE IDENTICAL when player falls!")
	assert(absf(pad10_screen_c.y - pad10_screen_a.y) < 1.0, "Pad 10 screen Y remains completely unchanged!")
	await _capture("v6_1_C_fall_300px.png")

	# ─── D. PLAYER FLIES RIGHT ───────────────────────────────────────────────
	print("\n--- D. Player Flies Right ---")
	var p10_pos = pad_10.global_position
	var p11_pos = pad_11.global_position
	player.global_position = Vector2(p10_pos.x + 280.0, resting_pos.y)
	player.velocity = Vector2(240.0, 0.0)
	await step_frames.call(30, player.velocity)
	
	var cam_y_d = camera.global_position.y
	var p_screen_d = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	var pad10_screen_d = (pad_10.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Camera Y: %.2f, Player Screen: %s, Pad 10 Screen X: %.2f" % [cam_y_d, p_screen_d, pad10_screen_d.x])
	assert(is_equal_approx(cam_y_d, baseline_cam_y), "Camera Y DOES NOT CHANGE during horizontal flight!")
	assert(pad10_screen_d.x < pad10_screen_a.x - 100.0, "Pad 10 scrolled left naturally as camera tracked right!")
	await _capture("v6_1_D_fly_right.png")

	# ─── E. PLAYER FLIES RIGHT + RISES ───────────────────────────────────────
	print("\n--- E. Player Flies Right + Rises ---")
	player.global_position = Vector2(p10_pos.x + 480.0, resting_pos.y - 200.0)
	player.velocity = Vector2(220.0, -180.0)
	await step_frames.call(30, player.velocity)
	
	var cam_y_e = camera.global_position.y
	var p_screen_e = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Camera Y: %.2f, Player Screen: %s" % [cam_y_e, p_screen_e])
	assert(is_equal_approx(cam_y_e, baseline_cam_y), "Camera Y DOES NOT CHANGE when player flies right + rises!")
	await _capture("v6_1_E_fly_right_rise.png")

	# ─── F. PLAYER FLIES RIGHT + DESCENDS ────────────────────────────────────
	print("\n--- F. Player Flies Right + Descends ---")
	player.global_position = Vector2(p11_pos.x - 160.0, resting_pos.y - 80.0)
	player.velocity = Vector2(160.0, 190.0)
	await step_frames.call(30, player.velocity)
	
	var cam_y_f = camera.global_position.y
	var p_screen_f = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	var pad11_screen_f = (pad_11.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Camera Y: %.2f, Player Screen: %s, Pad 11 Screen: %s" % [cam_y_f, p_screen_f, pad11_screen_f])
	assert(is_equal_approx(cam_y_f, baseline_cam_y), "Camera Y DOES NOT CHANGE when player flies right + descends!")
	await _capture("v6_1_F_fly_right_descend.png")

	# ─── G. LANDS ON NEXT PAD ────────────────────────────────────────────────
	print("\n--- G. Lands on Next Pad (Pad 11) ---")
	main.current_pad = 11
	player.spawn_on_platform(pad_11)
	player.velocity = Vector2.ZERO
	camera.notify_landed(pad_11)
	await step_frames.call(25)
	
	var p_screen_g = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	var pad11_screen_g = (pad_11.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Player Screen: %s (X frac: %.2f), Pad 11 Screen: %s" % [p_screen_g, p_screen_g.x / view_size.x, pad11_screen_g])
	assert(p_screen_g.x / view_size.x >= 0.36 and p_screen_g.x / view_size.x <= 0.46, "Landed player is framed at ~40% with forward space ahead!")
	await _capture("v6_1_G_landing_next_pad.png")

	print("\n=======================================================")
	print("🎉 ALL V6.1 FIXED-HEIGHT CAMERA TESTS PASSED 100%!")
	print("=======================================================")
	quit()

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img = root.get_viewport().get_texture().get_image()
	var dest = ARTIFACT_DIR + "/" + filename
	img.save_png(dest)
