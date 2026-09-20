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
	print("=== RUNNING V5.8 DEADZONE & VISUAL WORLD SCROLL TEST ===")
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
	
	# ─── 1. RESTING ON PAD 0 ─────────────────────────────────────────────────
	print("\n--- 1. RESTING ON PAD 0 ---")
	player.spawn_on_platform(pad_0)
	camera.snap_to_target()
	for _i in range(25):
		await create_timer(0.02).timeout
	
	var p_screen = (player.global_position - camera.global_position) + view_size * 0.5
	var pad0_screen = (pad_0.global_position - camera.global_position) + view_size * 0.5
	print("  Player World: %s, Camera World: %s" % [player.global_position, camera.global_position])
	print("  Player Screen: %s, Pad 0 Screen: %s" % [p_screen, pad0_screen])
	await _capture("v5_8_A_resting_pad0.png")
	
	# ─── 2. LIFT OFF THE PAD (Natural deadzone rise, Pad 0 clearly visible!) ───
	print("\n--- 2. LIFT OFF THE PAD (Within Deadzone) ---")
	_ensure_flying(main, hud, player)
	player.global_position = pad_0.global_position + Vector2(20.0, -75.0)
	player.velocity = Vector2(50.0, -180.0)
	for _i in range(20):
		player.global_position += player.velocity * 0.02
		await create_timer(0.02).timeout
	
	p_screen = (player.global_position - camera.global_position) + view_size * 0.5
	pad0_screen = (pad_0.global_position - camera.global_position) + view_size * 0.5
	print("  Player Screen: %s, Pad 0 Screen: %s" % [p_screen, pad0_screen])
	# Pad 0 must remain solidly in view on screen!
	assert(pad0_screen.y < view_size.y - 60.0, "Pad 0 must be clearly visible during initial climb!")
	await _capture("v5_8_B_lift_off_pad.png")
	
	# ─── 3. CLIMB OVER CANYON (Pushing Deadzone Top, World Scrolls Down) ─────
	print("\n--- 3. CLIMB OVER CANYON (Pushing Deadzone Top) ---")
	var start_p = pad_0.global_position
	var target_p = pad_1.global_position
	var dx = target_p.x - start_p.x
	
	player.global_position = Vector2(start_p.x + dx * 0.30, start_p.y - 190.0)
	player.velocity = Vector2(240.0, -140.0)
	for _i in range(30):
		player.global_position += player.velocity * 0.02
		await create_timer(0.02).timeout
	
	p_screen = (player.global_position - camera.global_position) + view_size * 0.5
	pad0_screen = (pad_0.global_position - camera.global_position) + view_size * 0.5
	print("  Player Screen: %s, Pad 0 Screen: %s" % [p_screen, pad0_screen])
	# Player is in upper-middle of deadzone, not lost in outer space
	assert(p_screen.y >= view_size.y * 0.30 and p_screen.y <= view_size.y * 0.55, "Player framed comfortably in upper-middle!")
	await _capture("v5_8_C_climb_over_canyon.png")
	
	# ─── 4. HORIZONTAL CRUISE (Pad 0 Exits Left, Pad 1 Enters Right) ─────────
	print("\n--- 4. HORIZONTAL CRUISE ---")
	player.global_position = Vector2(start_p.x + dx * 0.55, start_p.y - 170.0)
	player.velocity = Vector2(260.0, 10.0)
	for _i in range(30):
		player.global_position += player.velocity * 0.02
		await create_timer(0.02).timeout
	
	p_screen = (player.global_position - camera.global_position) + view_size * 0.5
	var pad1_screen = (pad_1.global_position - camera.global_position) + view_size * 0.5
	print("  Player Screen: %s, Pad 1 Screen: %s" % [p_screen, pad1_screen])
	# Pad 1 has entered from the right side!
	assert(pad1_screen.x < view_size.x + 80.0, "Pad 1 entering naturally from right edge!")
	await _capture("v5_8_D_horizontal_cruise.png")
	
	# ─── 5. DESCENT APPROACH (Pad 1 & Landing Terrain Rise Into View) ─────────
	print("\n--- 5. DESCENT APPROACH ---")
	player.global_position = Vector2(target_p.x - 140.0, target_p.y - 130.0)
	player.velocity = Vector2(160.0, 180.0)
	for _i in range(30):
		player.global_position += player.velocity * 0.02
		await create_timer(0.02).timeout
	
	p_screen = (player.global_position - camera.global_position) + view_size * 0.5
	pad1_screen = (pad_1.global_position - camera.global_position) + view_size * 0.5
	print("  Player Screen: %s, Pad 1 Screen: %s" % [p_screen, pad1_screen])
	# Pad 1 must be prominently visible in the lower portion of the screen!
	assert(pad1_screen.y > view_size.y * 0.50 and pad1_screen.y < view_size.y - 60.0, "Pad 1 must be clearly readable in lower-middle!")
	assert(pad1_screen.x > view_size.x * 0.40 and pad1_screen.x < view_size.x * 0.85, "Pad 1 horizontally in flight path!")
	await _capture("v5_8_E_descent_approach.png")
	
	# ─── 6. TOUCHDOWN ON PAD 1 (Settled) ────────────────────────────────────
	print("\n--- 6. TOUCHDOWN ON PAD 1 ---")
	player.spawn_on_platform(pad_1)
	player.velocity = Vector2.ZERO
	for _i in range(30):
		await create_timer(0.02).timeout
	
	p_screen = (player.global_position - camera.global_position) + view_size * 0.5
	pad1_screen = (pad_1.global_position - camera.global_position) + view_size * 0.5
	print("  Player Screen: %s, Pad 1 Screen: %s" % [p_screen, pad1_screen])
	await _capture("v5_8_F_touchdown_pad1.png")
	
	# ─── 7. MISSED LANDING (Plunging into Canyon Gap) ────────────────────────
	print("\n--- 7. MISSED LANDING ---")
	_ensure_flying(main, hud, player)
	player.global_position = Vector2(pad_1.global_position.x + 190.0, pad_1.global_position.y + 40.0)
	player.velocity = Vector2(20.0, 240.0)
	for _i in range(35):
		player.global_position += player.velocity * 0.02
		await create_timer(0.02).timeout
	
	p_screen = (player.global_position - camera.global_position) + view_size * 0.5
	pad1_screen = (pad_1.global_position - camera.global_position) + view_size * 0.5
	print("  Player Screen: %s, Pad 1 Screen: %s" % [p_screen, pad1_screen])
	assert(pad1_screen.y < view_size.y * 0.5, "Pad 1 moved up on screen as player plunged!")
	await _capture("v5_8_G_missed_canyon_fall.png")
	
	print("\n=======================================================")
	print("🎉 ALL V5.8 DEADZONE & VISUAL WORLD SCROLL TESTS PASSED!")
	print("=======================================================")
	quit()

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img = root.get_viewport().get_texture().get_image()
	var dest = ARTIFACT_DIR + "/" + filename
	img.save_png(dest)
