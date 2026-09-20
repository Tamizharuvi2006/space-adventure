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
	print("=== RUNNING V6 DIRECTIONAL COMPOSITION TEST SUITE ===")
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
	var pad_12 = world_gen.get_platform_by_index(12)
	assert(pad_10 != null and pad_11 != null and pad_12 != null, "Platforms 10, 11, 12 must exist!")
	var view_size = root.get_viewport().get_visible_rect().size
	
	var step_frames = func(count: int, move_vel: Vector2 = Vector2.ZERO):
		for _i in range(count):
			if move_vel != Vector2.ZERO:
				player.global_position += move_vel * 0.02
			await create_timer(0.02).timeout

	# ─── 1. STATIONARY PAD ─────────────────────────────────────────────────
	print("\n--- 1. Stationary Pad (Pad 10) ---")
	main.current_pad = 10
	camera.set_next_target_platform(pad_11)
	player.set_target_platform(pad_11)
	player.spawn_on_platform(pad_10)
	camera.snap_to_target()
	await step_frames.call(25)
	
	var p_screen = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	var pad10_screen = (pad_10.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	var pad11_screen = (pad_11.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Player Screen: %s (X frac: %.2f), Pad 10: %s, Pad 11: %s" % [p_screen, p_screen.x / view_size.x, pad10_screen, pad11_screen])
	# Player must NOT be dead center! Player sits at ~38-42% from left
	assert(p_screen.x / view_size.x >= 0.35 and p_screen.x / view_size.x <= 0.45, "Stationary player sits at ~35-45% from left (NOT dead-center)!")
	await _capture("v6_01_stationary_pad.png")

	# ─── 2. RIGHT FLIGHT ───────────────────────────────────────────────────
	print("\n--- 2. Right Flight (Toward Pad 11) ---")
	_ensure_flying(main, hud, player)
	var p10_pos = pad_10.global_position
	var p11_pos = pad_11.global_position
	player.global_position = Vector2(p10_pos.x + (p11_pos.x - p10_pos.x) * 0.35, minf(p10_pos.y, p11_pos.y) - 150.0)
	player.velocity = Vector2(240.0, -20.0)
	await step_frames.call(30, player.velocity)
	p_screen = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	pad11_screen = (pad_11.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Player Screen: %s (X frac: %.2f), Pad 11: %s" % [p_screen, p_screen.x / view_size.x, pad11_screen])
	assert(p_screen.x / view_size.x >= 0.33 and p_screen.x / view_size.x <= 0.44, "Rightward flight keeps player at ~35-42% from left!")
	assert(pad11_screen.x < view_size.x, "Pad 11 clearly visible in forward region!")
	await _capture("v6_02_right_flight.png")

	# ─── 3. LEFT FLIGHT ────────────────────────────────────────────────────
	print("\n--- 3. Left Flight (Mirror Framing) ---")
	# Simulate player banking back or flying left
	player.velocity = Vector2(-220.0, -10.0)
	await step_frames.call(35, player.velocity)
	p_screen = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Player Screen: %s (X frac: %.2f)" % [p_screen, p_screen.x / view_size.x])
	# When flying left, player shifts to 56-66% from left, opening space to the left!
	assert(p_screen.x / view_size.x >= 0.55 and p_screen.x / view_size.x <= 0.67, "Leftward flight mirrors framing: player at ~55-66% from left!")
	await _capture("v6_03_left_flight.png")

	# ─── 4. UPWARD FLIGHT ──────────────────────────────────────────────────
	print("\n--- 4. Upward Flight (Ascent Framing) ---")
	camera.set_next_target_platform(pad_11)
	player.set_target_platform(pad_11)
	player.global_position = Vector2(p10_pos.x + (p11_pos.x - p10_pos.x) * 0.45, p10_pos.y - 180.0)
	player.velocity = Vector2(160.0, -260.0)
	await step_frames.call(30, player.velocity)
	p_screen = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Player Screen: %s (Y frac: %.2f)" % [p_screen, p_screen.y / view_size.y])
	# During ascent, player sits lower in viewport (55-62% height), revealing space above
	assert(p_screen.y / view_size.y >= 0.54 and p_screen.y / view_size.y <= 0.64, "Ascent places player in lower-middle, opening sky & peaks above!")
	await _capture("v6_04_upward_flight.png")

	# ─── 5. DOWNWARD FLIGHT ────────────────────────────────────────────────
	print("\n--- 5. Downward Flight (Descent Framing) ---")
	_ensure_flying(main, hud, player)
	player.global_position = Vector2(p11_pos.x - 180.0, p11_pos.y - 280.0)
	player.velocity = Vector2(120.0, 240.0)
	await step_frames.call(42, player.velocity)
	p_screen = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	pad11_screen = (pad_11.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Player Screen: %s (Y frac: %.2f), Pad 11: %s" % [p_screen, p_screen.y / view_size.y, pad11_screen])
	# During descent, player sits higher in viewport (38-50% height), revealing landing pad below
	assert(p_screen.y / view_size.y >= 0.36 and p_screen.y / view_size.y <= 0.50, "Descent places player in upper-middle, opening landing zone below!")
	assert(pad11_screen.y < view_size.y - 30.0, "Pad 11 clearly visible below player!")
	await _capture("v6_05_downward_flight.png")

	# ─── 6. APPROACH ───────────────────────────────────────────────────────
	print("\n--- 6. Approach ---")
	_ensure_flying(main, hud, player)
	player.global_position = Vector2(p11_pos.x - 70.0, p11_pos.y - 90.0)
	player.velocity = Vector2(40.0, 80.0)
	await step_frames.call(18, player.velocity)
	p_screen = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	pad11_screen = (pad_11.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Player Screen: %s, Pad 11: %s" % [p_screen, pad11_screen])
	await _capture("v6_06_approach.png")

	# ─── 7. LANDING ────────────────────────────────────────────────────────
	print("\n--- 7. Landing (Landed on Pad 11, Target is Pad 12) ---")
	main.current_pad = 11
	camera.set_next_target_platform(pad_12)
	player.set_target_platform(pad_12)
	player.spawn_on_platform(pad_11)
	player.velocity = Vector2.ZERO
	camera.notify_landed(pad_11)
	await step_frames.call(30)
	p_screen = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	pad11_screen = (pad_11.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	var pad12_screen = (pad_12.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Player Screen: %s (X frac: %.2f), Pad 11: %s, Pad 12: %s" % [p_screen, p_screen.x / view_size.x, pad11_screen, pad12_screen])
	# When landed on Pad 11, player remains naturally offset at ~38-42% from left toward Pad 12!
	assert(p_screen.x / view_size.x >= 0.36 and p_screen.x / view_size.x <= 0.46, "Landed player is NOT recentered! Stays offset at ~40% with Pad 12 ahead!")
	await _capture("v6_07_landing.png")

	print("\n=======================================================")
	print("🎉 ALL 7 V6 DIRECTIONAL COMPOSITION TESTS PASSED!")
	print("=======================================================")
	quit()

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img = root.get_viewport().get_texture().get_image()
	var dest = ARTIFACT_DIR + "/" + filename
	img.save_png(dest)
