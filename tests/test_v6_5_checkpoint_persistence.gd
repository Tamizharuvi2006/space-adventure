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
	print("=== RUNNING V6.5 CHECKPOINT PERSISTENCE TEST SUITE ===")
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
	
	_run_checkpoint_persistence_tests()

func _simulate_landing(pad_idx: int) -> void:
	var pad = world_gen.ensure_checkpoint_exists(pad_idx)
	assert(pad != null, "Pad %d must exist" % pad_idx)
	player.current_state = SolarPlayer.State.FLYING
	player.velocity = Vector2(0.0, 120.0)
	player.test_touchdown(pad, pad.get_landing_position())
	main_scene._on_player_landed(pad, true)
	await process_frame

func _simulate_death(reason: String = "Test Crash") -> void:
	main_scene._on_player_crashed(reason)
	await process_frame

func _simulate_retry() -> void:
	hud.emit_signal("retry_game_requested")
	while main_scene.current_state != main_scene.GameState.PLAYING:
		await process_frame
	await process_frame

func _run_checkpoint_persistence_tests() -> void:
	# =========================================================================
	# TEST 1: Land Pad 1 -> Die -> Retry = Pad 1 (Target Pad 2)
	# =========================================================================
	print("\n--- TEST 1: Land Pad 1 -> Die -> Retry ---")
	await _simulate_landing(1)
	assert(main_scene.current_checkpoint == 1, "Checkpoint must be 1 after landing on Pad 1")
	assert(main_scene.current_pad == 1, "Current pad must be 1")
	
	await _simulate_death("Crashed after Pad 1")
	assert(main_scene.current_state == main_scene.GameState.GAME_OVER, "State must be GAME_OVER")
	assert(main_scene.current_checkpoint == 1, "Checkpoint 1 must be preserved on death!")
	
	await _simulate_retry()
	assert(main_scene.current_pad == 1, "Retry must spawn at Pad 1, got %d" % main_scene.current_pad)
	assert(main_scene.current_checkpoint == 1, "Checkpoint must remain 1 after retry")
	assert(camera.target_platform.platform_index == 2, "Next target after retry from Pad 1 must be Pad 2, got %d" % camera.target_platform.platform_index)
	assert(player.target_platform_ref.platform_index == 2, "Player target after retry must be Pad 2")
	print("  ✅ TEST 1 PASSED: Respawned at Pad 1, targeting Pad 2")

	# =========================================================================
	# TEST 2: Land Pad 2 -> Die -> Retry = Pad 2 (Target Pad 3)
	# =========================================================================
	print("\n--- TEST 2: Land Pad 2 -> Die -> Retry ---")
	await _simulate_landing(2)
	assert(main_scene.current_checkpoint == 2, "Checkpoint must be 2 after landing on Pad 2")
	
	await _simulate_death("Crashed after Pad 2")
	assert(main_scene.current_checkpoint == 2, "Checkpoint 2 must be preserved on death!")
	
	await _simulate_retry()
	assert(main_scene.current_pad == 2, "Retry must spawn at Pad 2, got %d" % main_scene.current_pad)
	assert(camera.target_platform.platform_index == 3, "Next target after retry from Pad 2 must be Pad 3, got %d" % camera.target_platform.platform_index)
	print("  ✅ TEST 2 PASSED: Respawned at Pad 2, targeting Pad 3")

	# =========================================================================
	# TEST 3: Land Pad 3 -> Die -> Retry = Pad 3 (Target Pad 4)
	# =========================================================================
	print("\n--- TEST 3: Land Pad 3 -> Die -> Retry ---")
	await _simulate_landing(3)
	assert(main_scene.current_checkpoint == 3, "Checkpoint must be 3 after landing on Pad 3")
	
	await _simulate_death("Crashed after Pad 3")
	assert(main_scene.current_checkpoint == 3, "Checkpoint 3 must be preserved on death!")
	
	await _simulate_retry()
	assert(main_scene.current_pad == 3, "Retry must spawn at Pad 3, got %d" % main_scene.current_pad)
	assert(camera.target_platform.platform_index == 4, "Next target after retry from Pad 3 must be Pad 4, got %d" % camera.target_platform.platform_index)
	print("  ✅ TEST 3 PASSED: Respawned at Pad 3, targeting Pad 4")

	# =========================================================================
	# TEST 4: Attempt Pad 4 but miss / die -> Retry = Still Pad 3 (Target Pad 4)
	# =========================================================================
	print("\n--- TEST 4: Attempt Pad 4 but miss -> Die -> Retry ---")
	# Player is flying toward Pad 4, but misses and crashes without landing
	player.current_state = SolarPlayer.State.FLYING
	await _simulate_death("Fell into void approaching Pad 4")
	assert(main_scene.current_checkpoint == 3, "Checkpoint must remain 3 because Pad 4 was never landed!")
	
	await _simulate_retry()
	assert(main_scene.current_pad == 3, "Retry must return to Pad 3, got %d" % main_scene.current_pad)
	assert(main_scene.current_checkpoint == 3, "Checkpoint must still be 3")
	assert(camera.target_platform.platform_index == 4, "Next target must still be Pad 4, got %d" % camera.target_platform.platform_index)
	print("  ✅ TEST 4 PASSED: Failed attempt preserved Checkpoint 3 and returned to Pad 3 targeting Pad 4")

	# =========================================================================
	# TEST 5: Land Pad 4 -> Die -> Retry = Pad 4 (Target Pad 5)
	# =========================================================================
	print("\n--- TEST 5: Land Pad 4 -> Die -> Retry ---")
	await _simulate_landing(4)
	assert(main_scene.current_checkpoint == 4, "Checkpoint must be 4 after landing on Pad 4")
	
	await _simulate_death("Crashed after Pad 4")
	assert(main_scene.current_checkpoint == 4, "Checkpoint 4 must be preserved on death!")
	
	await _simulate_retry()
	assert(main_scene.current_pad == 4, "Retry must spawn at Pad 4, got %d" % main_scene.current_pad)
	assert(camera.target_platform.platform_index == 5, "Next target after retry from Pad 4 must be Pad 5, got %d" % camera.target_platform.platform_index)
	print("  ✅ TEST 5 PASSED: Respawned at Pad 4, targeting Pad 5")

	# =========================================================================
	# TEST 6: HOME returns to Pad 0 / fresh run
	# =========================================================================
	print("\n--- TEST 6: Home/New Game resets checkpoint ---")
	main_scene.go_to_main_menu()
	await process_frame
	assert(main_scene.current_checkpoint == 0, "Home must reset checkpoint to 0")
	assert(main_scene.current_pad == 0, "Home must reset current pad to 0")
	print("  ✅ TEST 6 PASSED: Home cleanly resets checkpoint for new run")

	print("\n=======================================================")
	print("🎉 ALL CHECKPOINT PERSISTENCE TESTS PASSED 100%!")
	print("=======================================================")
	quit(0)
