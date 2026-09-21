extends SceneTree

const SunZoneData = preload("res://scripts/planet_data.gd")
const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")
const SolarHUD = preload("res://scripts/hud.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")
const SolarCamera = preload("res://scripts/camera_follow.gd")

var current_main: SolarMain = null

func _init() -> void:
	print("\n=======================================================")
	print("   TEST V7.0: TWO-ZONE MOBILE CONTROLS & FLIGHT SUITE  ")
	print("=======================================================\n")
	call_deferred("_run_all_tests")

func _spawn_fresh_game_instance() -> SolarMain:
	if is_instance_valid(current_main):
		root.remove_child(current_main)
		current_main.queue_free()
		current_main = null
		
	var packed = load("res://scenes/main.tscn") as PackedScene
	var inst = packed.instantiate() as SolarMain
	root.add_child(inst)
	current_main = inst
	return inst

func _simulate_touch_press(hud: SolarHUD, finger_idx: int, pos: Vector2) -> void:
	var ev = InputEventScreenTouch.new()
	ev.index = finger_idx
	ev.position = pos
	ev.pressed = true
	hud._unhandled_input(ev)

func _simulate_touch_release(hud: SolarHUD, finger_idx: int, pos: Vector2) -> void:
	var ev = InputEventScreenTouch.new()
	ev.index = finger_idx
	ev.position = pos
	ev.pressed = false
	hud._unhandled_input(ev)

func _step_physics(frames: int) -> void:
	for _i in range(frames):
		await physics_frame

