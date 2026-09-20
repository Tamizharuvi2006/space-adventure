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
	print("=== CAPTURING 6 REFERENCE FLIGHT PHASES (Pad 0 -> Pad 1) ===")
	call_deferred("_run_flight_capture")

func _run_flight_capture() -> void:
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
	
	var pad_0 = world_gen.get_platform_by_index(0)
	var pad_1 = world_gen.get_platform_by_index(1)
	assert(pad_0 != null and pad_1 != null, "Pad 0 and Pad 1 must exist!")
	
	# ─── PHASE 1: RESTING on Pad 0 ──────────────────────────────────────────
	print("\n--- 1. RESTING ON PAD 0 ---")
	player.spawn_on_platform(pad_0)
	camera.global_position = player.global_position + Vector2(0.0, camera.default_vertical_offset)
	for _i in range(25):
		await create_timer(0.02).timeout
	print("  Player: %s, Camera: %s" % [player.global_position, camera.global_position])
	await _capture("phase1_resting_pad0.png")
	
	# ─── PHASE 2: VERTICAL TAKEOFF (Boost upward off pad) ───────────────────
	print("\n--- 2. VERTICAL TAKEOFF ---")
	player.set_physics_process(false)
	player.current_state = SolarPlayer.State.FLYING
	player.global_position = pad_0.global_position + Vector2(0.0, -110.0)
	player.velocity = Vector2(40.0, -280.0)
	for _i in range(30):
		player.global_position += player.velocity * 0.02
		player.velocity.y += 640.0 * 0.005
		await create_timer(0.02).timeout
	print("  Player: %s, Camera: %s" % [player.global_position, camera.global_position])
	await _capture("phase2_vertical_takeoff.png")
	
	# ─── PHASE 3: DIAGONAL ASCENT (Climbing toward Pad 1) ───────────────────
	print("\n--- 3. DIAGONAL ASCENT ---")
	var start_p = pad_0.global_position
	var target_p = pad_1.global_position
	var dx = target_p.x - start_p.x
	
	player.global_position = Vector2(start_p.x + dx * 0.28, start_p.y - 240.0)
	player.velocity = Vector2(260.0, -160.0)
	for _i in range(30):
		player.global_position += player.velocity * 0.02
		await create_timer(0.02).timeout
	print("  Player: %s, Camera: %s" % [player.global_position, camera.global_position])
	await _capture("phase3_diagonal_ascent.png")
	
	# ─── PHASE 4: HIGH ALTITUDE APEX (Gliding over canyon) ──────────────────
	print("\n--- 4. HIGH ALTITUDE APEX ---")
	player.global_position = Vector2(start_p.x + dx * 0.52, start_p.y - 320.0)
	player.velocity = Vector2(240.0, 10.0)
	for _i in range(30):
		player.global_position += player.velocity * 0.02
		await create_timer(0.02).timeout
	print("  Player: %s, Camera: %s" % [player.global_position, camera.global_position])
	await _capture("phase4_high_altitude_apex.png")
	
	# ─── PHASE 5: DESCENT & APPROACH (Landing area rises into viewport) ───────
	print("\n--- 5. DESCENT & APPROACH ---")
	player.global_position = Vector2(target_p.x - 300.0, target_p.y - 250.0)
	player.velocity = Vector2(180.0, 160.0)
	for _i in range(20):
		player.global_position += player.velocity * 0.02
		await create_timer(0.02).timeout
	print("  Player: %s, Camera: %s" % [player.global_position, camera.global_position])
	await _capture("phase5_descent_approach.png")
	
	# ─── PHASE 6: TOUCHDOWN ON PAD 1 (Settled) ──────────────────────────────
	print("\n--- 6. TOUCHDOWN ON PAD 1 ---")
	player.spawn_on_platform(pad_1)
	player.velocity = Vector2.ZERO
	for _i in range(30):
		await create_timer(0.02).timeout
	print("  Player: %s, Camera: %s" % [player.global_position, camera.global_position])
	await _capture("phase6_touchdown_pad1.png")
	
	print("\n=======================================================")
	print("🎉 ALL 6 REFERENCE FLIGHT PHASES CAPTURED SUCCESSFULLY!")
	print("=======================================================")
	quit()

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img = root.get_viewport().get_texture().get_image()
	var dest = ARTIFACT_DIR + "/" + filename
	img.save_png(dest)
