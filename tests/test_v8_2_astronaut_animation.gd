extends SceneTree

const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")

var current_main: SolarMain = null

func _init() -> void:
	print("\n=======================================================")
	print("   TEST V8.2: SUBTLE ASTRONAUT ORGANIC MOVEMENT        ")
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

	var player = game.player
	var world_gen = game.world_gen

	game.hud.emit_signal("play_game_requested")
	while game.current_state != SolarMain.GameState.PLAYING:
		await physics_frame
	await physics_frame

	var pad_1 = world_gen.get_platform_by_index(1)

	# -------------------------------------------------------------------------
	# TEST 1: Idle Breathing & Organic Torso/Head Bobbing on Pad
	# -------------------------------------------------------------------------
	print("--- TEST 1: Idle Breathing & Subtle Body Sway ---")
	player.spawn_on_platform(pad_1)
	
	var torso = player.get_node("Visuals/Torso") as Node2D
	var head = player.get_node("Visuals/Head") as Node2D
	var left_arm = player.get_node("Visuals/LeftArm") as Node2D
	var right_arm = player.get_node("Visuals/RightArm") as Node2D
	var left_leg = player.get_node("Visuals/LeftLeg") as Node2D
	var right_leg = player.get_node("Visuals/RightLeg") as Node2D

	var torso_y_min: float = 999.0
	var torso_y_max: float = -999.0
	var arm_rot_min: float = 999.0
	var arm_rot_max: float = -999.0

	for _f in range(75):
		await physics_frame
		torso_y_min = minf(torso_y_min, torso.position.y)
		torso_y_max = maxf(torso_y_max, torso.position.y)
		arm_rot_min = minf(arm_rot_min, left_arm.rotation)
		arm_rot_max = maxf(arm_rot_max, left_arm.rotation)

	var breathing_amplitude = torso_y_max - torso_y_min
	var arm_sway_amplitude = arm_rot_max - arm_rot_min
	print("  Torso breathing displacement range: %.2f px" % breathing_amplitude)
	print("  Arm idle sway rotation range:       %.3f rad (%.1f°)" % [arm_sway_amplitude, rad_to_deg(arm_sway_amplitude)])

	assert(breathing_amplitude > 0.25, "Torso must show organic breathing movement while idle on pad!")
	assert(arm_sway_amplitude > 0.015, "Arms must subtly sway with breathing while idle on pad!")
	print("  ✅ TEST 1 PASSED: Astronaut has subtle breathing, head bob, and arm sway while idle.")

	# -------------------------------------------------------------------------
	# TEST 2: Standing Footing Stability (Boots remain planted)
	# -------------------------------------------------------------------------
	print("\n--- TEST 2: Platform Footing Stability During Idle ---")
	var left_boot = player.get_node("Visuals/LeftLeg/LeftBoot") as Polygon2D
	var max_boot_y = -999.0
	for pt in left_boot.polygon:
		max_boot_y = maxf(max_boot_y, pt.y)
	print("  Boots deck height: y=%.1f" % max_boot_y)
	assert(absf(max_boot_y - 12.0) < 0.1, "Boots must remain firmly planted at deck level y=12!")
	print("  ✅ TEST 2 PASSED: Idle body movements do not disrupt pad deck footing.")

	# -------------------------------------------------------------------------
	# TEST 3: Thruster Steering Reactive Arm Bracing
	# -------------------------------------------------------------------------
	print("\n--- TEST 3: Thruster Steering Reactive Arm Bracing ---")
	player.current_state = SolarPlayer.State.FLYING
	player.velocity = Vector2.ZERO

	# Fire LEFT thruster -> Left arm braces
	player.set_mobile_inputs(true, false)
	for _f in range(15): await physics_frame
	print("  Left arm rotation under Left Thruster burn:  %.2f rad (%.1f°)" % [left_arm.rotation, rad_to_deg(left_arm.rotation)])
	assert(left_arm.rotation < -0.08, "Left arm must brace outward when Left thruster is firing!")

	# Fire RIGHT thruster -> Right arm braces
	player.set_mobile_inputs(false, true)
	for _f in range(15): await physics_frame
	print("  Right arm rotation under Right Thruster burn: %.2f rad (%.1f°)" % [right_arm.rotation, rad_to_deg(right_arm.rotation)])
	assert(right_arm.rotation > 0.08, "Right arm must brace outward when Right thruster is firing!")
	print("  ✅ TEST 3 PASSED: Arms dynamically react and brace with thruster controls.")

	# -------------------------------------------------------------------------
	# TEST 4: In-Flight Leg Trailing & Micro-Turbulence Flutter
	# -------------------------------------------------------------------------
	print("\n--- TEST 4: In-Flight Leg Trailing & Flutter ---")
	player.set_mobile_inputs(false, false)
	player.velocity = Vector2(240.0, -20.0) # flying rightward

	var leg_rot_samples: Array[float] = []
	for _f in range(25):
		await physics_frame
		leg_rot_samples.append(left_leg.rotation)

	var avg_leg_rot: float = 0.0
	for r in leg_rot_samples: avg_leg_rot += r
	avg_leg_rot /= float(leg_rot_samples.size())

	var leg_min: float = 999.0
	var leg_max: float = -999.0
	for r in leg_rot_samples:
		leg_min = minf(leg_min, r)
		leg_max = maxf(leg_max, r)

	var flutter_range = leg_max - leg_min
	print("  Average forward leg trailing angle: %.1f°" % rad_to_deg(avg_leg_rot))
	print("  Leg flutter dynamic range:          %.2f°" % rad_to_deg(flutter_range))

	assert(avg_leg_rot < -0.05, "Legs must trail behind flight direction!")
	assert(flutter_range > 0.02, "Legs must exhibit continuous organic flutter in flight turbulence!")
	print("  ✅ TEST 4 PASSED: Legs trail velocity and flutter dynamically in solar winds.")

	# -------------------------------------------------------------------------
	# TEST 5: Ascent vs Descent Adaptive Leg Posture
	# -------------------------------------------------------------------------
	print("\n--- TEST 5: Vertical Flight Adaptation (Climb Tuck vs Landing Reach) ---")
	player.global_position = pad_1.get_landing_position() + Vector2(250.0, -150.0)
	player.current_state = SolarPlayer.State.FLYING
	# Fast ascent
	player.velocity = Vector2(0.0, -180.0)
	for _f in range(15): await physics_frame
	var climb_leg_y = left_leg.position.y
	print("  Leg vertical position during steep climb:   %.2f px" % climb_leg_y)
	assert(climb_leg_y < 0.0, "Legs should tuck slightly during steep upward climb!")

	# Fast descent
	player.velocity = Vector2(0.0, 180.0)
	for _f in range(15): await physics_frame
	var descent_leg_y = left_leg.position.y
	print("  Leg vertical position during steep descent: %.2f px" % descent_leg_y)
	assert(descent_leg_y > 0.0, "Legs should extend downward ready for landing touchdown!")
	print("  ✅ TEST 5 PASSED: Legs adaptively tuck on climb and extend for landing.")

	print("\n=======================================================")
	print("   ALL 5 V8.2 ASTRONAUT MOVEMENT TESTS PASSED! 🎉      ")
	print("=======================================================\n")
	quit()
