extends SceneTree

const SunZoneData = preload("res://scripts/planet_data.gd")
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

func _init() -> void:
	print("=== RUNNING V6.6 SEAMLESS CHECKPOINT REWIND SUITE ===")
	call_deferred("_setup_and_run")

func _setup_and_run() -> void:
	var packed = load("res://scenes/main.tscn") as PackedScene
	main_scene = packed.instantiate()
	root.add_child(main_scene)
	
	player = main_scene.get_node("Player") as SolarPlayer
	hud = main_scene.get_node("HUD") as SolarHUD
	world_gen = main_scene.get_node("WorldGenerator") as WorldGenerator
	camera = main_scene.get_node("Camera2D") as SolarCamera
	
	await process_frame
	await process_frame
	
	# Start game
	hud.emit_signal("play_game_requested")
	while main_scene.current_state != main_scene.GameState.PLAYING:
		await process_frame
	await process_frame
	
	_run_seamless_rewind_tests()

func _capture_screenshot(file_name: String) -> void:
	await process_frame
	await process_frame
	var image = root.get_viewport().get_texture().get_image()
	var artifact_dir = "C:/Users/aruvi/.gemini/antigravity-ide/brain/f75eeb4b-bf34-4366-b518-afc1bd64e4d0"
	var path = artifact_dir + "/" + file_name
	image.save_png(path)
	print("  [SCREENSHOT] Saved: %s" % path)

func _land_on_pad(pad_idx: int) -> void:
	var pad = world_gen.ensure_checkpoint_exists(pad_idx)
	assert(pad != null, "Pad %d must exist" % pad_idx)
	player.current_state = SolarPlayer.State.FLYING
	player.velocity = Vector2(0.0, 100.0)
	player.test_touchdown(pad, pad.get_landing_position())
	main_scene._on_player_landed(pad, true)
	
	var view_w = 1280.0
	camera.global_position.x = pad.global_position.x - (view_w * (camera.current_screen_frac_x - 0.5))
	camera.global_position.y = pad.global_position.y + camera.default_vertical_offset
	
	await process_frame
	await process_frame

func _test_pad_rewind(pad_idx: int) -> void:
	print("\n--- TESTING PAD %d SEAMLESS REWIND ---" % pad_idx)
	
	# 1. Land on pad_idx
	await _land_on_pad(pad_idx)
	assert(main_scene.current_checkpoint == pad_idx, "Checkpoint must be %d" % pad_idx)
	assert(main_scene.current_pad == pad_idx, "Current pad must be %d" % pad_idx)
	var expected_next = pad_idx + 1
	assert(camera.target_platform.platform_index == expected_next, "Target must be Pad %d" % expected_next)
	
	# 2. Player launches toward next pad
	player.current_state = SolarPlayer.State.FLYING
	player.global_position.x += 350.0 # Flown forward into the jump
	player.global_position.y -= 120.0
	camera.global_position.x += 350.0
	
	var crash_cam_x = camera.global_position.x
	print("  Airborne toward Pad %d: Player X=%.1f, Cam X=%.1f" % [expected_next, player.global_position.x, crash_cam_x])
	
	# 3. Death occurs mid-flight
	main_scene._on_player_crashed("Missed approach to Pad %d" % expected_next)
	assert(main_scene.current_state == main_scene.GameState.REWINDING, "State must transition to REWINDING")
	assert(hud.game_over_menu.visible == false, "GAME OVER menu must NOT be visible!")
	assert(player.is_control_enabled == false, "Player controls must be disabled during rewind")
	
	# Capture explosion blast screenshot right in the middle of slow-motion burst (at ~0.10s)
	if pad_idx == 3:
		await create_timer(0.10, true, false, true).timeout
		await _capture_screenshot("v6_7_death_blast_slowmo_impact.png")
		await create_timer(0.45, true, false, true).timeout
	else:
		# Wait for slow-mo death burst (0.25s) and catch midway reverse travel (~0.55s real time)
		await create_timer(0.55, true, false, true).timeout
		
	if main_scene.current_state == main_scene.GameState.REWINDING:
		var midway_cam_x = camera.global_position.x
		var midway_player_x = player.global_position.x
		print("  [CONTINUOUS TRAVEL] Midway Cam X=%.1f (traveling back from death %.1f), Player X=%.1f" % [midway_cam_x, crash_cam_x, midway_player_x])
		assert(midway_cam_x < crash_cam_x, "Camera must travel backward continuously without snapping!")
		assert(player.is_control_enabled == false, "Controls must remain disabled during rewind!")
		if pad_idx == 3:
			await _capture_screenshot("v6_7_rewind_midway_travel.png")

	# 4. Wait for smooth rewind completion
	while main_scene.current_state == main_scene.GameState.REWINDING:
		await process_frame
		
	# 5. Verify restored state at checkpoint
	assert(main_scene.current_state == main_scene.GameState.PLAYING, "State must return to PLAYING after rewind")
	assert(main_scene.current_pad == pad_idx, "Current pad must be restored to %d" % pad_idx)
	assert(main_scene.current_checkpoint == pad_idx, "Checkpoint must remain %d" % pad_idx)
	assert(player.current_state == SolarPlayer.State.ON_PAD, "Player state must be ON_PAD on checkpoint")
	assert(player.fuel == player.max_fuel, "Fuel must be 100%% refilled")
	assert(player.is_control_enabled == true, "Player controls must be re-enabled immediately")
	assert(camera.target_platform.platform_index == expected_next, "Target platform must remain Pad %d" % expected_next)
	assert(hud.game_over_menu.visible == false, "GAME OVER screen must NEVER appear")
	
	# Camera must have moved backward toward the checkpoint pad
	assert(camera.global_position.x < crash_cam_x, "Camera must have smoothly rewound backward (now %.1f < crash %.1f)" % [camera.global_position.x, crash_cam_x])
	
	# 6. Test immediate playability: tap thrust and verify immediate takeoff
	player.set_mobile_inputs(false, true)
	await physics_frame
	await physics_frame
	assert(player.current_state == SolarPlayer.State.FLYING, "Player must be playable immediately after rewind without any menu or delay!")
	player.set_mobile_inputs(false, false)
	
	print("  ✅ PAD %d REWIND PASSED: Smoothly returned to Pad %d, target Pad %d, controls active immediately!" % [
		pad_idx, pad_idx, expected_next
	])

func _run_seamless_rewind_tests() -> void:
	# Test Pad 1 -> die -> rewind -> Pad 1
	await _test_pad_rewind(1)
	await _capture_screenshot("v6_6_rewind_pad1.png")
	
	# Test Pad 3 -> die -> rewind -> Pad 3
	await _test_pad_rewind(3)
	await _capture_screenshot("v6_6_rewind_pad3.png")
	
	# Test Pad 18 -> die -> rewind -> Pad 18
	await _test_pad_rewind(18)
	await _capture_screenshot("v6_6_rewind_pad18.png")
	
	# Test Pad 50 -> die -> rewind -> Pad 50
	await _test_pad_rewind(50)
	await _capture_screenshot("v6_6_rewind_pad50.png")
	
	# Test Pad 99 -> die -> rewind -> Pad 99
	await _test_pad_rewind(99)
	await _capture_screenshot("v6_6_rewind_pad99.png")
	
	print("\n=======================================================")
	print("🎉 ALL SEAMLESS CHECKPOINT REWIND TESTS PASSED 100%!")
	print("=======================================================")
	quit(0)
