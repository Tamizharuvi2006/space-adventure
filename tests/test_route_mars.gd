extends SceneTree

const ARTIFACT_DIR = "C:/Users/aruvi/.gemini/antigravity-ide/brain/f75eeb4b-bf34-4366-b518-afc1bd64e4d0"

func _init() -> void:
	print("=== STARTING MARS: MARS ROUTE-BASED GAMEPLAY TEST SUITE ===")
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
	
	main._on_play_game_requested()
	while main.current_state != main.GameState.PLAYING:
		await create_timer(0.05).timeout
		
	# ====================================================
	# 1. ROUTE INTEGRITY & SPACING AUDIT
	# ====================================================
	print("\n--- TEST 1: ROUTE INTEGRITY & SPACING AUDIT (PADS 0 TO 8) ---")
	var p0 = world_gen.get_platform_by_index(0)
	var next_p = world_gen.get_platform_by_index(1)
	assert(next_p != null, "Pad 01 must exist ahead")
	assert(next_p.is_active_target, "Pad 01 must be the designated primary target with beacon")
	
	var min_dx = 9999.0
	var max_dx = 0.0
	var min_dy = 9999.0
	var max_dy = 0.0
	
	for i in range(1, 8):
		var prev = world_gen.get_platform_by_index(i - 1)
		var curr = world_gen.get_platform_by_index(i)
		assert(curr != null, "Pad %d must exist" % i)
		
		var dx = curr.global_position.x - prev.global_position.x
		var dy = curr.global_position.y - prev.global_position.y
		var abs_dx = absf(dx)
		var abs_dy = absf(dy)
		
		min_dx = minf(min_dx, abs_dx)
		max_dx = maxf(max_dx, abs_dx)
		min_dy = minf(min_dy, abs_dy)
		max_dy = maxf(max_dy, abs_dy)
		
		print("  Pad #%02d -> Pad #%02d: ΔX=%+.1f px (%s) | ΔY=%+.1f px | Width=%.0f px" % [
			i - 1, i, dx, "RIGHT" if dx > 0 else "LEFT", dy, curr.current_width
		])
		
	print("  Horizontal Gap Range: [%.1f, %.1f] px (Target: 280-400 px)" % [min_dx, max_dx])
	print("  Vertical Delta Range: [%.1f, %.1f] px (Target: 60-140 px)" % [min_dy, max_dy])
	assert(min_dx >= 270.0, "Pads must require real flight (>= 270px)")
	assert(min_dy >= 45.0, "Pads must have vertical variation (>= 45px)")
	print("  ✅ Route integrity and spacing PASSED!")
	
	_capture_screenshot("route_initial_view.png")
	await create_timer(0.2).timeout

	# ====================================================
	# 2. TEST A & F: NORMAL FLIGHT -> TOUCHDOWN -> REFUEL
	# ====================================================
	print("\n--- TEST 2 (A & F): FLIGHT TO NEXT PAD & REFUEL ---")
	var pad1 = world_gen.get_platform_by_index(1)
	var pad1_pos = pad1.get_landing_position()
	
	# Take off and steer towards pad 1
	player.set_mobile_inputs(pad1_pos.x < player.global_position.x, pad1_pos.x > player.global_position.x, true)
	await create_timer(0.2).timeout
	
	# Land on pad 1
	player.global_position = pad1_pos
	player.velocity = Vector2.ZERO
	player.set_mobile_inputs(false, false, false)
	main._on_player_landed(pad1, true)
	await create_timer(0.15).timeout
	
	print("  Landed on Pad 01! Current Platform: %s | Next Target: %s" % [
		world_gen.current_platform.name, world_gen.next_platform.name if world_gen.next_platform else "none"
	])
	assert(world_gen.current_platform == pad1, "Pad 01 must be current platform")
	assert(world_gen.next_platform == world_gen.get_platform_by_index(2), "Pad 02 must be the new next target")
	assert(player.fuel >= 99.0, "Landing on route pad must refill fuel to 100%")
	print("  ✅ Normal route jump and refuel PASSED!")
	
	_capture_screenshot("route_pad1_touchdown.png")
	await create_timer(0.2).timeout

	# ====================================================
	# 3. TEST C & D: NO MAGIC SPAWN WHEN FLYING OFF-ROUTE
	# ====================================================
	print("\n--- TEST 3 (C & D): NO MAGIC PLATFORM SPAWN OFF-ROUTE ---")
	var pre_flight_count = world_gen.active_platforms.size()
	
	# Fly far off to the side into empty space
	player.global_position = player.global_position + Vector2(-600.0, -100.0)
	player.current_state = player.State.FLYING
	await create_timer(0.2).timeout
	
	var post_flight_count = world_gen.active_platforms.size()
	print("  Pads count before off-route flight: %d | after: %d" % [pre_flight_count, post_flight_count])
	assert(post_flight_count == pre_flight_count, "NO magic platforms must spawn when player flies off route")
	print("  ✅ No magic platforms spawned off-route PASSED!")

	# ====================================================
	# 4. TEST E: PLATFORM SKIPPING (PAD 1 -> PAD 3)
	# ====================================================
	print("\n--- TEST 4 (E): PLATFORM SKIPPING (PAD 1 -> PAD 3) ---")
	var pad3 = world_gen.get_platform_by_index(3)
	var pad3_pos = pad3.get_landing_position()
	
	player.global_position = pad3_pos
	player.velocity = Vector2.ZERO
	main._on_player_landed(pad3, true)
	await create_timer(0.15).timeout
	
	print("  Landed on Pad 03 directly (skipped Pad 02)! Current: %s | Next: %s" % [
		world_gen.current_platform.name, world_gen.next_platform.name if world_gen.next_platform else "none"
	])
	assert(world_gen.current_platform == pad3, "Skipped landing on Pad 03 must become current")
	assert(world_gen.next_platform == world_gen.get_platform_by_index(4), "Next target must be Pad 04")
	print("  ✅ Platform skipping PASSED!")
	
	_capture_screenshot("route_skipped_pad.png")
	await create_timer(0.2).timeout

	# ====================================================
	# 5. TEST B: ZERO FUEL GLIDING
	# ====================================================
	print("\n--- TEST 5 (B): ZERO-FUEL GLIDE TEST ---")
	var pad4 = world_gen.get_platform_by_index(4)
	player.global_position = pad4.get_landing_position() + Vector2(0.0, -70.0)
	player.velocity = Vector2(0.0, 40.0)
	player.fuel = 0.0 # Zero fuel!
	player.current_state = player.State.FLYING
	await create_timer(0.08).timeout
	
	assert(player.current_state == player.State.FLYING, "Player must remain alive when fuel hits 0")
	player.global_position = pad4.get_landing_position()
	player.velocity = Vector2.ZERO
	main._on_player_landed(pad4, false)
	await create_timer(0.15).timeout
	
	assert(player.fuel >= 99.0, "Touchdown after zero fuel glide must refill fuel")
	print("  ✅ Zero fuel glide and recovery PASSED!")

	# ====================================================
	# 6. TEST G: CONTINUOUS ROUTE ADVANCEMENT TO 100m, 300m, 500m+
	# ====================================================
	print("\n--- TEST 6 (G): CONTINUOUS ROUTE FLIGHT & MILESTONE PROGRESSION ---")
	var curr_idx = 4
	var cap_100 = false
	var cap_300 = false
	var cap_500 = false
	
	while curr_idx < 30 and not cap_500:
		curr_idx += 1
		var target_pad = world_gen.get_platform_by_index(curr_idx)
		if not is_instance_valid(target_pad):
			break
			
		var target_pos = target_pad.get_landing_position()
		
		# Hop towards target
		player.set_mobile_inputs(target_pos.x < player.global_position.x, target_pos.x > player.global_position.x, true)
		await create_timer(0.12).timeout
		
		# Land safely on target pad
		player.global_position = target_pos
		player.velocity = Vector2.ZERO
		player.set_mobile_inputs(false, false, false)
		main._on_player_landed(target_pad, true)
		await create_timer(0.1).timeout
		
		if not cap_100 and main.current_altitude >= 100:
			cap_100 = true
			_capture_screenshot("route_altitude_100m.png")
			print("  📸 Captured route_altitude_100m.png (Alt: %dm, Pad #%02d)" % [main.current_altitude, curr_idx])
			
		if not cap_300 and main.current_altitude >= 300:
			cap_300 = true
			_capture_screenshot("route_altitude_300m.png")
			print("  📸 Captured route_altitude_300m.png (Alt: %dm, Pad #%02d)" % [main.current_altitude, curr_idx])
			
		if not cap_500 and main.current_altitude >= 500:
			cap_500 = true
			_capture_screenshot("route_altitude_500m.png")
			print("  📸 Captured route_altitude_500m.png (Alt: %dm, Pad #%02d)" % [main.current_altitude, curr_idx])

	print("\n=== MARS: MARS ROUTE-BASED GAMEPLAY TEST SUITE COMPLETE! ===")
	await create_timer(0.2).timeout
	quit(0)

func _capture_screenshot(filename: String) -> void:
	var img = root.get_viewport().get_texture().get_image()
	if img:
		var save_path = ARTIFACT_DIR + "/" + filename
		var err = img.save_png(save_path)
		print("    📸 Saved %s (result=%d)" % [filename, err])
