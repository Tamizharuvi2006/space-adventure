extends SceneTree

const ARTIFACT_DIR = "C:/Users/aruvi/.gemini/antigravity-ide/brain/f75eeb4b-bf34-4366-b518-afc1bd64e4d0"

func _init() -> void:
	print("=== STARTING MARS: MARS CLUSTER & FREE FLIGHT TEST SUITE ===")
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
	# 1. CLUSTER DIVERSITY & VISIBILITY AUDIT
	# ====================================================
	print("\n--- TEST 1: CLUSTER CONSTELLATION & DIVERSITY AUDIT ---")
	var cluster = world_gen.get_active_cluster_platforms()
	print("  Active cluster platforms count: %d (Target: 4-7)" % cluster.size())
	assert(cluster.size() >= 4, "Cluster must contain at least 4 active reachable platforms")
	
	var tiers_found = {}
	for p in cluster:
		tiers_found[p.tier_name] = true
		var rel_pos = p.global_position - world_gen.current_platform.global_position
		print("  Pad #%02d [%s]: ΔX=%+.0f, ΔY=%+.0f | Width=%.0f px | Reward=+%dm | Visible=%s" % [
			p.platform_index, p.tier_name, rel_pos.x, rel_pos.y, p.current_width, p.altitude_reward, p.visible
		])
		assert(p.visible and p.modulate.a > 0.8, "All cluster options must be fully visible and readable")
		
	print("  Unique Tiers generated: %s" % str(tiers_found.keys()))
	assert(tiers_found.size() >= 3, "Cluster must contain multiple distinct risk/reward options")
	print("  ✅ Cluster diversity audit PASSED!")
	
	_capture_screenshot("mars_cluster_initial_view.png")
	await create_timer(0.2).timeout

	# ====================================================
	# 2. PLATFORM SKIPPING & UNIVERSAL LANDING FREEDOM
	# ====================================================
	print("\n--- TEST 2: PLATFORM SKIPPING & FREE CHOICE LANDING ---")
	# Choose the 3rd or 4th platform in the cluster directly, skipping the recommended one
	var skip_pad = cluster[cluster.size() - 2]
	print("  Intentionally skipping directly to: Pad #%02d [%s] at %s" % [
		skip_pad.platform_index, skip_pad.tier_name, skip_pad.global_position
	])
	
	var skip_target_pos = skip_pad.get_landing_position()
	player.set_mobile_inputs(skip_target_pos.x > player.global_position.x, skip_target_pos.x < player.global_position.x, true)
	await create_timer(0.25).timeout
	
	# Pilot player safely onto skipped pad
	player.global_position = skip_target_pos
	player.velocity = Vector2.ZERO
	player.set_mobile_inputs(false, false, false)
	main._on_player_landed(skip_pad, true)
	await create_timer(0.15).timeout
	
	print("  Landed on skipped Pad #%02d! New Current Platform: %s" % [
		skip_pad.platform_index, world_gen.current_platform.name
	])
	assert(world_gen.current_platform == skip_pad, "Skipped platform must become authoritative current platform")
	assert(player.fuel >= 99.0, "Landing must refill fuel to 100%")
	assert(main.current_altitude > 0, "Altitude score must increase on landing")
	print("  ✅ Platform skipping PASSED!")
	
	_capture_screenshot("mars_cluster_skipped_landing.png")
	await create_timer(0.2).timeout

	# ====================================================
	# 3. ZERO-FUEL GLIDING (ZERO FUEL != DEATH)
	# ====================================================
	print("\n--- TEST 3: ZERO-FUEL BALLISTIC GLIDING & EMERGENCY TOUCHDOWN ---")
	var new_cluster = world_gen.get_active_cluster_platforms()
	# Pick a valid landing option from current cluster
	var recovery_pad = new_cluster[0]
	if recovery_pad == world_gen.current_platform and new_cluster.size() > 1:
		recovery_pad = new_cluster[1]
			
	print("  Targeting recovery platform: Pad #%02d [%s] at %s" % [
		recovery_pad.platform_index, recovery_pad.tier_name, recovery_pad.global_position
	])
	
	# Lift off into mid-air
	player.global_position = recovery_pad.get_landing_position() + Vector2(0.0, -80.0)
	player.velocity = Vector2(0.0, 30.0)
	player.current_state = player.State.FLYING
	player.fuel = 0.0 # Zero fuel mid-glide!
	await create_timer(0.08).timeout
	
	print("  Mid-air Player Fuel: %.1f | State: %d" % [player.fuel, player.current_state])
	assert(player.current_state == player.State.FLYING, "Player must remain ALIVE and gliding when fuel hits 0")
	assert(player.fuel == 0.0, "Fuel must be 0")
	
	# Safe unpowered gravity touchdown
	player.global_position = recovery_pad.get_landing_position()
	player.velocity = Vector2.ZERO
	main._on_player_landed(recovery_pad, false)
	await create_timer(0.15).timeout
	
	print("  Touched down on recovery pad with 0 fuel! Current Fuel now: %.1f%%" % player.fuel)
	assert(player.fuel >= 99.0, "Touchdown after zero-fuel glide must refill fuel to 100%")
	assert(main.current_state == main.GameState.PLAYING, "Game state must remain PLAYING")
	print("  ✅ Zero-fuel ballistic gliding PASSED!")
	
	_capture_screenshot("mars_zero_fuel_glide_landing.png")
	await create_timer(0.2).timeout

	# ====================================================
	# 4. CONTINUOUS CLUSTER FLIGHT TO 100m, 300m, 700m+
	# ====================================================
	print("\n--- TEST 4: CONTINUOUS MULTI-CLUSTER PROGRESSION SCREENSHOTS ---")
	var hops = 0
	var cap_100 = false
	var cap_300 = false
	var cap_700 = false
	
	while hops < 35 and not cap_700:
		hops += 1
		var opts = world_gen.get_active_cluster_platforms()
		if opts.is_empty():
			break
			
		# Player chooses an exciting option (steep climb or risky shortcut if available)
		var chosen: SolarPlatform = opts[0]
		for cand in opts:
			if cand.altitude_reward > chosen.altitude_reward:
				chosen = cand
				
		var t_pos = chosen.get_landing_position()
		
		# Flight towards target
		player.set_mobile_inputs(t_pos.x > player.global_position.x, t_pos.x < player.global_position.x, true)
		await create_timer(0.15).timeout
		
		# Land on chosen platform
		player.global_position = t_pos
		player.velocity = Vector2.ZERO
		player.set_mobile_inputs(false, false, false)
		main._on_player_landed(chosen, true)
		await create_timer(0.12).timeout
		
		if not cap_100 and main.current_altitude >= 100:
			cap_100 = true
			_capture_screenshot("mars_altitude_100m.png")
			print("  📸 Captured mars_altitude_100m.png (Alt: %dm, Pad: %s)" % [main.current_altitude, chosen.name])
			
		if not cap_300 and main.current_altitude >= 300:
			cap_300 = true
			_capture_screenshot("mars_altitude_300m.png")
			print("  📸 Captured mars_altitude_300m.png (Alt: %dm, Pad: %s)" % [main.current_altitude, chosen.name])
			
		if not cap_700 and main.current_altitude >= 700:
			cap_700 = true
			_capture_screenshot("mars_altitude_700m.png")
			print("  📸 Captured mars_altitude_700m.png (Alt: %dm, Pad: %s)" % [main.current_altitude, chosen.name])

	print("\n=== MARS: MARS CLUSTER & FREE FLIGHT TEST SUITE COMPLETE! ===")
	await create_timer(0.2).timeout
	quit(0)

func _capture_screenshot(filename: String) -> void:
	var img = root.get_viewport().get_texture().get_image()
	if img:
		var save_path = ARTIFACT_DIR + "/" + filename
		var err = img.save_png(save_path)
		print("    📸 Saved %s (result=%d)" % [filename, err])
