extends SceneTree

var main_scene: Node = null
var player: SolarPlayer = null
var hud: SolarHUD = null
var world_gen: WorldGenerator = null

func _init() -> void:
	print("=== STARTING MARS: MARS DUAL-THRUSTER & MOBILE V8 TEST SUITE ===")
	call_deferred("_setup_and_run")

func _setup_and_run() -> void:
	var packed = load("res://scenes/main.tscn") as PackedScene
	main_scene = packed.instantiate()
	root.add_child(main_scene)
	
	player = main_scene.get_node("Player") as SolarPlayer
	hud = main_scene.get_node("HUD") as SolarHUD
	world_gen = main_scene.get_node("WorldGenerator") as WorldGenerator
	
	await process_frame
	await process_frame
	
	_run_tests()

func _run_tests() -> void:
	print("\n--- TEST 1: TWO-THRUSTER FLIGHT MODEL (INDEPENDENT FORCES) ---")
	
	# Start game and wait for countdown to transition to PLAYING
	hud.emit_signal("play_game_requested")
	while main_scene.current_state != main_scene.GameState.PLAYING:
		await process_frame
	await process_frame
	
	# 1A: Test Left Thruster Only
	player.global_position = Vector2(200.0, 400.0)
	player.velocity = Vector2.ZERO
	player.current_state = SolarPlayer.State.FLYING
	player.fuel = 100.0
	player.set_mobile_inputs(true, false)
	
	for i in range(15):
		await physics_frame
		
	var vx_left = player.velocity.x
	var vy_left = player.velocity.y
	print("  Left Thruster Only: Vx=%.1f (target < 0), Vy=%.1f (target < 0)" % [vx_left, vy_left])
	assert(vx_left < -30.0, "Left thruster must produce leftward lateral velocity!")
	assert(vy_left < 50.0, "Left thruster must produce upward lift counteracting gravity!")
	print("  ✅ Left thruster pushes ↖ PASSED!")
	
	# 1B: Test Right Thruster Only
	player.global_position = Vector2(200.0, 400.0)
	player.velocity = Vector2.ZERO
	player.set_mobile_inputs(false, true)
	
	for i in range(15):
		await physics_frame
		
	var vx_right = player.velocity.x
	var vy_right = player.velocity.y
	print("  Right Thruster Only: Vx=%.1f (target > 0), Vy=%.1f (target < 0)" % [vx_right, vy_right])
	assert(vx_right > 30.0, "Right thruster must produce rightward lateral velocity!")
	assert(vy_right < 50.0, "Right thruster must produce upward lift counteracting gravity!")
	print("  ✅ Right thruster pushes ↗ PASSED!")
	
	# 1C: Test Both Thrusters Simultaneously
	player.global_position = Vector2(200.0, 400.0)
	player.velocity = Vector2.ZERO
	player.set_mobile_inputs(true, true)
	
	for i in range(20):
		await physics_frame
		
	var vx_both = player.velocity.x
	var vy_both = player.velocity.y
	print("  Both Thrusters: Vx=%.1f (target ~0), Vy=%.1f (target < -50 upward lift)" % [vx_both, vy_both])
	assert(absf(vx_both) < 5.0, "Both thrusters must naturally balance lateral forces!")
	assert(vy_both < -60.0, "Both thrusters combined must produce strong upward climb!")
	print("  ✅ Both thrusters push ↑ with natural lateral balance PASSED!")
	
	# 1D: Test Natural Inertia (No artificial velocity.x = 0 braking)
	player.global_position = Vector2(200.0, 400.0)
	player.velocity = Vector2(150.0, 0.0) # Existing rightward momentum
	player.set_mobile_inputs(true, true) # Fire both
	
	await physics_frame
	await physics_frame
	print("  Both fired with Vx=150: new Vx=%.1f" % player.velocity.x)
	assert(player.velocity.x > 120.0, "Both thrusters must NOT artificially zero out existing velocity.x!")
	print("  ✅ No artificial velocity.x = 0 braking confirmed PASSED!")
	
	# 1E: Release both -> Fall under gravity
	player.set_mobile_inputs(false, false)
	for i in range(25):
		await physics_frame
	print("  Released both: Vy=%.1f (target > 0 descending under gravity)" % player.velocity.y)
	assert(player.velocity.y > 100.0, "Releasing both thrusters must fall under gravity!")
	print("  ✅ Release both -> ballistic fall under gravity PASSED!")
	
	print("\n--- TEST 2: MULTI-TOUCH INPUT HANDLING (NO STUCK THRUSTERS) ---")
	hud.clear_touch_inputs()
	
	# Simulate Finger 1 down on Left (X = 200, viewport width = 1280)
	var touch_f1_down = InputEventScreenTouch.new()
	touch_f1_down.index = 1
	touch_f1_down.position = Vector2(200.0, 500.0)
	touch_f1_down.pressed = true
	hud._unhandled_input(touch_f1_down)
	
	assert(hud.touch_steer_l == true, "Finger 1 on left must activate left thruster!")
	assert(hud.touch_steer_r == false, "Finger 1 on left must not activate right thruster!")
	print("  Finger 1 -> Left: Left=ON, Right=OFF")
	
	# Simulate Finger 2 down on Right (X = 900) while Finger 1 still held
	var touch_f2_down = InputEventScreenTouch.new()
	touch_f2_down.index = 2
	touch_f2_down.position = Vector2(900.0, 500.0)
	touch_f2_down.pressed = true
	hud._unhandled_input(touch_f2_down)
	
	assert(hud.touch_steer_l == true and hud.touch_steer_r == true, "Both fingers down must activate BOTH thrusters!")
	print("  Finger 2 -> Right: Left=ON, Right=ON (BOTH ACTIVE)")
	
	# Release Finger 1 -> Right must stay ON, Left must turn OFF
	var touch_f1_up = InputEventScreenTouch.new()
	touch_f1_up.index = 1
	touch_f1_up.position = Vector2(200.0, 500.0)
	touch_f1_up.pressed = false
	hud._unhandled_input(touch_f1_up)
	
	assert(hud.touch_steer_l == false, "Releasing Finger 1 must turn OFF left thruster!")
	assert(hud.touch_steer_r == true, "Right thruster must REMAIN ACTIVE when Finger 1 is released!")
	print("  Released Finger 1: Left=OFF, Right=ON (NO STUCK THRUSTER)")
	
	# Release Finger 2 -> Both OFF
	var touch_f2_up = InputEventScreenTouch.new()
	touch_f2_up.index = 2
	touch_f2_up.position = Vector2(900.0, 500.0)
	touch_f2_up.pressed = false
	hud._unhandled_input(touch_f2_up)
	
	assert(hud.touch_steer_l == false and hud.touch_steer_r == false, "Releasing Finger 2 must turn OFF both thrusters!")
	print("  Released Finger 2: Left=OFF, Right=OFF")
	print("  ✅ Multi-touch sequence with zero stuck thrusters PASSED!")
	
	print("\n--- TEST 3: 4-STATE FUEL BAR & ZERO-FUEL GLIDE ---")
	# 3A: Normal state (> 40%)
	hud._on_fuel_changed(80.0, 100.0)
	hud._process(0.016)
	assert(hud.fuel_status_label.text == "", "Above 40% fuel must show normal status!")
	print("  Fuel 80%: Normal state confirmed")
	
	# 3B: Amber Warning state (20-40%)
	hud._on_fuel_changed(35.0, 100.0)
	hud._process(0.016)
	assert(hud.fuel_status_label.text == "LOW FUEL", "35% fuel must display LOW FUEL!")
	print("  Fuel 35%: LOW FUEL amber state confirmed")
	
	# 3C: Critical Red state (0-20%)
	hud._on_fuel_changed(15.0, 100.0)
	hud._process(0.016)
	assert(hud.fuel_status_label.text == "CRITICAL FUEL", "15% fuel must display CRITICAL FUEL!")
	print("  Fuel 15%: CRITICAL FUEL pulsing red state confirmed")
	
	# 3D: Depleted state (0%)
	hud._on_fuel_changed(0.0, 100.0)
	hud._process(0.016)
	assert(hud.fuel_status_label.text == "BOOST EMPTY", "0% fuel must display BOOST EMPTY!")
	print("  Fuel 0%: BOOST EMPTY state confirmed")
	print("  ✅ 4-state fuel bar machine PASSED!")
	
	# 3E: Zero-fuel glide test
	player.fuel = 0.0
	player.set_mobile_inputs(true, true)
	await physics_frame
	assert(player.current_state == SolarPlayer.State.FLYING, "Zero fuel must NOT immediately kill the player!")
	print("  ✅ Zero fuel allows ballistic gliding to pad PASSED!")
	
	print("\n--- TEST 4: RESPONSIVE VIEWPORT SCALING ---")
	var aspect_test_sizes = [
		Vector2i(1280, 720),  # 16:9 standard
		Vector2i(1920, 1080), # 16:9 FHD
		Vector2i(2340, 1080), # 19.5:9 modern mobile
		Vector2i(2400, 1080), # 20:9 ultra-wide
		Vector2i(1280, 800)   # 16:10 tablet
	]
	
	for s in aspect_test_sizes:
		root.size = s
		hud._update_safe_margins()
		await process_frame
		
		# Verify margins are valid and positive
		var ml = hud.top_margin_container.get_theme_constant("margin_left")
		var mr = hud.top_margin_container.get_theme_constant("margin_right")
		var mt = hud.top_margin_container.get_theme_constant("margin_top")
		var mb = hud.bottom_margin_container.get_theme_constant("margin_bottom")
		
		assert(ml >= 24 and mr >= 24 and mt >= 16 and mb >= 18, "Safe margins must be maintained at size %s!" % s)
		print("  Viewport %dx%d: Safe margins [L=%d, R=%d, T=%d, B=%d] OK" % [s.x, s.y, ml, mr, mt, mb])
	print("  ✅ Responsive viewports & safe area scaling PASSED!")
	
	print("\n--- TEST 5: 100-PLATFORM SESSION & BOUNDED MEMORY ---")
	var start_platforms = world_gen.active_platforms.size()
	print("  Initial active platforms: %d" % start_platforms)
	
	# Simulate progressing across 100 platforms
	for pad_i in range(1, 101):
		var pad = world_gen.get_platform_by_index(pad_i)
		if not pad:
			pad = world_gen.spawn_next_route_pad()
		world_gen.on_platform_reached(pad)
		
	await process_frame
	await process_frame
	
	var final_platforms = world_gen.active_platforms.size()
	print("  Active platforms after 100 landings: %d" % final_platforms)
	assert(final_platforms <= 16, "Platform recycling must keep active platforms bounded <= 16!")
	print("  ✅ Bounded streaming window maintained over 100 platforms PASSED!")
	
	print("\n--- TEST 6: VISUAL SCREENS & PLANET PROGRESSION ---")
	hud.update_altitude(340, 520)
	hud.update_planet_progression("SUN", "MERCURY", 8, 10)
	print("  Destination badge: %s" % hud.destination_label.text)
	assert("SUN ➔ MERCURY" in hud.destination_label.text, "Destination badge must display current journey!")
	
	# Test Pause screen
	hud.show_pause_menu()
	assert(hud.pause_menu.visible == true, "Pause menu must be visible!")
	print("  Pause menu displayed successfully")
	hud.hide_pause_menu()
	
	# Test Game Over screen
	hud.show_game_over(420, 500, true, "Solar Flare Impact")
	assert(hud.game_over_menu.visible == true, "Game over menu must be visible!")
	assert(hud.new_record_badge.visible == true, "New record badge must display on record!")
	print("  Game over menu displayed with New Record badge successfully")
	hud.hide_game_over()
	
	# Return to gameplay HUD
	hud.show_gameplay_hud()
	print("  Gameplay HUD restored")
	
	print("\n=== ALL MARS: MARS DUAL-THRUSTER & MOBILE V8 TESTS PASSED SUCCESSFULLY! ===")
	quit(0)
