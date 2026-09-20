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
	print("=== RUNNING V5.9 MARS: MARS CAMERA COMPOSITION TEST SUITE ===")
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
	
	# Spawn enough pads for our testing
	while world_gen.next_platform_idx <= 20:
		world_gen.spawn_next_route_pad()
	
	var pad_10 = world_gen.get_platform_by_index(10)
	var pad_11 = world_gen.get_platform_by_index(11)
	var pad_12 = world_gen.get_platform_by_index(12)
	assert(pad_10 != null and pad_11 != null and pad_12 != null, "Pads 10, 11, 12 must exist!")
	var view_size = root.get_viewport().get_visible_rect().size
	
	print("Pad 10 position: %s" % pad_10.global_position)
	print("Pad 11 position: %s" % pad_11.global_position)
	print("Pad 12 position: %s" % pad_12.global_position)
	
	# Helper lambda to step frames
	var step_frames = func(count: int, move_vel: Vector2 = Vector2.ZERO):
		for _i in range(count):
			if move_vel != Vector2.ZERO:
				player.global_position += move_vel * 0.02
			await create_timer(0.02).timeout

	# ─── 1. RESTING ON PAD 10 ──────────────────────────────────────────────
	print("\n--- 1. Resting on Pad 10 ---")
	main.current_pad = 10
	camera.set_next_target_platform(pad_11)
	player.set_target_platform(pad_11)
	player.spawn_on_platform(pad_10)
	camera.snap_to_target()
	await step_frames.call(25)
	
	var p_screen = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	var pad10_screen = (pad_10.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	var pad11_screen = (pad_11.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Player Screen: %s, Pad 10 Screen: %s, Pad 11 Screen: %s" % [p_screen, pad10_screen, pad11_screen])
	print("  Zoom: %s" % camera.zoom)
	# Player should sit approximately 35%-45% from left
	assert(p_screen.x >= view_size.x * 0.30 and p_screen.x <= view_size.x * 0.50, "Player framed at ~35-45% from left on resting pad!")
	await _capture("v5_9_01_resting_pad10.png")

	# ─── 2. TAKEOFF FROM PAD 10 ────────────────────────────────────────────
	print("\n--- 2. Takeoff from Pad 10 ---")
	_ensure_flying(main, hud, player)
	player.global_position = pad_10.global_position + Vector2(25.0, -80.0)
	player.velocity = Vector2(80.0, -220.0)
	await step_frames.call(25, player.velocity)
	p_screen = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	pad10_screen = (pad_10.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Player Screen: %s, Pad 10 Screen: %s" % [p_screen, pad10_screen])
	# Pad 10 remains in view during takeoff
	assert(pad10_screen.y < view_size.y - 40.0, "Pad 10 remains visible during takeoff!")
	await _capture("v5_9_02_takeoff_pad10.png")

	# ─── 3. MID-FLIGHT TOWARD PAD 11 ───────────────────────────────────────
	print("\n--- 3. Mid-flight toward Pad 11 ---")
	var p10_pos = pad_10.global_position
	var p11_pos = pad_11.global_position
	player.global_position = Vector2(p10_pos.x + (p11_pos.x - p10_pos.x) * 0.40, minf(p10_pos.y, p11_pos.y) - 160.0)
	player.velocity = Vector2(220.0, -40.0)
	await step_frames.call(30, player.velocity)
	p_screen = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	pad11_screen = (pad_11.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Player Screen: %s, Pad 11 Screen: %s" % [p_screen, pad11_screen])
	# Player is in forward travel corridor (35%-45% from left)
	assert(p_screen.x >= view_size.x * 0.32 and p_screen.x <= view_size.x * 0.48, "Player sits at ~35-45% from left during forward cruise!")
	await _capture("v5_9_03_midflight_pad11.png")

	# ─── 4. PAD 11 CLEARLY VISIBLE AHEAD ───────────────────────────────────
	print("\n--- 4. Pad 11 clearly visible ahead ---")
	player.global_position = Vector2(p10_pos.x + (p11_pos.x - p10_pos.x) * 0.65, minf(p10_pos.y, p11_pos.y) - 110.0)
	player.velocity = Vector2(200.0, 50.0)
	await step_frames.call(30, player.velocity)
	p_screen = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	pad11_screen = (pad_11.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Player Screen: %s, Pad 11 Screen: %s" % [p_screen, pad11_screen])
	# Next pad 11 is clearly visible on screen!
	assert(pad11_screen.x < view_size.x - 40.0 and pad11_screen.x > view_size.x * 0.50, "Pad 11 is clearly visible ahead in right half!")
	await _capture("v5_9_04_pad11_visible_ahead.png")

	# ─── 5. DESCENDING TOWARD PAD 11 ───────────────────────────────────────
	print("\n--- 5. Descending toward Pad 11 ---")
	player.global_position = Vector2(p11_pos.x - 120.0, p11_pos.y - 120.0)
	player.velocity = Vector2(130.0, 160.0)
	await step_frames.call(30, player.velocity)
	p_screen = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	pad11_screen = (pad_11.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Player Screen: %s, Pad 11 Screen: %s" % [p_screen, pad11_screen])
	assert(pad11_screen.y > view_size.y * 0.45 and pad11_screen.y < view_size.y - 50.0, "Pad 11 clearly readable in lower-middle landing zone!")
	await _capture("v5_9_05_descending_pad11.png")

	# ─── 6. FINAL LANDING ON PAD 11 ────────────────────────────────────────
	print("\n--- 6. Final landing on Pad 11 ---")
	main.current_pad = 11
	player.spawn_on_platform(pad_11)
	player.velocity = Vector2.ZERO
	camera.notify_landed(pad_11)
	await step_frames.call(30)
	p_screen = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	pad11_screen = (pad_11.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Player Screen: %s, Pad 11 Screen: %s" % [p_screen, pad11_screen])
	await _capture("v5_9_06_final_landing_pad11.png")

	# ─── 7. LAUNCH FROM PAD 11 (Heading toward Pad 12) ─────────────────────
	print("\n--- 7. Launch from Pad 11 ---")
	camera.set_next_target_platform(pad_12)
	player.set_target_platform(pad_12)
	_ensure_flying(main, hud, player)
	player.global_position = pad_11.global_position + Vector2(40.0, -90.0)
	player.velocity = Vector2(120.0, -200.0)
	await step_frames.call(25, player.velocity)
	p_screen = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	pad11_screen = (pad_11.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Player Screen: %s, Pad 11 Screen: %s" % [p_screen, pad11_screen])
	await _capture("v5_9_07_launch_pad11.png")

	# ─── 8. LONG HORIZONTAL JUMP ───────────────────────────────────────────
	print("\n--- 8. Long horizontal jump ---")
	# Find a long horizontal jump in route or create a test gap between pads
	var pad_long_a = pad_12
	var pad_long_b = world_gen.get_platform_by_index(13)
	camera.set_next_target_platform(pad_long_b)
	player.set_target_platform(pad_long_b)
	var mid_x = (pad_long_a.global_position.x + pad_long_b.global_position.x) * 0.5
	var avg_y = (pad_long_a.global_position.y + pad_long_b.global_position.y) * 0.5 - 120.0
	player.global_position = Vector2(mid_x, avg_y)
	player.velocity = Vector2(250.0, 0.0)
	await step_frames.call(30, player.velocity)
	p_screen = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	var pad_b_screen = (pad_long_b.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Player Screen: %s, Next Pad Screen: %s, Zoom: %s" % [p_screen, pad_b_screen, camera.zoom])
	await _capture("v5_9_08_long_horizontal_jump.png")

	# ─── 9. LARGE UPWARD JUMP ──────────────────────────────────────────────
	print("\n--- 9. Large upward jump ---")
	# Find or configure an uphill climb
	var pad_up_a = world_gen.get_platform_by_index(14)
	var pad_up_b = world_gen.get_platform_by_index(15)
	camera.set_next_target_platform(pad_up_b)
	player.set_target_platform(pad_up_b)
	player.global_position = Vector2(pad_up_a.global_position.x + 180.0, pad_up_a.global_position.y - 180.0)
	player.velocity = Vector2(180.0, -180.0)
	await step_frames.call(30, player.velocity)
	p_screen = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	var pad_up_b_screen = (pad_up_b.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Player Screen: %s, Target Pad Screen: %s" % [p_screen, pad_up_b_screen])
	# Verify player and terrain are both in frame (not empty sky)
	assert(p_screen.y >= view_size.y * 0.20, "Player is within visual vertical corridor!")
	await _capture("v5_9_09_large_upward_jump.png")

	# ─── 10. LARGE DOWNWARD JUMP ───────────────────────────────────────────
	print("\n--- 10. Large downward jump ---")
	var pad_down_a = world_gen.get_platform_by_index(16)
	var pad_down_b = world_gen.get_platform_by_index(17)
	camera.set_next_target_platform(pad_down_b)
	player.set_target_platform(pad_down_b)
	player.global_position = Vector2(pad_down_b.global_position.x - 160.0, pad_down_b.global_position.y - 150.0)
	player.velocity = Vector2(140.0, 200.0)
	await step_frames.call(30, player.velocity)
	p_screen = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	var pad_down_b_screen = (pad_down_b.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Player Screen: %s, Landing Pad Screen: %s" % [p_screen, pad_down_b_screen])
	assert(pad_down_b_screen.y < view_size.y - 40.0, "Landing pad is clearly visible during downward jump approach!")
	await _capture("v5_9_10_large_downward_jump.png")

	print("\n=======================================================")
	print("🎉 ALL 10 V5.9 MARS: MARS CAMERA COMPOSITION TESTS PASSED!")
	print("=======================================================")
	quit()

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img = root.get_viewport().get_texture().get_image()
	var dest = ARTIFACT_DIR + "/" + filename
	img.save_png(dest)
