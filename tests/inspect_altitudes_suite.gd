extends SceneTree

const ARTIFACT_DIR = "C:/Users/aruvi/.gemini/antigravity-ide/brain/f75eeb4b-bf34-4366-b518-afc1bd64e4d0"

func _init() -> void:
	print("=== STARTING VISUAL INSPECTION AT 0m, 100m, 300m, 700m+ ===")
	call_deferred("_run_inspection")

func _run_inspection() -> void:
	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	
	await create_timer(0.3).timeout
	
	var player: SolarPlayer = main.get_node("Player")
	var world_gen: WorldGenerator = main.get_node("WorldGenerator")
	var hud: SolarHUD = main.get_node("HUD")
	var camera: SolarCamera = main.get_node("Camera2D")
	
	# Start game
	main._on_play_game_requested()
	while main.current_state != main.GameState.PLAYING:
		await create_timer(0.05).timeout
		
	print("[INSPECTION] Game started, on platform 0 (0m).")
	
	# 1. 0m Screen
	await create_timer(0.15).timeout
	_capture_screenshot("screen_altitude_0m.png")
	print("  📸 Captured screen_altitude_0m.png at altitude: %dm" % main.current_altitude)
	
	# Step through platforms sequentially
	var curr_idx = 0
	var captured_100 = false
	var captured_300 = false
	var captured_700 = false
	
	while curr_idx < 40 and not captured_700:
		var next_idx = curr_idx + 1
		var target_pad = world_gen.get_platform_by_index(next_idx)
		if not is_instance_valid(target_pad):
			print("  [ERROR] Platform %d does not exist!" % next_idx)
			break
			
		var target_pos = target_pad.get_landing_position()
		
		# Smoothly fly or teleport player onto landing pad with realistic landing trigger
		# First do a short hop simulation to show flight + landing
		player.global_position = target_pos + Vector2(0.0, -18.0)
		player.velocity = Vector2(0.0, 40.0)
		await create_timer(0.08).timeout
		
		# Trigger safe landing
		player.global_position = target_pos
		player.velocity = Vector2.ZERO
		main._on_player_landed(target_pad, true)
		curr_idx = next_idx
		
		# Allow camera and HUD to update
		await create_timer(0.12).timeout
		
		if not captured_100 and main.current_altitude >= 100:
			captured_100 = true
			# Let player lift slightly so we see flight + next platform
			player.set_mobile_inputs(false, true, true)
			await create_timer(0.18).timeout
			player.set_mobile_inputs(false, false, false)
			await create_timer(0.08).timeout
			_capture_screenshot("screen_altitude_100m.png")
			print("  📸 Captured screen_altitude_100m.png at altitude: %dm" % main.current_altitude)
			
		if not captured_300 and main.current_altitude >= 300:
			captured_300 = true
			player.set_mobile_inputs(false, true, true)
			await create_timer(0.18).timeout
			player.set_mobile_inputs(false, false, false)
			await create_timer(0.08).timeout
			_capture_screenshot("screen_altitude_300m.png")
			print("  📸 Captured screen_altitude_300m.png at altitude: %dm" % main.current_altitude)
			
		if not captured_700 and main.current_altitude >= 700:
			captured_700 = true
			player.set_mobile_inputs(false, true, true)
			await create_timer(0.18).timeout
			player.set_mobile_inputs(false, false, false)
			await create_timer(0.08).timeout
			_capture_screenshot("screen_altitude_700m.png")
			print("  📸 Captured screen_altitude_700m.png at altitude: %dm" % main.current_altitude)

	print("[INSPECTION] Complete! Altitude reached: %dm" % main.current_altitude)
	await create_timer(0.2).timeout
	quit(0)

func _capture_screenshot(filename: String) -> void:
	var img = root.get_viewport().get_texture().get_image()
	if img:
		var save_path = ARTIFACT_DIR + "/" + filename
		var err = img.save_png(save_path)
		print("    📸 Saved %s (err=%d)" % [filename, err])
