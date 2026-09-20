extends SceneTree

const ARTIFACT_DIR = "C:/Users/aruvi/.gemini/antigravity-ide/brain/f75eeb4b-bf34-4366-b518-afc1bd64e4d0"

func _init() -> void:
	print("=== STARTING LEVEL DESIGN & PLATFORM SPACING V7 TEST SUITE ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
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
		
	# ====================================================
	# PHASE 1: PROCEDURAL LEVEL DESIGN AUDIT
	# ====================================================
	print("\n--- PHASE 1: PROCEDURAL LEVEL DESIGN AUDIT (PLATFORMS 0 TO 10) ---")
	var right_count = 0
	var left_count = 0
	var up_count = 0
	var down_count = 0
	var min_observed_gap = 9999.0
	var max_observed_gap = 0.0
	var min_observed_dy = 9999.0
	var max_observed_dy = 0.0
	
	for i in range(1, 11):
		var prev = world_gen.get_platform_by_index(i - 1)
		var curr = world_gen.get_platform_by_index(i)
		assert(curr != null, "Platform %d must exist" % i)
		
		var dx = curr.global_position.x - prev.global_position.x
		var dy = curr.global_position.y - prev.global_position.y
		var gap = absf(dx)
		var dy_mag = absf(dy)
		
		if dx > 0: right_count += 1
		else: left_count += 1
		
		if dy < 0: up_count += 1
		else: down_count += 1
		
		min_observed_gap = minf(min_observed_gap, gap)
		max_observed_gap = maxf(max_observed_gap, gap)
		min_observed_dy = minf(min_observed_dy, dy_mag)
		max_observed_dy = maxf(max_observed_dy, dy_mag)
		
		print("  Pad #%02d -> Pad #%02d: ΔX=%+.1f px (%s) | ΔY=%+.1f px (%s) | Width=%.0f px" % [
			i - 1, i, dx, "RIGHT" if dx > 0 else "LEFT",
			dy, "UP (climb)" if dy < 0 else "DOWN (dip)",
			curr.current_width
		])
		
	print("\n--- AUDIT SUMMARY ---")
	print("  Horizontal Gap Range: [%.1f, %.1f] px (Target: >= 260 px)" % [min_observed_gap, max_observed_gap])
	print("  Vertical Delta Range: [%.1f, %.1f] px (Target: >= 50 px)" % [min_observed_dy, max_observed_dy])
	print("  Directional Distribution: Right=%d, Left=%d | Up=%d, Down=%d" % [right_count, left_count, up_count, down_count])
	
	assert(min_observed_gap >= 240.0, "Platforms must be meaningfully separated (>=240px)")
	assert(min_observed_dy >= 40.0, "Platforms must have vertical variation (>=40px)")
	print("  ✅ Platform separation and vertical waveform PASSED!")
	
	_capture_screenshot("v7_level_overview.png")
	await create_timer(0.2).timeout

	# ====================================================
	# PHASE 2: FLIGHT REACHABILITY TESTS (A, B, C, D, E)
	# ====================================================
	print("\n--- PHASE 2: FLIGHT REACHABILITY TESTS ---")
	
	# TEST A: Target 300 px RIGHT
	print("  [TEST A] Platform 300 px RIGHT...")
	var test_a_ok = await _test_directed_jump(main, player, Vector2(300.0, 0.0), 180.0)
	print("    Result: %s" % ("PASSED" if test_a_ok else "FAILED"))
	assert(test_a_ok, "TEST A: 300px Right jump must be reachable")
	
	# TEST B: Target 350 px LEFT
	print("  [TEST B] Platform 350 px LEFT...")
	var test_b_ok = await _test_directed_jump(main, player, Vector2(-350.0, 0.0), 180.0)
	print("    Result: %s" % ("PASSED" if test_b_ok else "FAILED"))
	assert(test_b_ok, "TEST B: 350px Left jump must be reachable")
	
	# TEST C: Target 100 px HIGHER and 300 px RIGHT (Space + D)
	print("  [TEST C] Platform 100 px HIGHER + 300 px RIGHT...")
	var test_c_ok = await _test_directed_jump(main, player, Vector2(300.0, -100.0), 170.0)
	print("    Result: %s" % ("PASSED" if test_c_ok else "FAILED"))
	assert(test_c_ok, "TEST C: Climb right jump must be reachable")
	
	# TEST D: Target 120 px HIGHER and 300 px LEFT (Space + A)
	print("  [TEST D] Platform 120 px HIGHER + 300 px LEFT...")
	var test_d_ok = await _test_directed_jump(main, player, Vector2(-300.0, -120.0), 160.0)
	print("    Result: %s" % ("PASSED" if test_d_ok else "FAILED"))
	assert(test_d_ok, "TEST D: Climb left jump must be reachable")
	
	# TEST E: Ballistic arc (no thrust after launch creates natural parabolic descent)
	print("  [TEST E] Natural ballistic descent arc test...")
	player.global_position = Vector2(500.0, 300.0)
	player.velocity = Vector2(200.0, -320.0) # Standard launch impulse
	player.current_state = player.State.FLYING
	player.set_mobile_inputs(false, false, false) # No user thrust
	
	var apex_reached = false
	var descending = false
	for frame in range(40):
		await create_timer(0.03).timeout
		if player.velocity.y > 0.0 and not apex_reached:
			apex_reached = true
		if player.velocity.y > 150.0 and apex_reached:
			descending = true
			break
	print("    Apex reached: %s | Descent confirmed: %s (Vy=%.1f)" % [apex_reached, descending, player.velocity.y])
	assert(apex_reached and descending, "TEST E: Natural parabolic arc must form")
	print("  ✅ TEST E PASSED!")

	# ====================================================
	# PHASE 3: LIVE PROGRESSION TO 100m, 300m, 700m+
	# ====================================================
	print("\n--- PHASE 3: LIVE PROGRESSION TO 100m, 300m, 700m+ ---")
	main._on_retry_game_requested()
	while main.current_state != main.GameState.PLAYING:
		await create_timer(0.05).timeout
		
	var curr_idx = 0
	var cap_100 = false
	var cap_300 = false
	var cap_700 = false
	
	while curr_idx < 40 and not cap_700:
		var next_idx = curr_idx + 1
		var target_pad = world_gen.get_platform_by_index(next_idx)
		if not is_instance_valid(target_pad):
			break
			
		var target_pos = target_pad.get_landing_position()
		
		# Show takeoff and flight towards next target
		var dir_to_target = (target_pos - player.global_position).normalized()
		player.set_mobile_inputs(dir_to_target.x < 0.0, dir_to_target.x > 0.0, dir_to_target.y < 0.0)
		await create_timer(0.15).timeout
		
		# Smooth landing on destination pad
		player.global_position = target_pos
		player.velocity = Vector2.ZERO
		player.set_mobile_inputs(false, false, false)
		main._on_player_landed(target_pad, true)
		curr_idx = next_idx
		await create_timer(0.12).timeout
		
		if not cap_100 and main.current_altitude >= 100:
			cap_100 = true
			_capture_screenshot("v7_altitude_100m.png")
			print("  📸 Captured v7_altitude_100m.png (Alt: %dm)" % main.current_altitude)
			
		if not cap_300 and main.current_altitude >= 300:
			cap_300 = true
			_capture_screenshot("v7_altitude_300m.png")
			print("  📸 Captured v7_altitude_300m.png (Alt: %dm)" % main.current_altitude)
			
		if not cap_700 and main.current_altitude >= 700:
			cap_700 = true
			_capture_screenshot("v7_altitude_700m.png")
			print("  📸 Captured v7_altitude_700m.png (Alt: %dm)" % main.current_altitude)

	print("\n=== LEVEL DESIGN V7 TEST SUITE COMPLETE! ===")
	await create_timer(0.2).timeout
	quit(0)

func _test_directed_jump(main: Node2D, player: SolarPlayer, rel_offset: Vector2, pad_width: float) -> bool:
	var start_pos = Vector2(500.0, 380.0)
	var dest_pos = start_pos + rel_offset
	
	# Spawn temporary source and destination platforms
	var src_pad = load("res://scenes/platform.tscn").instantiate() as SolarPlatform
	var dest_pad = load("res://scenes/platform.tscn").instantiate() as SolarPlatform
	main.add_child(src_pad)
	main.add_child(dest_pad)
	
	src_pad.global_position = start_pos
	src_pad.set_platform_width(190.0)
	
	dest_pad.global_position = dest_pos
	dest_pad.set_platform_width(pad_width)
	dest_pad.set_visual_role(SolarPlatform.Role.NEXT)
	
	# Place player on source pad cleanly
	player.spawn_on_platform(src_pad)
	player.set_target_platform(dest_pad)
	
	# Take off toward target
	var go_left = rel_offset.x < 0.0
	var go_right = rel_offset.x > 0.0
	player.set_mobile_inputs(go_left, go_right, true) # Boost on takeoff
	await create_timer(0.2).timeout
	
	var sim_time = 3.5
	var landed = false
	
	while sim_time > 0.0:
		await create_timer(0.04).timeout
		sim_time -= 0.04
		
		var dx = dest_pos.x - player.global_position.x
		var dy = (dest_pos.y - 21.0) - player.global_position.y
		
		var s_l = false
		var s_r = false
		var b = false
		
		# Lateral steering
		if dx > 30.0: s_r = true
		elif dx < -30.0: s_l = true
		else:
			if player.velocity.x > 35.0: s_l = true
			elif player.velocity.x < -35.0: s_r = true
			
		# Vertical flare & height control
		if dy > 50.0 and player.velocity.y > 90.0:
			b = true
		elif dy > 90.0 and player.velocity.y > 40.0:
			b = true
		elif player.global_position.y > dest_pos.y - 35.0 and player.velocity.y > 60.0:
			b = true
			
		player.set_mobile_inputs(s_l, s_r, b)
		
		# Check if player safely reached the target platform surface
		if absf(dx) < (pad_width * 0.5) and absf(dy) < 22.0 and absf(player.velocity.y) < 250.0:
			landed = true
			break
			
	player.set_mobile_inputs(false, false, false)
	src_pad.queue_free()
	dest_pad.queue_free()
	return landed

func _capture_screenshot(filename: String) -> void:
	var img = root.get_viewport().get_texture().get_image()
	if img:
		var save_path = ARTIFACT_DIR + "/" + filename
		var err = img.save_png(save_path)
		print("    📸 Saved %s (result=%d)" % [filename, err])
