extends SceneTree

const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")

var current_main: SolarMain = null

func _init() -> void:
	print("\n=======================================================")
	print("   TEST V7.7: HUMAN PLANETARY EXPLORER ASTRONAUT       ")
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
	var camera = game.camera

	game.hud.emit_signal("play_game_requested")
	while game.current_state != SolarMain.GameState.PLAYING:
		await physics_frame
	await physics_frame

	var pad_1 = world_gen.get_platform_by_index(1)
	var pad_2 = world_gen.get_platform_by_index(2)

	# -------------------------------------------------------------------------
	# TEST 1: Human Astronaut Anatomy Hierarchy
	# -------------------------------------------------------------------------
	print("--- TEST 1: Human Astronaut Visual Hierarchy ---")
	var visuals = player.get_node("Visuals")
	assert(visuals != null, "Player must have Visuals node!")
	
	# Head & Visor
	var head = visuals.get_node_or_null("Head")
	assert(head != null, "Astronaut must have Head node!")
	assert(head.has_node("HelmetDome"), "Must have HelmetDome!")
	assert(head.has_node("VisorGlass"), "Must have dark glossy VisorGlass!")
	assert(head.has_node("VisorGleam"), "Must have curved VisorGleam reflection!")
	
	# Torso & Mission Details
	var torso = visuals.get_node_or_null("Torso")
	assert(torso != null, "Astronaut must have Torso!")
	assert(torso.has_node("SuitBody"), "Must have SuitBody!")
	assert(torso.has_node("ChestStripe"), "Must have orange ChestStripe!")
	assert(torso.has_node("UtilityBelt"), "Must have UtilityBelt!")
	
	# Arms & Gloves
	assert(visuals.has_node("LeftArm") and visuals.has_node("RightArm"), "Astronaut must have two arms!")
	assert(visuals.get_node("LeftArm").has_node("LeftGlove"), "Must have left glove!")
	assert(visuals.get_node("RightArm").has_node("RightGlove"), "Must have right glove!")
	
	# Legs & Boots
	assert(visuals.has_node("LeftLeg") and visuals.has_node("RightLeg"), "Astronaut must have two legs!")
	assert(visuals.get_node("LeftLeg").has_node("LeftBoot"), "Must have left boot!")
	assert(visuals.get_node("RightLeg").has_node("RightBoot"), "Must have right boot!")
	
	# Backpack Equipment
	var backpack = visuals.get_node_or_null("Backpack")
	assert(backpack != null, "Astronaut must have life-support Backpack!")
	assert(backpack.has_node("BackpackAntenna"), "Must have comms antenna!")
	assert(backpack.has_node("LeftThrusterNozzle") and backpack.has_node("RightThrusterNozzle"), "Must have backpack side thrusters!")
	print("  ✅ TEST 1 PASSED: Full human astronaut anatomy hierarchy confirmed.")

	# -------------------------------------------------------------------------
	# TEST 2: Standing Footpad Alignment on Pad Deck
	# -------------------------------------------------------------------------
	print("\n--- TEST 2: Platform Footing Alignment ---")
	player.spawn_on_platform(pad_1)
	for _f in range(5): await physics_frame
	
	# Boots bottom vertices are at y = 12, matching the landing deck position
	var left_boot = visuals.get_node("LeftLeg/LeftBoot") as Polygon2D
	var max_boot_y = -999.0
	for pt in left_boot.polygon:
		max_boot_y = maxf(max_boot_y, pt.y)
	assert(absf(max_boot_y - 12.0) < 0.1, "Boots bottom must align cleanly at deck level y=12! (got " + str(max_boot_y) + ")")
	print("  ✅ TEST 2 PASSED: Astronaut boots firmly planted on pad deck (y=" + str(max_boot_y) + ").")

	# -------------------------------------------------------------------------
	# TEST 3: Character Visual Scale (1.3–1.6x Bigger)
	# -------------------------------------------------------------------------
	print("\n--- TEST 3: Visual Scale Verification ---")
	var helmet_poly = visuals.get_node("Head/HelmetDome") as Polygon2D
	var min_head_y = 999.0
	for pt in helmet_poly.polygon:
		min_head_y = minf(min_head_y, pt.y)
	var total_visual_height = max_boot_y - min_head_y
	print("  Total astronaut visual height: " + str(snappedf(total_visual_height, 0.1)) + " px")
	assert(total_visual_height >= 48.0 and total_visual_height <= 62.0, "Astronaut must be noticeably bigger (48..62px tall, was ~32px lander)!")
	print("  ✅ TEST 3 PASSED: Astronaut is substantially bigger (" + str(snappedf(total_visual_height, 0.1)) + "px height).")

	# -------------------------------------------------------------------------
	# TEST 4: Flight Limb Articulation
	# -------------------------------------------------------------------------
	print("\n--- TEST 4: Flight Limb Articulation ---")
	player.current_state = SolarPlayer.State.FLYING
	player.velocity = Vector2(250.0, -100.0) # Flying forward rightward
	for _f in range(15): await physics_frame
	
	# Check that limbs trail with velocity
	var left_leg_node = visuals.get_node("LeftLeg") as Node2D
	print("  Leg articulation angle in forward flight: " + str(snappedf(rad_to_deg(left_leg_node.rotation), 0.1)) + "°")
	assert(absf(left_leg_node.rotation) > 0.02, "Legs must subtly articulate/trail with flight velocity!")
	print("  ✅ TEST 4 PASSED: Dynamic limb trailing active during flight.")

	# -------------------------------------------------------------------------
	# TEST 5: Landing Squash & Stand Upright Recovery
	# -------------------------------------------------------------------------
	print("\n--- TEST 5: Landing Response & Upright Stand ---")
	player.global_position = pad_2.get_landing_position() + Vector2(0.0, -10.0)
	player.current_state = SolarPlayer.State.FLYING
	player.velocity = Vector2(0.0, 80.0)
	player._process_platform_touchdown(pad_2, pad_2.get_landing_position(), 80.0)
	
	# Verify squash compression
	var scale_y_landing = visuals.scale.y
	print("  Touchdown squash scale Y: " + str(snappedf(scale_y_landing, 0.01)))
	assert(scale_y_landing < 1.5, "Touchdown should produce subtle squash compression (< 1.5)!")
	
	# Let it recover over 15 frames
	for _f in range(15): await physics_frame
	print("  Recovered standing scale Y: " + str(snappedf(visuals.scale.y, 0.01)))
	assert(absf(visuals.scale.y - 1.5) < 0.05, "Astronaut must recover to natural upright 1.5 scale!")
	print("  ✅ TEST 5 PASSED: Touchdown squash and upright recovery confirmed.")

	print("\n=======================================================")
	print("   ALL 5 V7.7 HUMAN ASTRONAUT TESTS PASSED! 🎉        ")
	print("=======================================================\n")
	quit()
