extends SceneTree

const ARTIFACT_DIR = "C:/Users/aruvi/.gemini/antigravity-ide/brain/f75eeb4b-bf34-4366-b518-afc1bd64e4d0"

func _init() -> void:
	print("=== STARTING FLIGHT MODEL V4 PLAYTEST & TUNING SUITE ===")
	call_deferred("_run_playtest")

func _run_playtest() -> void:
	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	
	await create_timer(0.3).timeout
	
	var player: SolarPlayer = main.get_node("Player")
	var world_gen: WorldGenerator = main.get_node("WorldGenerator")
	var hud: SolarHUD = main.get_node("HUD")
	var camera: SolarCamera = main.get_node("Camera2D")
	
	print("[PLAYTEST] Scene instantiated successfully.")
	_capture_screenshot("screen_main_menu.png")
	await create_timer(0.2).timeout
	
	main._on_play_game_requested()
	
	while main.current_state != main.GameState.PLAYING:
		await create_timer(0.1).timeout
	print("[PLAYTEST] Countdown finished! Game State: PLAYING")

	# ====================================================
	# 1. ONE COMPLETE JUMP: TAKEOFF -> STEERING -> LANDING
	# ====================================================
	print("\n--- PHASE 1: FULL JUMP CAPTURE (00 -> 01) ---")
	var p0 = world_gen.get_platform_by_index(0)
	var p1 = world_gen.get_platform_by_index(1)
	var p1_target_pos = p1.get_landing_position()
	print("  Platform 00 at %s -> Platform 01 at %s (Gap: %.0f px)" % [p0.global_position, p1.global_position, p1.global_position.x - p0.global_position.x])

	# A. TAKEOFF
	player.set_mobile_inputs(false, true, true) # Right + Boost
	await create_timer(0.18).timeout
	_capture_screenshot("jump_takeoff.png")
	print("  [1/4 TAKEOFF] Pos: %s | Vel: %s" % [player.global_position, player.velocity])

	# B. CLOSED-LOOP PILOT TO PAD 01
	var jump_timer = 4.0
	var mid_captured = false
	var arc_captured = false
	
	while jump_timer > 0.0 and player.current_state != player.State.LANDED and player.current_state != player.State.ON_PAD:
		await create_timer(0.04).timeout
		jump_timer -= 0.04
		
		var dx = p1_target_pos.x - player.global_position.x
		var dy = p1_target_pos.y - player.global_position.y
		
		var s_l = false
		var s_r = false
		var b = false
		
		if dx > 25.0:
			s_r = true
		elif dx < -25.0:
			s_l = true
		else:
			if player.velocity.x > 35.0: s_l = true
			elif player.velocity.x < -35.0: s_r = true
			
		if dy > 60.0 and player.velocity.y > 80.0:
			b = true
		elif player.global_position.y > p1_target_pos.y - 20.0 and player.velocity.y > 60.0:
			b = true
			
		player.set_mobile_inputs(s_l, s_r, b)
		
		if not mid_captured and player.global_position.x > p0.global_position.x + 80.0:
			mid_captured = true
			_capture_screenshot("jump_steering.png")
			print("  [2/4 STEERING] Pos: %s | Vel: %s" % [player.global_position, player.velocity])
			
		if not arc_captured and player.global_position.y < p1_target_pos.y - 50.0 and player.velocity.y > 0.0:
			arc_captured = true
			_capture_screenshot("jump_arc.png")
			print("  [3/4 DESCENT ARC] Pos: %s | Vel: %s" % [player.global_position, player.velocity])
			
	player.set_mobile_inputs(false, false, false)
	await create_timer(0.1).timeout
	_capture_screenshot("jump_touchdown.png")
	print("  [4/4 TOUCHDOWN] Pos: %s | State: %d | Platform: %s" % [
		player.global_position, player.current_state, player.active_platform.name if player.active_platform else "none"
	])
	
	# Test Pause overlay
	main._on_pause_game_requested()
	await create_timer(0.15).timeout
	_capture_screenshot("screen_pause.png")
	main._on_resume_game_requested()
	await create_timer(0.1).timeout

	# ====================================================
	# 2. 15 CONSECUTIVE PLATFORM HOPS
	# ====================================================
	print("\n--- PHASE 2: 15 CONSECUTIVE PLATFORM HOPS ---")
	var current_pad_idx = 1
	var hops_successful = 0
	
	for hop in range(15):
		var src_pad = world_gen.get_platform_by_index(current_pad_idx)
		var dest_pad = world_gen.get_platform_by_index(current_pad_idx + 1)
		if not is_instance_valid(dest_pad):
			print("  [HOP #%02d] Platform #%d not spawned!" % [hop + 1, current_pad_idx + 1])
			break
			
		var dest_pos = dest_pad.get_landing_position()
		var hop_time = 4.0
		var hop_done = false
		
		# Launch toward destination
		player.set_mobile_inputs(false, true, true)
		await create_timer(0.25).timeout
		
		while hop_time > 0.0:
			await create_timer(0.04).timeout
			hop_time -= 0.04
			
			var dx = dest_pos.x - player.global_position.x
			var dy = dest_pos.y - player.global_position.y
			
			var s_l = false
			var s_r = false
			var b = false
			
			# Horizontal piloting
			if dx > 30.0:
				s_r = true
			elif dx < -30.0:
				s_l = true
			else:
				# Brake horizontally
				if player.velocity.x > 30.0: s_l = true
				elif player.velocity.x < -30.0: s_r = true
				
			# Vertical flare & height control
			if dy > 60.0 and player.velocity.y > 100.0:
				b = true
			elif dy > 120.0 and player.velocity.y > 30.0:
				b = true
			elif player.global_position.y > dest_pos.y - 15.0 and player.velocity.y > 80.0:
				b = true
				
			player.set_mobile_inputs(s_l, s_r, b)
			
			if player.current_state == player.State.LANDED or (player.current_state == player.State.ON_PAD and player.active_platform == dest_pad):
				hop_done = true
				break
				
		player.set_mobile_inputs(false, false, false)
		
		if hop_done:
			hops_successful += 1
			current_pad_idx += 1
			print("  [HOP #%02d -> PAD #%02d] SUCCESS! Pos: (%.0f, %.0f), Alt: %dm, Fuel: %.0f%%" % [
				hop + 1, current_pad_idx, player.global_position.x, player.global_position.y, main.current_altitude, player.fuel
			])
			await create_timer(0.3).timeout
		else:
			print("  [HOP #%02d -> PAD #%02d] MISSED / TIMEOUT" % [hop + 1, current_pad_idx + 1])
			break

	print("\n--- HOPPING EVALUATION ---")
	print("  Safe Landings: %d / 15" % hops_successful)
	print("  Current Altitude: %dm | Best: %dm" % [main.current_altitude, main.best_altitude])

	# ====================================================
	# 3. HIGH ALTITUDE & ROUTE GENERATION CHECK
	# ====================================================
	print("\n--- PHASE 3: HIGH ALTITUDE GENERATION & CAMERA FRAMING ---")
	var highest_pad = world_gen.get_highest_platform_index()
	print("  Platforms active in buffer ahead: up to Pad #%d" % highest_pad)
	print("  Player pos: %s | Camera pos: %s" % [player.global_position, camera.global_position])
	var player_screen_y = (player.global_position.y - camera.global_position.y) + 360.0
	var player_screen_pct = (player_screen_y / 720.0) * 100.0
	print("  Player vertical screen position: %.1f px (%.1f%% from top) [Framing target: 55-65%%]" % [
		player_screen_y, player_screen_pct
	])

	# ====================================================
	# 4. UI & STATE FLOW
	# ====================================================
	print("\n--- PHASE 4: UI & PAUSE/RESUME VERIFICATION ---")
	main._on_pause_game_requested()
	print("  [PAUSE] State: %d | Tree Paused: %s" % [main.current_state, main.get_tree().paused])
	await create_timer(0.2).timeout
	main._on_resume_game_requested()
	print("  [RESUME] State: %d | Tree Paused: %s" % [main.current_state, main.get_tree().paused])
	await create_timer(0.2).timeout

	print("\n=== PLAYTEST SUITE COMPLETED CLEANLY ===")
	quit(0)

func _capture_screenshot(filename: String) -> void:
	await create_timer(0.04).timeout
	var img = root.get_viewport().get_texture().get_image()
	if img:
		var save_path = ARTIFACT_DIR + "/" + filename
		var err = img.save_png(save_path)
		print("    📸 Screenshot: %s (result=%d)" % [filename, err])
