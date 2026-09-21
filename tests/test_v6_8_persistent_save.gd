extends SceneTree

const SunZoneData = preload("res://scripts/planet_data.gd")
const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")
const SolarHUD = preload("res://scripts/hud.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")
const SolarCamera = preload("res://scripts/camera_follow.gd")

const SAVE_PATH = "user://explore_sun_save.json"
const LEGACY_SAVE_PATH = "user://explore_sun_best.save"

var current_main: SolarMain = null

func _init() -> void:
	print("\n=======================================================")
	print("   EXPLORE SUN — PERSISTENT CHECKPOINT SAVE TEST SUITE  ")
	print("=======================================================\n")
	call_deferred("_run_all_tests")

func _clean_save_files() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if FileAccess.file_exists(LEGACY_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_SAVE_PATH))

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

func _simulate_landing(scene: SolarMain, pad_idx: int) -> void:
	var pad = scene.world_gen.ensure_checkpoint_exists(pad_idx)
	assert(pad != null, "Pad %d must exist" % pad_idx)
	scene.player.current_state = SolarPlayer.State.FLYING
	scene.player.velocity = Vector2(0.0, 120.0)
	scene.player.test_touchdown(pad, pad.get_landing_position())
	scene._on_player_landed(pad, true)

func _run_all_tests() -> void:
	# =========================================================================
	# TEST 1: New game -> checkpoint 1
	# =========================================================================
	print("--- TEST 1: New Game Initialization ---")
	_clean_save_files()
	var game1 = _spawn_fresh_game_instance()
	await process_frame
	await process_frame
	
	assert(game1.current_checkpoint == 1, "TEST 1 FAILED: New game checkpoint should be 1, got %d" % game1.current_checkpoint)
	assert(game1.current_pad == 1, "TEST 1 FAILED: Current pad should be 1")
	assert(game1.current_state == SolarMain.GameState.PLAYING, "TEST 1 FAILED: Should be in PLAYING state")
	assert(game1.player.target_platform_ref.platform_index == 2, "TEST 1 FAILED: Target should be Pad 2, got %d" % game1.player.target_platform_ref.platform_index)
	print("  ✅ TEST 1 PASSED: New game correctly initialized at Checkpoint PAD 1 targeting PAD 2.")

	# =========================================================================
	# TEST 2: Land Pad 3 -> Save -> Restart Application -> Resumes Pad 3
	# =========================================================================
	print("\n--- TEST 2: Land Pad 3 -> Immediate Save -> Restart Application ---")
	_simulate_landing(game1, 2)
	await process_frame
	_simulate_landing(game1, 3)
	await process_frame
	
	# Verify save was written immediately to disk
	assert(FileAccess.file_exists(SAVE_PATH), "TEST 2 FAILED: Save file was not created on landing!")
	var f2 = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var content2 = f2.get_as_text()
	f2.close()
	var json2 = JSON.parse_string(content2) as Dictionary
	assert(json2.has("checkpoint_pad"), "TEST 2 FAILED: Missing checkpoint_pad in save JSON")
	assert(int(json2["checkpoint_pad"]) == 3, "TEST 2 FAILED: Expected disk checkpoint 3, got %s" % str(json2["checkpoint_pad"]))
	print("  Disk checkpoint verified immediately after landing: PAD %d" % int(json2["checkpoint_pad"]))
	
	# Simulate application restart
	var game2 = _spawn_fresh_game_instance()
	await process_frame
	await process_frame
	
	assert(game2.current_checkpoint == 3, "TEST 2 FAILED: Restarted game checkpoint should be 3, got %d" % game2.current_checkpoint)
	assert(game2.current_pad == 3, "TEST 2 FAILED: Player should be spawned on Pad 3")
	assert(game2.player.target_platform_ref.platform_index == 4, "TEST 2 FAILED: Target should be Pad 4, got %d" % game2.player.target_platform_ref.platform_index)
	print("  ✅ TEST 2 PASSED: Reopened application safely resumed at Checkpoint PAD 3 targeting PAD 4.")

	# =========================================================================
	# TEST 3: Land Pad 10 -> Close Game -> Reopen -> Resumes Pad 10
	# =========================================================================
	print("\n--- TEST 3: Land Pad 10 -> Close -> Reopen ---")
	_simulate_landing(game2, 10)
	await process_frame
	
	# Reopen fresh instance
	var game3 = _spawn_fresh_game_instance()
	await process_frame
	await process_frame
	
	assert(game3.current_checkpoint == 10, "TEST 3 FAILED: Checkpoint should be 10, got %d" % game3.current_checkpoint)
	assert(game3.player.target_platform_ref.platform_index == 11, "TEST 3 FAILED: Target should be Pad 11")
	# Check camera position
	var pad10 = game3.world_gen.get_platform_by_index(10)
	var view_w = game3.get_viewport().get_visible_rect().size.x
	var expected_cam_x = pad10.global_position.x - (view_w * (game3.camera.current_screen_frac_x - 0.5))
	assert(absf(game3.camera.global_position.x - expected_cam_x) < 5.0, "TEST 3 FAILED: Camera composition not restored for Pad 10")
	print("  ✅ TEST 3 PASSED: Close and reopen safely restored PAD 10 with Mars camera composition.")

	# =========================================================================
	# TEST 4: Land Pad 18 -> Force Close -> Reopen -> Resumes Pad 18
	# =========================================================================
	print("\n--- TEST 4: Land Pad 18 -> Force Close Simulation -> Reopen ---")
	_simulate_landing(game3, 18)
	await process_frame
	
	# Simulate sudden abrupt force-close without graceful shutdown (discard game3 without calling exit)
	root.remove_child(game3)
	game3.free()
	current_main = null
	
	# Reopen after force-close
	var game4 = _spawn_fresh_game_instance()
	await process_frame
	await process_frame
	
	assert(game4.current_checkpoint == 18, "TEST 4 FAILED: Checkpoint should be 18 after force close, got %d" % game4.current_checkpoint)
	assert(game4.player.target_platform_ref.platform_index == 19, "TEST 4 FAILED: Next target should be Pad 19")
	print("  ✅ TEST 4 PASSED: Progress survived simulated force-close. Resumed at PAD 18 targeting PAD 19.")

	# =========================================================================
	# TEST 5: Land Pad 25 -> Die -> Rewind -> Checkpoint Remains 25
	# =========================================================================
	print("\n--- TEST 5: Land Pad 25 -> Crash & Rewind -> Checkpoint Remains 25 ---")
	_simulate_landing(game4, 25)
	await process_frame
	assert(game4.current_checkpoint == 25, "Checkpoint should be 25")
	
	# Simulate death on the way to Pad 26
	game4._on_player_crashed("Flight abort test")
	# Wait for slow-mo (0.25s) and rewind tween (~1.0s) to finish and return to PLAYING
	var timer: float = 0.0
	while game4.current_state != SolarMain.GameState.PLAYING and timer < 5.0:
		await process_frame
		timer += 0.016
		
	assert(game4.current_checkpoint == 25, "TEST 5 FAILED: Checkpoint was changed on death!")
	assert(game4.player.target_platform_ref.platform_index == 26, "TEST 5 FAILED: Next target should remain Pad 26")
	assert(game4.current_state == SolarMain.GameState.PLAYING, "TEST 5 FAILED: State should be restored to PLAYING after rewind")
	
	# Verify save on disk is STILL 25
	var f5 = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json5 = JSON.parse_string(f5.get_as_text()) as Dictionary
	f5.close()
	assert(int(json5["checkpoint_pad"]) == 25, "TEST 5 FAILED: Disk save was corrupted or altered during death!")
	print("  ✅ TEST 5 PASSED: Death and rewind preserved Checkpoint 25 in memory and on disk.")

	# =========================================================================
	# TEST 6: Land Pad 30 -> Save -> Restart -> Next Target is Pad 31
	# =========================================================================
	print("\n--- TEST 6: Land Pad 30 -> Save -> Restart -> Next Target Pad 31 ---")
	_simulate_landing(game4, 30)
	await process_frame
	
	var game6 = _spawn_fresh_game_instance()
	await process_frame
	await process_frame
	
	assert(game6.current_checkpoint == 30, "TEST 6 FAILED: Checkpoint should be 30, got %d" % game6.current_checkpoint)
	assert(game6.player.target_platform_ref.platform_index == 31, "TEST 6 FAILED: Target should be Pad 31, got %d" % game6.player.target_platform_ref.platform_index)
	print("  ✅ TEST 6 PASSED: Restart correctly targets PAD 31 from Checkpoint PAD 30.")

	# =========================================================================
	# TEST 7: Corrupted / Missing Save Data -> Safe Fallback to Pad 1
	# =========================================================================
	print("\n--- TEST 7: Corrupted / Out-of-Range Save Fallback ---")
	# 7A: Corrupted non-JSON string
	var f7 = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f7.store_string("THIS IS COMPLETELY INVALID CORRUPTED DATA! {[[[")
	f7.close()
	
	var game7a = _spawn_fresh_game_instance()
	await process_frame
	await process_frame
	assert(game7a.current_checkpoint == 1, "TEST 7A FAILED: Corrupted save did not fall back to Pad 1, got %d" % game7a.current_checkpoint)
	assert(game7a.player.target_platform_ref.platform_index == 2, "TEST 7A FAILED: Target should be Pad 2")
	print("  7A: Malformed JSON safely fell back to Checkpoint PAD 1.")

	# 7B: Out-of-bounds pad values (e.g. pad -99 or pad 999)
	var f7b = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f7b.store_string(JSON.stringify({"checkpoint_pad": 9999, "best_pad": 9999}))
	f7b.close()
	
	var game7b = _spawn_fresh_game_instance()
	await process_frame
	await process_frame
	assert(game7b.current_checkpoint == 1, "TEST 7B FAILED: Out-of-range checkpoint did not reset to Pad 1, got %d" % game7b.current_checkpoint)
	print("  7B: Out-of-range pad (9999) safely clamped to Checkpoint PAD 1.")
	print("  ✅ TEST 7 PASSED: All corrupted/missing scenarios safely recover.")

	# =========================================================================
	# TEST 8 (Bonus): Pad 100 Edge Case (Journey Complete, No Pad 101)
	# =========================================================================
	print("\n--- TEST 8 (Bonus): Pad 100 Journey Complete Edge Case ---")
	var f8 = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f8.store_string(JSON.stringify({"checkpoint_pad": 100, "best_pad": 100, "journey_complete": true}))
	f8.close()
	
	var game8 = _spawn_fresh_game_instance()
	await process_frame
	await process_frame
	
	assert(game8.current_checkpoint == 100, "TEST 8 FAILED: Should load Pad 100")
	assert(game8.player.target_platform_ref == null, "TEST 8 FAILED: Should not have a Pad 101 target")
	assert(game8.camera.target_platform == null, "TEST 8 FAILED: Camera should not have a Pad 101 target")
	print("  ✅ TEST 8 PASSED: Pad 100 safely handles journey complete without spawning Pad 101.")

	# Cleanup
	_clean_save_files()
	
	print("\n=======================================================")
	print("   ALL 8 PERSISTENT CHECKPOINT SAVE TESTS PASSED! 🎉   ")
	print("=======================================================\n")
	quit(0)