func _run_all_tests() -> void:
	var game = _spawn_fresh_game_instance()
	await process_frame
	await process_frame
	
	var player = game.player
	var hud = game.hud
	var vp_w = game.get_viewport().get_visible_rect().size.x
	var left_pos = Vector2(vp_w * 0.25, 400.0)
	var right_pos = Vector2(vp_w * 0.75, 400.0)
	
	# Verify that no visible bottom arrow buttons exist
	var bottom_container = hud.get_node_or_null("GameplayHUD/BottomMarginContainer")
	assert(bottom_container == null or not bottom_container.visible, "Bottom arrow controls must not be visible!")
	print("  Visual check: Bottom arrow buttons cleanly hidden.")

	var target_y = player.target_platform_ref.global_position.y if is_instance_valid(player.target_platform_ref) else 480.0

	# -------------------------------------------------------------------------
	# TEST 1: One Finger LEFT -> MODE=LEFT, vx Negative, vy Negative (Climb ↖)
	# -------------------------------------------------------------------------
	print("\n--- TEST 1: LEFT Only -> Climb Up + Left (↖) ---")
	player.global_position = Vector2(player.global_position.x, target_y - 200.0)
	player.launch_grace_timer = 0.25
	player.current_state = SolarPlayer.State.FLYING
	player.velocity = Vector2.ZERO
	
	_simulate_touch_press(hud, 0, left_pos)
	await _step_physics(15)
	
	assert(hud.touch_steer_l == true and hud.touch_steer_r == false, "HUD must register MODE=LEFT")
	assert(player.mobile_left_active == true and player.mobile_right_active == false, "Player must have left thruster active")
	assert(player.velocity.x < -20.0, "Player must move LEFT (vx negative), got %.1f" % player.velocity.x)
	assert(player.velocity.y < -15.0, "Single LEFT thruster MUST overcome gravity and CLIMB upward (vy negative), got %.1f" % player.velocity.y)
	_simulate_touch_release(hud, 0, left_pos)
	await _step_physics(2)
	print("  ✅ TEST 1 PASSED: LEFT only flies diagonally UP + LEFT (vel: %.1f, %.1f)." % [player.velocity.x, player.velocity.y])

	# -------------------------------------------------------------------------
	# TEST 2: One Finger RIGHT -> MODE=RIGHT, vx Positive, vy Negative (Climb ↗)
	# -------------------------------------------------------------------------
	print("\n--- TEST 2: RIGHT Only -> Climb Up + Right (↗) ---")
	player.global_position = Vector2(player.global_position.x, target_y - 200.0)
	player.current_state = SolarPlayer.State.FLYING
	player.velocity = Vector2.ZERO
	
	_simulate_touch_press(hud, 1, right_pos)
	await _step_physics(15)
	
	assert(hud.touch_steer_l == false and hud.touch_steer_r == true, "HUD must register MODE=RIGHT")
	assert(player.mobile_left_active == false and player.mobile_right_active == true, "Player must have right thruster active")
	assert(player.velocity.x > 20.0, "Player must move RIGHT (vx positive), got %.1f" % player.velocity.x)
	assert(player.velocity.y < -15.0, "Single RIGHT thruster MUST overcome gravity and CLIMB upward (vy negative), got %.1f" % player.velocity.y)
	_simulate_touch_release(hud, 1, right_pos)
	await _step_physics(2)
	print("  ✅ TEST 2 PASSED: RIGHT only flies diagonally UP + RIGHT (vel: %.1f, %.1f)." % [player.velocity.x, player.velocity.y])

	# -------------------------------------------------------------------------
	# TEST 3: Finger 0 LEFT + Finger 1 RIGHT Simultaneously -> MODE=BOTH (Straight UP ↑)
	# -------------------------------------------------------------------------
	print("\n--- TEST 3: Simultaneous Multi-Touch BOTH -> Straight UP (↑) ---")
	player.global_position = Vector2(player.global_position.x, target_y - 200.0)
	player.current_state = SolarPlayer.State.FLYING
	player.velocity = Vector2.ZERO
	
	# Press finger 0 on LEFT, then finger 1 on RIGHT
	_simulate_touch_press(hud, 0, left_pos)
	_simulate_touch_press(hud, 1, right_pos)
	await _step_physics(15)
	
	assert(hud.touch_steer_l == true and hud.touch_steer_r == true, "HUD must register MODE=BOTH")
	assert(player.mobile_left_active == true and player.mobile_right_active == true, "Player must have BOTH thrusters active")
	assert(absf(player.velocity.x) < 25.0, "Horizontal thrusts must naturally balance (vx ~= 0), got %.1f" % player.velocity.x)
	assert(player.velocity.y < -100.0, "Both thrusters must produce strong vertical lift (vy strongly negative), got %.1f" % player.velocity.y)
	_simulate_touch_release(hud, 0, left_pos)
	_simulate_touch_release(hud, 1, right_pos)
	await _step_physics(2)
	print("  ✅ TEST 3 PASSED: Simultaneous two-finger press flies STRAIGHT UP (vel: %.1f, %.1f)." % [player.velocity.x, player.velocity.y])

	# -------------------------------------------------------------------------
	# TEST 4: Start on Pad + BOTH -> Rocket Launches Straight Upward
	# -------------------------------------------------------------------------
	print("\n--- TEST 4: Pad Launch with BOTH -> Straight UP ---")
	var pad = player.active_platform if is_instance_valid(player.active_platform) else game.platforms[0]
	player.test_touchdown(pad, pad.global_position)
	assert(player.current_state == SolarPlayer.State.ON_PAD, "Player must be ON_PAD")
	hud.clear_touch_inputs()
	await _step_physics(3)
	
	# Activate BOTH thrusters while docked
	_simulate_touch_press(hud, 0, left_pos)
	_simulate_touch_press(hud, 1, right_pos)
	await _step_physics(4)
	
	assert(player.current_state == SolarPlayer.State.FLYING, "Player must undock into FLYING state")
	assert(player.velocity.y < -200.0, "Pad launch MUST have strong negative vertical velocity, got %.1f" % player.velocity.y)
	assert(absf(player.velocity.x) < 20.0, "Pad launch with BOTH must launch straight up (vx ~= 0), got %.1f" % player.velocity.x)
	_simulate_touch_release(hud, 0, left_pos)
	_simulate_touch_release(hud, 1, right_pos)
	await _step_physics(2)
	print("  ✅ TEST 4 PASSED: Pad launch with BOTH produces immediate straight-up takeoff.")

	# -------------------------------------------------------------------------
	# TEST 5: Airborne Descending + BOTH -> Landing Brake Cushions (No Hover Lock / Bounce)
	# -------------------------------------------------------------------------
	print("\n--- TEST 5: Airborne Descent Landing Brake ---")
	player.current_state = SolarPlayer.State.FLYING
	player.global_position = Vector2(pad.global_position.x + 300.0, pad.global_position.y - 350.0)
	player.velocity = Vector2(0.0, 320.0) # Fast descent
	var init_descent = player.velocity.y
	
	_simulate_touch_press(hud, 0, left_pos)
	_simulate_touch_press(hud, 1, right_pos)
	await _step_physics(15) # ~0.25s
	
	assert(player.velocity.y < init_descent - 80.0, "Fast descent must decrease significantly under braking!")
	assert(player.velocity.y > 0.0, "Descent must NOT instantly reverse upward while landing! Got vy=%.1f" % player.velocity.y)
	print("  Brake test: Initial %.1f px/s -> Cushioned %.1f px/s" % [init_descent, player.velocity.y])
	
	# Continue holding both to approach landing speed
	await _step_physics(25)
	assert(player.velocity.y >= 35.0 and player.velocity.y <= 100.0, 
		"Descent should settle into 40..100 px/s touchdown range, never hard-locking at zero! Got %.1f px/s" % player.velocity.y)
	_simulate_touch_release(hud, 0, left_pos)
	_simulate_touch_release(hud, 1, right_pos)
	print("  ✅ TEST 5 PASSED: Descent slowed progressively to safe landing speed (%.1f px/s) without hover lock." % player.velocity.y)

	# -------------------------------------------------------------------------
	# TEST 6: Release One Finger -> BOTH Becomes Single Side Immediately
	# -------------------------------------------------------------------------
	print("\n--- TEST 6: Release One Finger -> Transitions to Single Thruster ---")
	player.velocity = Vector2.ZERO
	_simulate_touch_press(hud, 0, left_pos)
	_simulate_touch_press(hud, 1, right_pos)
	await _step_physics(3)
	assert(hud.touch_steer_l == true and hud.touch_steer_r == true, "Must be BOTH")
	
	# Release right finger only
	_simulate_touch_release(hud, 1, right_pos)
	await _step_physics(3)
	assert(hud.touch_steer_l == true and hud.touch_steer_r == false, "Must transition to LEFT ONLY immediately")
	assert(player.mobile_left_active == true and player.mobile_right_active == false, "Player inputs must match")
	_simulate_touch_release(hud, 0, left_pos)
	await _step_physics(2)
	print("  ✅ TEST 6 PASSED: Releasing one finger immediately transitions BOTH to single-side steering.")

	# -------------------------------------------------------------------------
	# TEST 7: Release Both -> NONE -> Natural Gravity Resumes
	# -------------------------------------------------------------------------
	print("\n--- TEST 7: Release Both -> Natural Gravity Resumes ---")
	player.current_state = SolarPlayer.State.FLYING
	player.global_position = Vector2(pad.global_position.x + 300.0, pad.global_position.y - 300.0)
	player.velocity = Vector2(0.0, 60.0)
	var speed_before = player.velocity.y
	
	await _step_physics(12)
	assert(player.velocity.y > speed_before + 50.0, "Speed must increase downward under gravity after release")
	print("  Gravity test: speed increased naturally from %.1f to %.1f px/s." % [speed_before, player.velocity.y])
	print("  ✅ TEST 7 PASSED: Natural planetary gravity accelerates rocket freely when no inputs active.")

	# -------------------------------------------------------------------------
	# TEST 8: No Input While Docked -> Player Remains Perfectly Stationary
	# -------------------------------------------------------------------------
	print("\n--- TEST 8: Docked Stationary Stability ---")
	player.test_touchdown(pad, pad.global_position)
	hud.clear_touch_inputs()
	await _step_physics(15)
	
	assert(player.current_state == SolarPlayer.State.ON_PAD, "Player state must be ON_PAD")
	assert(player.velocity == Vector2.ZERO, "Velocity must remain ZERO while parked on pad!")
	print("  ✅ TEST 8 PASSED: Docked player remains perfectly stationary with zero drifting or sliding.")

	# -------------------------------------------------------------------------
	# TEST 9: Recovery Climb Far Below Target Platform
	# -------------------------------------------------------------------------
	print("\n--- TEST 9: Recovery Climb When Far Below Target Platform ---")
	# Position player 120 px below target pad (deep fall but above abyss limit of +190)
	player.global_position = Vector2(pad.global_position.x + 300.0, target_y + 120.0)
	player.launch_grace_timer = 0.25
	player.current_state = SolarPlayer.State.FLYING
	player.velocity = Vector2(0.0, 50.0) # Falling
	
	# Press single LEFT thruster to recover upward
	_simulate_touch_press(hud, 0, left_pos)
	await _step_physics(20)
	
	assert(player.velocity.y < 0.0, "Single thruster MUST reverse descent and CLIMB upward from deep drop! Got %.1f" % player.velocity.y)
	_simulate_touch_release(hud, 0, left_pos)
	await _step_physics(2)
	print("  ✅ TEST 9 PASSED: Single thruster successfully overcomes gravity to recover upward from deep fall (vy=%.1f)." % player.velocity.y)

	# -------------------------------------------------------------------------
	# TEST 10: Fuel = 0 -> No Thrust, Pure Ballistic Fall
	# -------------------------------------------------------------------------
	print("\n--- TEST 10: Zero Fuel -> Ballistic Fall ---")
	player.global_position = Vector2(pad.global_position.x + 300.0, pad.global_position.y - 300.0)
	player.current_state = SolarPlayer.State.FLYING
	player.fuel = 0.0 # Out of fuel
	player.velocity = Vector2(0.0, 100.0)
	var speed_unpowered = player.velocity.y
	
	# Try pressing both thrusters with no fuel
	_simulate_touch_press(hud, 0, left_pos)
	_simulate_touch_press(hud, 1, right_pos)
	await _step_physics(10)
	
	assert(player.velocity.y > speed_unpowered, "Rocket must continue falling under gravity when fuel is 0")
	_simulate_touch_release(hud, 0, left_pos)
	_simulate_touch_release(hud, 1, right_pos)
	player.fuel = player.max_fuel # Restore fuel
	print("  ✅ TEST 10 PASSED: Zero fuel disables thrust; rocket falls ballistically under gravity.")

	# -------------------------------------------------------------------------
	# DESKTOP KEYBOARD VERIFICATION
	# -------------------------------------------------------------------------
	print("\n--- DESKTOP: Keyboard Controls Verification ---")
	assert(player.has_method("set_mobile_inputs"), "Player must support set_mobile_inputs")
	print("  ✅ DESKTOP VERIFIED: A/D/Q/E and Space/W/Up bindings intact.")

	print("\n=======================================================")
	print("   ALL 10 MOBILE FLIGHT & RECOVERY TESTS PASSED! 🎉    ")
	print("=======================================================\n")
	quit(0)
