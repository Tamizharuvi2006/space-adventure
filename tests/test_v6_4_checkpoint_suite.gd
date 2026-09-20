extends SceneTree

const SunZoneData = preload("res://scripts/planet_data.gd")
const SolarBackground = preload("res://scripts/background.gd")
const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")
const SolarHUD = preload("res://scripts/hud.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")
const SolarCamera = preload("res://scripts/camera_follow.gd")

var main_scene: SolarMain = null
var player: SolarPlayer = null
var hud: SolarHUD = null
var world_gen: WorldGenerator = null
var camera: SolarCamera = null
var background: SolarBackground = null

func _init() -> void:
	print("=== RUNNING V6.4 PAD 1 -> 100 CHECKPOINT PROGRESSION SUITE ===")
	call_deferred("_setup_and_run")

func _setup_and_run() -> void:
	var packed = load("res://scenes/main.tscn") as PackedScene
	main_scene = packed.instantiate()
	root.add_child(main_scene)
	
	player = main_scene.get_node("Player") as SolarPlayer
	hud = main_scene.get_node("HUD") as SolarHUD
	world_gen = main_scene.get_node("WorldGenerator") as WorldGenerator
	camera = main_scene.get_node("Camera2D") as SolarCamera
	background = main_scene.get_node("Background") as SolarBackground
	
	await process_frame
	await process_frame
	
	# Start game
	hud.emit_signal("play_game_requested")
	while main_scene.current_state != main_scene.GameState.PLAYING:
		await process_frame
	await process_frame
	
	_run_all_checkpoints_test()

func _capture_screenshot(file_name: String) -> void:
	await process_frame
	await process_frame
	var image = root.get_viewport().get_texture().get_image()
	var artifact_dir = "C:/Users/aruvi/.gemini/antigravity-ide/brain/f75eeb4b-bf34-4366-b518-afc1bd64e4d0"
	var path = artifact_dir + "/" + file_name
	image.save_png(path)
	print("  [SCREENSHOT] Saved: %s" % path)

func _run_all_checkpoints_test() -> void:
	print("\n--- PHASE 1: VERIFY INITIAL PAD 0 LAUNCH ---")
	assert(main_scene.current_pad == 0, "Initial pad must be 0")
	assert(main_scene.current_zone_idx == 0, "Initial zone must be Solar Valley")
	
	var initial_cam_y = camera.global_position.y
	print("  Initial Camera Y: %.2f" % initial_cam_y)
	
	# We will progress pad by pad from Pad 1 up to Pad 100
	var zone_transition_counts = 0
	var last_zone = 0
	
	print("\n--- PHASE 2: PROGRESSION ACROSS ALL 100 CHECKPOINTS ---")
	for target_pad_idx in range(1, 101):
		# 1. Ensure platform target_pad_idx exists
		while world_gen.next_platform_idx <= target_pad_idx + 2:
			world_gen.spawn_next_route_pad()
			
		var pad_node = world_gen.get_platform_by_index(target_pad_idx)
		assert(pad_node != null, "Pad %d must exist in active route!" % target_pad_idx)
		
		# 2. Simulate approach & flight
		player.current_state = SolarPlayer.State.FLYING
		player.velocity = Vector2(0.0, 100.0)
		player.fuel = 45.0 # Partially depleted fuel to test refill
		
		# 3. Touchdown on pad_node
		var is_perfect = (target_pad_idx % 3 == 0)
		player.test_touchdown(pad_node, pad_node.get_landing_position())
		main_scene._on_player_landed(pad_node, is_perfect)
		
		# Process a frame for physics & HUD
		await process_frame
		
		# 4. Verify Checkpoint Behaviors for every single pad
		assert(main_scene.current_pad == target_pad_idx, "Current pad must be %d, got %d" % [target_pad_idx, main_scene.current_pad])
		assert(player.current_state == SolarPlayer.State.ON_PAD, "Player state must be ON_PAD")
		assert(player.fuel == player.max_fuel, "Fuel must be 100%% refilled on landing at Pad %d" % target_pad_idx)
		assert(player.active_platform == pad_node, "Player active platform must be Pad %d" % target_pad_idx)
		
		# Verify HUD altitude label
		var expected_progress = "%d / %d" % [target_pad_idx, SunZoneData.TOTAL_PADS]
		assert(hud.altitude_label.text == expected_progress, "HUD progress must be '%s', got '%s'" % [expected_progress, hud.altitude_label.text])
		
		# Verify Next Target platform
		if target_pad_idx < 100:
			var expected_next = world_gen.get_platform_by_index(target_pad_idx + 1)
			assert(expected_next != null, "Next pad %d must be available" % (target_pad_idx + 1))
			assert(camera.target_platform == expected_next, "Camera next target must be Pad %d" % (target_pad_idx + 1))
			assert(player.target_platform_ref == expected_next, "Player next target must be Pad %d" % (target_pad_idx + 1))
		
		# Verify Zone Transition logic
		var expected_zone_idx = SunZoneData.get_zone_index(target_pad_idx)
		assert(main_scene.current_zone_idx == expected_zone_idx, "Zone idx must match %d at Pad %d" % [expected_zone_idx, target_pad_idx])
		
		if expected_zone_idx != last_zone:
			zone_transition_counts += 1
			print("  [MILESTONE] Zone Transition %d -> %d at Pad %d (%s)" % [
				last_zone, expected_zone_idx, target_pad_idx, SunZoneData.get_zone_by_index(expected_zone_idx)["name"]
			])
			last_zone = expected_zone_idx
			
			# Take milestone screenshots
			if target_pad_idx == 21:
				await _capture_screenshot("v6_4_zone1_pad21_craters.png")
			elif target_pad_idx == 41:
				await _capture_screenshot("v6_4_zone2_pad41_mountains.png")
			elif target_pad_idx == 61:
				await _capture_screenshot("v6_4_zone3_pad61_ruins.png")
			elif target_pad_idx == 81:
				await _capture_screenshot("v6_4_zone4_pad81_core.png")
		
		# Log progress periodically
		if target_pad_idx % 20 == 0 or target_pad_idx == 1:
			print("  ✓ Pad %d / 100 verified: fuel=100%%, next target=Pad %d, cam_y=%.1f, HUD='%s'" % [
				target_pad_idx, target_pad_idx + 1, camera.global_position.y, hud.altitude_label.text
			])
	
	# 5. Immediate Relaunch Verification from Pad 100
	print("\n--- PHASE 3: IMMEDIATE RELAUNCH VERIFICATION ---")
	player.set_mobile_inputs(false, true)
	await physics_frame
	await physics_frame
	assert(player.current_state == SolarPlayer.State.FLYING, "Player must immediately relaunch on thrust without any wait or lock!")
	player.set_mobile_inputs(false, false)
	print("  ✓ Immediate relaunch without lock verified!")

	# 6. Final Pad 100 Journey Completion Verification
	print("\n--- PHASE 4: PAD 100 SUN JOURNEY COMPLETION ---")
	assert(main_scene.current_pad == 100, "Must have reached final Pad 100")
	assert(SunZoneData.is_journey_complete(100), "Journey must be marked complete at Pad 100")
	assert(zone_transition_counts == 4, "Must have completed exactly 4 zone transitions across 100 pads (Pads 21, 41, 61, 81)")
	await _capture_screenshot("v6_4_pad100_journey_complete.png")
	
	print("\n=======================================================")
	print("🎉 ALL 100 CHECKPOINTS & ZONE TRANSITIONS PASSED 100%!")
	print("=======================================================")
	quit(0)
