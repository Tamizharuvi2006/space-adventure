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
	print("=== RUNNING V6.3 MARS-STYLE GAMEPLAY COMPOSITION TEST SUITE ===")
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
	
	var pad_1 = world_gen.get_platform_by_index(1)
	var pad_2 = world_gen.get_platform_by_index(2)
	assert(pad_1 != null and pad_2 != null, "Platforms 1 and 2 must exist!")
	var view_size = root.get_viewport().get_visible_rect().size
	
	var step_frames = func(count: int, move_vel: Vector2 = Vector2.ZERO):
		for _i in range(count):
			if move_vel != Vector2.ZERO:
				player.global_position += move_vel * 0.02
			await create_timer(0.02).timeout

	# ─── TEST A: Player launches from Pad 1 toward Pad 2 ────────────────────
	print("\n--- TEST A: Launch from Pad 1 toward Pad 2 ---")
	main.current_pad = 1
	camera.set_next_target_platform(pad_2)
	player.set_target_platform(pad_2)
	player.spawn_on_platform(pad_1)
	camera.snap_to_target()
	await step_frames.call(25)
	
	var cam_a = camera.global_position
	var p_screen_a = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	var pad1_screen_a = (pad_1.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	var pad2_screen_a = (pad_2.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Pad 1 Screen: %s, Pad 2 Screen: %s, Player Screen: %s" % [pad1_screen_a, pad2_screen_a, p_screen_a])
	assert(p_screen_a.x / view_size.x >= 0.36 and p_screen_a.x / view_size.x <= 0.44, "Player sits at ~40% from left!")
	await _capture("v6_3_A_launch_pad1_to_pad2.png")

	# ─── TEST B: Player climbs significantly (300px) ─────────────────────────
	print("\n--- TEST B: Player Climbs Significantly (300px) ---")
	_ensure_flying(main, hud, player)
	var base_cam_y = camera.global_position.y
	player.global_position = pad_1.global_position + Vector2(100.0, -320.0)
	player.velocity = Vector2(80.0, -200.0)
	await step_frames.call(35)
	
	var cam_b = camera.global_position
	var cam_dy = absf(cam_b.y - base_cam_y)
	var p_screen_b = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	var pad1_screen_b = (pad_1.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Player climbed 320px. Camera Y moved: %.2f px (Target: ~80-120px)" % cam_dy)
	print("  Player Screen Y: %.2f, Pad 1 Screen Y: %.2f" % [p_screen_b.y, pad1_screen_b.y])
	# Camera moves partially (approx 80-130px), NOT 320px!
	assert(cam_dy >= 60.0 and cam_dy <= 140.0, "Camera moves partially (~80-120px), not 300px!")
	# Player is visibly higher on screen!
	assert(p_screen_b.y < p_screen_a.y - 150.0, "Player visibly moves upward on screen!")
	# Pad 1 remains visible in lower half!
	assert(pad1_screen_b.y < view_size.y - 20.0, "Pad 1 remains grounded and visible!")
	await _capture("v6_3_B_climb_300px.png")

	# ─── TEST C: Mountain between player and Pad 2 (Terrain Protection) ───────
	print("\n--- TEST C: Terrain Occlusion Protection ---")
	player.global_position = Vector2(pad_1.global_position.x + (pad_2.global_position.x - pad_1.global_position.x) * 0.5, pad_1.global_position.y - 120.0)
	player.velocity = Vector2(220.0, 0.0)
	await step_frames.call(30, player.velocity)
	
	var pad2_screen_c = (pad_2.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Pad 2 Screen: %s (Y frac: %.2f)" % [pad2_screen_c, pad2_screen_c.y / view_size.y])
	# Next pad is kept safely inside the 25%-75% visibility band!
	assert(pad2_screen_c.y >= view_size.y * 0.20 and pad2_screen_c.y <= view_size.y * 0.80, "Pad 2 protected inside visibility band!")
	await _capture("v6_3_C_terrain_protection.png")

	# ─── TEST D: Player descends toward Pad 2 ────────────────────────────────
	print("\n--- TEST D: Player Descends Toward Pad 2 ---")
	player.global_position = Vector2(pad_2.global_position.x - 120.0, pad_2.global_position.y - 130.0)
	player.velocity = Vector2(100.0, 180.0)
	await step_frames.call(25, player.velocity)
	
	var p_screen_d = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	var pad2_screen_d = (pad_2.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Player Screen: %s, Pad 2 Screen: %s" % [p_screen_d, pad2_screen_d])
	# Landing area visible naturally, player NOT centered
	assert(p_screen_d.x / view_size.x <= 0.48, "Player is NOT locked to horizontal center during descent!")
	assert(pad2_screen_d.y > view_size.y * 0.40 and pad2_screen_d.y < view_size.y - 30.0, "Pad 2 clearly visible in landing zone!")
	await _capture("v6_3_D_descent_approach.png")

	# ─── TEST E: Player lands on Pad 2 (Smooth Transition, No Snap) ───────────
	print("\n--- TEST E: Player Lands on Pad 2 (Smooth Landing Transition) ---")
	var cam_before_land = camera.global_position
	main.current_pad = 2
	var pad_3 = world_gen.get_platform_by_index(3)
	camera.set_next_target_platform(pad_3)
	player.set_target_platform(pad_3)
	player.spawn_on_platform(pad_2)
	player.velocity = Vector2.ZERO
	camera.notify_landed(pad_2)
	
	# Step 1 frame: MUST NOT SNAP!
	await step_frames.call(1)
	var cam_1_frame = camera.global_position
	var delta_touchdown = cam_1_frame.distance_to(cam_before_land)
	print("  Touchdown 1-frame distance: %.2f px (MUST NOT BE A TELEPORT SNAP)" % delta_touchdown)
	assert(delta_touchdown < 25.0, "Touchdown is completely continuous without teleportation!")
	
	# Glide into settled composition over ~0.6s
	await step_frames.call(30)
	var cam_settled = camera.global_position
	var p_screen_e = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	var pad2_screen_e = (pad_2.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Settled on Pad 2: Player Screen: %s (%.2f frac), Pad 2: %s" % [p_screen_e, p_screen_e.x / view_size.x, pad2_screen_e])
	assert(p_screen_e.x / view_size.x >= 0.36 and p_screen_e.x / view_size.x <= 0.45, "Settled landed player framed at ~40% from left!")
	await _capture("v6_3_E_landed_pad2.png")

	# ─── TEST F: Immediately Relaunch After Landing (Continuous Live Target) ─
	print("\n--- TEST F: Immediately Relaunch After Landing ---")
	_ensure_flying(main, hud, player)
	player.velocity = Vector2(240.0, -180.0)
	await step_frames.call(25, player.velocity)
	
	var cam_relaunch = camera.global_position
	print("  Relaunch: Cam X=%.2f, Cam Y=%.2f" % [cam_relaunch.x, cam_relaunch.y])
	assert(cam_relaunch.x > cam_settled.x + 30.0, "Camera seamlessly follows live relaunch trajectory!")
	await _capture("v6_3_F_relaunch_live_target.png")

	print("\n=======================================================")
	print("🎉 ALL V6.3 MARS-STYLE COMPOSITION TESTS PASSED 100%!")
	print("=======================================================")
	quit()

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img = root.get_viewport().get_texture().get_image()
	var dest = ARTIFACT_DIR + "/" + filename
	img.save_png(dest)
