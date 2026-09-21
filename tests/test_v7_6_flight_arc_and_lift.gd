extends SceneTree

const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")

var current_main: SolarMain = null

func _init() -> void:
	print("\n=======================================================")
	print("   TEST V7.6: CONTROLLED FLIGHT ARC & REACHABILITY     ")
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
	var vp_size = game.get_viewport().get_visible_rect().size

	hud.emit_signal("play_game_requested")
	while game.current_state != SolarMain.GameState.PLAYING:
		await physics_frame
	await physics_frame

	var pad_1 = world_gen.get_platform_by_index(1)
	var pad_2 = world_gen.get_platform_by_index(2)
	assert(is_instance_valid(pad_1) and is_instance_valid(pad_2), "Pads 1 and 2 must exist!")

	# -------------------------------------------------------------------------
	# TEST 1: Launch Vertical Boost & Lift Arc
	# -------------------------------------------------------------------------
	print("--- TEST 1: Launch Liftoff — Moderate, Controlled Hop ---")
	player.spawn_on_platform(pad_1)
	for _f in range(5): await physics_frame
	var deck_y = player.global_position.y

	# Tap launch (both thrusters active for 1 frame)
	player.set_mobile_inputs(true, true)
	await physics_frame
	player.set_mobile_inputs(false, false) # Release thrusters

	# Track peak altitude of initial launch hop
	var peak_y = player.global_position.y
	for _f in range(30):
		await physics_frame
		peak_y = minf(peak_y, player.global_position.y)

	var hop_height = deck_y - peak_y
	print("  Launch tap hop height: " + str(snappedf(hop_height, 0.1)) + " px (was >80px in V7.4)")
	assert(hop_height >= 12.0 and hop_height <= 40.0, "Launch hop must be moderate and controlled (12..40px), not shooting to the sky!")
	print("  ✅ TEST 1 PASSED: Launch liftoff is controlled and gentle (" + str(snappedf(hop_height, 0.1)) + "px).")

	# -------------------------------------------------------------------------
	# TEST 2: Climb Speed Cap & Stratosphere Soft Limit
	# -------------------------------------------------------------------------
	print("\n--- TEST 2: Maximum Upward Climb Rate ---")
	player.spawn_on_platform(pad_1)
	for _f in range(5): await physics_frame

	# Hold both thrusters upward for 1.2s to test maximum climb velocity
	player.set_mobile_inputs(true, true)
	var max_vy_recorded = 0.0
	for _f in range(70):
		await physics_frame
		max_vy_recorded = minf(max_vy_recorded, player.velocity.y)

	player.set_mobile_inputs(false, false)
	print("  Max upward velocity reached: " + str(snappedf(max_vy_recorded, 0.1)) + " px/s (cap is -240)")
	assert(max_vy_recorded >= -240.0, "Climb velocity must respect the -240 px/s cap (was " + str(max_vy_recorded) + ")!")
	print("  ✅ TEST 2 PASSED: Climb rate is strictly capped and readable (" + str(snappedf(max_vy_recorded, 0.1)) + " px/s).")

	# -------------------------------------------------------------------------
	# TEST 3: Horizontal Steering Authority Preserved
	# -------------------------------------------------------------------------
	print("\n--- TEST 3: Horizontal Steering Authority ---")
	player.spawn_on_platform(pad_1)
	for _f in range(5): await physics_frame

	# Fire right thruster only to test sideways steering acceleration
	player.set_mobile_inputs(false, true)
	for _f in range(20):
		await physics_frame

	player.set_mobile_inputs(false, false)
	print("  Horizontal velocity achieved after right thrust: " + str(snappedf(player.velocity.x, 0.1)) + " px/s")
	assert(player.velocity.x > 80.0, "Horizontal steering authority must be preserved (got " + str(player.velocity.x) + " px/s)!")
	print("  ✅ TEST 3 PASSED: Horizontal steering authority is fully intact.")

	# -------------------------------------------------------------------------
	# TEST 4: Next Pad Reachability & Safe Touchdown
	# -------------------------------------------------------------------------
	print("\n--- TEST 4: Flight to Pad 2 & Landing Confirmation ---")
	player.spawn_on_platform(pad_1)
	for _f in range(5): await physics_frame

	var pad2_pos = pad_2.get_landing_position()
	var reached_pad_2 = false

	for frame_i in range(300):
		var dx_to_pad = pad2_pos.x - player.global_position.x
		var dy_to_pad = pad2_pos.y - player.global_position.y

		if dx_to_pad > 80.0:
			# Cruising toward Pad 2: maintain forward speed ~220 px/s with altitude control
			var want_climb = (player.global_position.y > pad2_pos.y - 80.0) and player.velocity.y > -80.0
			var want_forward = player.velocity.x < 220.0
			if want_forward:
				player.set_mobile_inputs(false, true) # Right thruster
			elif want_climb:
				player.set_mobile_inputs(true, true) # Dual thruster lift
			else:
				player.set_mobile_inputs(false, false)
		else:
			# Arrived above Pad 2: counteract horizontal drift and brake descent
			var brake_x = player.velocity.x > 25.0
			var brake_y = player.velocity.y > 70.0
			if brake_x:
				player.set_mobile_inputs(true, false) # Counter-steer left to kill forward drift
			elif brake_y:
				player.set_mobile_inputs(true, true) # Dual brake descent
			else:
				player.set_mobile_inputs(false, false) # Coast onto deck

		await physics_frame
		if player.current_state == SolarPlayer.State.ON_PAD or player.current_state == SolarPlayer.State.LANDED:
			if player.active_platform == pad_2 or player.last_docked_platform == pad_2:
				reached_pad_2 = true
				break

	assert(reached_pad_2, "Player must comfortably reach Pad 2 and land safely!")
	print("  ✅ TEST 4 PASSED: Explorer successfully navigated to Pad 2 and landed safely.")

	# -------------------------------------------------------------------------
	# TEST 5: Camera Follow File Was Not Modified
	# -------------------------------------------------------------------------
	print("\n--- TEST 5: Camera System Integrity ---")
	assert(camera is SolarCamera, "Camera must remain SolarCamera!")
	assert(camera.MAX_VERTICAL_CAMERA_SHIFT == 45.0, "Camera MAX_VERTICAL_CAMERA_SHIFT must remain 45.0!")
	print("  ✅ TEST 5 PASSED: Camera follow system remains intact and unmodified.")

	print("\n=======================================================")
	print("   ALL 5 V7.6 FLIGHT ARC TESTS PASSED! 🎉              ")
	print("=======================================================\n")
	quit()
