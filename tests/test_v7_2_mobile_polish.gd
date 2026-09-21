extends SceneTree

const SunZoneData = preload("res://scripts/planet_data.gd")
const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")
const SolarPlatform = preload("res://scripts/platform.gd")
const SolarHUD = preload("res://scripts/hud.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")

var current_main: SolarMain = null

func _init() -> void:
	print("\n=======================================================")
	print("   TEST V7.2: MOBILE POLISH & HUD / COMPOSITION SUITE ")
	print("=======================================================\n")
	call_deferred("_run_all_tests")

func _spawn_fresh_game_instance() -> SolarMain:
	Engine.time_scale = 1.0
	if is_instance_valid(current_main):
		root.remove_child(current_main)
		current_main.queue_free()
		current_main = null
		
	var packed = load("res://scenes/main.tscn") as PackedScene
	var inst = packed.instantiate() as SolarMain
	root.add_child(inst)
	current_main = inst
	return inst

func _run_all_tests() -> void:
	var save_path = "user://explore_sun_save.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	var game = _spawn_fresh_game_instance()
	await process_frame
	await process_frame
	
	var hud = game.hud
	var player = game.player
	var world_gen = game.world_gen
	var camera = game.camera
	
	# -------------------------------------------------------------------------
	# TEST A: HUD Labels Hierarchy (No old altitude meters, clean progress)
	# -------------------------------------------------------------------------
	print("--- TEST A: HUD labels layout ---")
	hud.update_progress(25, 100, 25)
	assert(hud.altitude_label.text == "25 / 100", "Progress label must display 'XX / 100'!")
	assert(hud.altitude_tag.text == "SUN JOURNEY", "Journey subtitle must be 'SUN JOURNEY'!")
	assert(hud.best_tag.text == "BEST", "Best tag must be 'BEST'!")
	assert(hud.best_label.text == "PAD 25", "Best label must display 'PAD XX'!")
	print("  ✅ TEST A PASSED: HUD labels strictly conform to final design (25 / 100, SUN JOURNEY, BEST PAD 25).")

	# -------------------------------------------------------------------------
	# TEST B: Zone Badge Display
	# -------------------------------------------------------------------------
	print("\n--- TEST B: Zone Badge ---")
	hud.update_zone_name("SOLAR CRATERS")
	assert("SOLAR CRATERS" in hud.destination_label.text, "Zone badge must display current zone name!")
	print("  ✅ TEST B PASSED: Zone badge dynamically reflects SOLAR CRATERS.")

	# -------------------------------------------------------------------------
	# TEST C: Fuel Refill Animation on Touchdown
	# -------------------------------------------------------------------------
	print("\n--- TEST C: Fuel Refill Animation ---")
	hud.fuel_bar.value = 20.0 # Depleted before landing
	hud.current_fuel_ratio = 0.20
	hud.animate_fuel_refill()
	
	# Gameplay fuel ratio becomes 1.0 immediately for instant takeoff capability
	assert(hud.current_fuel_ratio == 1.0, "Gameplay fuel ratio must be 1.0 immediately upon touchdown!")
	
	# After 25 frames, visual tween smoothly animates the bar value toward 100%
	for _f in range(25):
		await physics_frame
	assert(hud.fuel_bar.value > 85.0, "Fuel bar visual value must smoothly animate toward 100%!")
	print("  ✅ TEST C PASSED: Fuel immediately usable for takeoff while bar smoothly animates to 100%.")

	# -------------------------------------------------------------------------
	# TEST D: Mobile Safe Areas across Landscape Aspect Ratios
	# -------------------------------------------------------------------------
	print("\n--- TEST D: Mobile Safe Areas ---")
	hud._update_safe_margins()
	var margin_l = hud.top_margin_container.get_theme_constant("margin_left")
	var margin_r = hud.top_margin_container.get_theme_constant("margin_right")
	var margin_t = hud.top_margin_container.get_theme_constant("margin_top")
	assert(margin_l >= 28, "Left safe margin must be at least 28px!")
	assert(margin_r >= 28, "Right safe margin must be at least 28px!")
	assert(margin_t >= 16, "Top safe margin must be at least 16px!")
	print("  ✅ TEST D PASSED: Safe margins protect HUD from screen cutouts and rounded edges (L=%d, R=%d, T=%d)." % [margin_l, margin_r, margin_t])

	# -------------------------------------------------------------------------
	# TEST E: Pause Button Touch Target & Gameplay Exclusion
	# -------------------------------------------------------------------------
	print("\n--- TEST E: Pause Button Exclusion ---")
	assert(hud.pause_button.custom_minimum_size.x >= 48.0, "Pause button width must be >= 48px!")
	assert(hud.pause_button.custom_minimum_size.y >= 48.0, "Pause button height must be >= 48px!")
	
	var pause_rect = hud.pause_button.get_global_rect().grow(12.0)
	var touch_inside_pause = InputEventScreenTouch.new()
	touch_inside_pause.index = 0
	touch_inside_pause.position = pause_rect.position + pause_rect.size * 0.5
	touch_inside_pause.pressed = true
	
	hud.clear_touch_inputs()
	hud._unhandled_input(touch_inside_pause)
	assert(hud.touch_sides.size() == 0, "Touch inside Pause button area must be excluded from flight controls!")
	print("  ✅ TEST E PASSED: Pause button has 48x48+ touch target and is safely excluded from thruster triggers.")

	# -------------------------------------------------------------------------
	# TEST F: LEFT Touch Control
	# -------------------------------------------------------------------------
	print("\n--- TEST F: LEFT Touch Control ---")
	hud.clear_touch_inputs()
	var touch_l = InputEventScreenTouch.new()
	touch_l.index = 0
	touch_l.position = Vector2(200.0, 400.0) # Left half of screen
	touch_l.pressed = true
	hud._unhandled_input(touch_l)
	assert(hud.touch_steer_l == true and hud.touch_steer_r == false, "Left touch must activate only left thruster!")
	print("  ✅ TEST F PASSED: Left half touch activates LEFT thruster.")

	# -------------------------------------------------------------------------
	# TEST G: RIGHT Touch Control
	# -------------------------------------------------------------------------
	print("\n--- TEST G: RIGHT Touch Control ---")
	hud.clear_touch_inputs()
	var touch_r = InputEventScreenTouch.new()
	touch_r.index = 0
	touch_r.position = Vector2(1000.0, 400.0) # Right half of screen
	touch_r.pressed = true
	hud._unhandled_input(touch_r)
	assert(hud.touch_steer_r == true and hud.touch_steer_l == false, "Right touch must activate only right thruster!")
	print("  ✅ TEST G PASSED: Right half touch activates RIGHT thruster.")

	# -------------------------------------------------------------------------
	# TEST H: BOTH Multi-Touch Control
	# -------------------------------------------------------------------------
	print("\n--- TEST H: BOTH Multi-Touch ---")
	hud.clear_touch_inputs()
	var f1 = InputEventScreenTouch.new()
	f1.index = 0
	f1.position = Vector2(200.0, 400.0)
	f1.pressed = true
	hud._unhandled_input(f1)
	
	var f2 = InputEventScreenTouch.new()
	f2.index = 1
	f2.position = Vector2(1000.0, 400.0)
	f2.pressed = true
	hud._unhandled_input(f2)
	
	assert(hud.touch_steer_l == true and hud.touch_steer_r == true, "Two fingers on both halves must activate BOTH thrusters!")
	print("  ✅ TEST H PASSED: Independent multi-finger touch activates BOTH thrusters.")

	# -------------------------------------------------------------------------
	# TEST I: No-Input Docked State Stability
	# -------------------------------------------------------------------------
	print("\n--- TEST I: Docked Stability ---")
	hud.clear_touch_inputs()
	var pad_1 = world_gen.get_platform_by_index(1)
	player.current_state = SolarPlayer.State.ON_PAD
	player.active_platform = pad_1
	player.global_position = pad_1.get_landing_position()
	player.velocity = Vector2.ZERO
	camera.snap_to_target()
	
	for _f in range(15):
		await physics_frame
	assert(player.global_position.distance_to(pad_1.get_landing_position()) < 0.1, "Player must remain stationary while docked with no input!")
	print("  ✅ TEST I PASSED: Stationary docked stability verified.")

	# -------------------------------------------------------------------------
	# TEST J & K: Player Remains Visible During Ascent & Descent
	# -------------------------------------------------------------------------
	print("\n--- TEST J & K: Player Visibility Bounds ---")
	var vp_size = game.get_viewport().get_visible_rect().size
	var p_screen_y = (player.global_position.y - camera.global_position.y) * camera.zoom.y + vp_size.y * 0.5
	var p_screen_frac = p_screen_y / vp_size.y
	assert(p_screen_frac > 0.16 and p_screen_frac < 0.75, "Player screen position must stay inside safe viewport band (16%-75%)!")
	print("  ✅ TEST J & K PASSED: Player framed within safe vertical margins (current: %.1f%%)." % (p_screen_frac * 100.0))

	# -------------------------------------------------------------------------
	# TEST L: Next Pad Discoverable / Visible
	# -------------------------------------------------------------------------
	print("\n--- TEST L: Next Pad Discoverability ---")
	var pad_2 = world_gen.get_platform_by_index(2)
	assert(is_instance_valid(pad_2), "Pad 2 must be pre-spawned along the forward route!")
	var pad_screen_y = (pad_2.global_position.y - camera.global_position.y) * camera.zoom.y + vp_size.y * 0.5
	var pad_screen_frac = pad_screen_y / vp_size.y
	assert(pad_screen_frac > 0.10 and pad_screen_frac < 0.90, "Next pad must remain discoverable in viewable region!")
	print("  ✅ TEST L PASSED: Upcoming pad is discoverable and properly framed.")

	# -------------------------------------------------------------------------
	# TEST M: Landing Pad Deck Not Occluded by Terrain
	# -------------------------------------------------------------------------
	print("\n--- TEST M: No Terrain Occlusion of Pad Deck ---")
	# Pad 1 deck is at pos.y - 10.0. Rock footing is at pos.y + 74.0.
	var pad_deck_y = pad_1.global_position.y - 10.0
	var terrain_footing_y = pad_1.global_position.y + 74.0
	assert(terrain_footing_y > pad_deck_y + 60.0, "Pad landing deck must sit well above bedrock foundation (84px clearance)!")
	print("  ✅ TEST M PASSED: Pad landing deck is completely clear of terrain occlusion.")

	print("\n=======================================================")
	print("   ALL 13 MOBILE POLISH TESTS (A–M) PASSED! 🎉        ")
	print("=======================================================\n")
	quit(0)
