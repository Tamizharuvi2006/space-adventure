extends SceneTree

const SunZoneData = preload("res://scripts/planet_data.gd")
const SolarBackground = preload("res://scripts/background.gd")
const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")
const SolarHUD = preload("res://scripts/hud.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")

const ARTIFACT_DIR = "C:/Users/aruvi/.gemini/antigravity-ide/brain/f75eeb4b-bf34-4366-b518-afc1bd64e4d0"

func _init() -> void:
	print("=== RUNNING V3 CORRECTION PROTOCOL (PADS 18-25) ===")
	call_deferred("_run_protocol")

func _run_protocol() -> void:
	var packed = load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate() as SolarMain
	root.add_child(main)
	
	var hud = main.get_node("HUD") as SolarHUD
	var player = main.get_node("Player") as SolarPlayer
	var world_gen = main.get_node("WorldGenerator") as WorldGenerator
	var camera = main.get_node("Camera2D") as SolarCamera
	
	await create_timer(0.4).timeout
	
	# Start game
	hud.emit_signal("play_game_requested")
	while main.current_state != SolarMain.GameState.PLAYING:
		await create_timer(0.05).timeout
	await create_timer(0.3).timeout
	
	# Advance route generation up to Pad 26
	while world_gen.next_platform_idx <= 26:
		world_gen.spawn_next_route_pad()
		
	var pad_19 = world_gen.get_platform_by_index(19)
	var pad_20 = world_gen.get_platform_by_index(20)
	assert(pad_19 != null and pad_20 != null, "Pads 19 & 20 must exist!")
	
	# =========================================================================
	# TEST A: Player on Pad 19 overlooking huge canyon chasm toward Pad 20
	# =========================================================================
	player.spawn_on_platform(pad_19)
	main._on_player_landed(pad_19, false)
	if camera:
		camera.global_position = pad_19.global_position + Vector2(100.0, -75.0)
	await create_timer(0.8).timeout
	await _capture_screenshot("v3_a_docked_pad19.png")
	
	# =========================================================================
	# TEST B: Player in mid-air flying across open canyon toward Pad 20
	# =========================================================================
	player.current_state = SolarPlayer.State.FLYING
	player.active_platform = null
	player.last_docked_platform = pad_19
	player.global_position = pad_19.global_position.lerp(pad_20.global_position, 0.42) + Vector2(0.0, -120.0)
	player.velocity = Vector2(160.0, -20.0)
	if camera:
		camera.global_position = player.global_position + Vector2(80.0, -75.0)
	await create_timer(0.5).timeout
	await _capture_screenshot("v3_b_inflight_pad20.png")
	
	# =========================================================================
	# TEST C: Player missing Pad 20, falling past cliff into open void
	# =========================================================================
	# Position player falling beyond Pad 20's right edge
	player.global_position = pad_20.global_position + Vector2(120.0, 150.0)
	player.velocity = Vector2(40.0, 320.0)
	if camera:
		camera.global_position = player.global_position + Vector2(0.0, -60.0)
	await create_timer(0.4).timeout
	await _capture_screenshot("v3_c_miss_falling.png")
	
	# =========================================================================
	# TEST D: Abyss Death Triggered -> Game Over screen
	# =========================================================================
	# Force player below abyss recovery limit
	var floor_ref_y = maxf(pad_20.global_position.y, pad_19.global_position.y)
	player.global_position = Vector2(pad_20.global_position.x + 80.0, floor_ref_y + 300.0)
	player._physics_process(0.0166)
	await create_timer(0.8).timeout
	await _capture_screenshot("v3_d_game_over.png")
	
	# =========================================================================
	# TEST E: Clean Landing on Pad 20
	# =========================================================================
	# Reset state and land safely on Pad 20
	main.current_state = SolarMain.GameState.PLAYING
	hud.hide_game_over()
	player.set_control_enabled(true)
	player.spawn_on_platform(pad_20)
	main._on_player_landed(pad_20, true)
	if camera:
		camera.global_position = pad_20.global_position + Vector2(60.0, -75.0)
	await create_timer(0.8).timeout
	await _capture_screenshot("v3_e_landed_pad20.png")
	
	print("=== V3 CORRECTION PROTOCOL COMPLETE ===")
	quit(0)

func _capture_screenshot(filename: String) -> void:
	await create_timer(0.1).timeout
	var vp = root.get_viewport()
	if vp:
		var tex = vp.get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				var path = ARTIFACT_DIR + "/" + filename
				var err = img.save_png(path)
				print("  📸 Saved screenshot %s (res=%d)" % [filename, err])
