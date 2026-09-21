extends SceneTree

const SunZoneData = preload("res://scripts/planet_data.gd")
const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")
const SolarHUD = preload("res://scripts/hud.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")
const SolarCamera = preload("res://scripts/camera_follow.gd")

const SAVE_PATH = "user://explore_sun_save.json"

var current_main: SolarMain = null

func _init() -> void:
	print("\n=======================================================")
	print("   TEST V6.9: JOURNEY COMPLETION & PAD 100 BOUNDS TEST ")
	print("=======================================================\n")
	call_deferred("_run_all_tests")

func _clean_save_files() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

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

func _is_completion_ui_visible(scene: SolarMain) -> bool:
	var arrival_card = scene.hud.planet_arrival_card
	var arrival_title = scene.hud.arrival_title
	if arrival_card and arrival_card.visible and arrival_card.modulate.a > 0.0:
		if arrival_title and arrival_title.text == "SUN JOURNEY COMPLETE":
			return true
	return false

func _run_all_tests() -> void:
	_clean_save_files()
	var game = _spawn_fresh_game_instance()
	await process_frame
	await process_frame

	# -------------------------------------------------------------------------
	# TEST 1: Land Pad 1 -> no completion UI
	# -------------------------------------------------------------------------
	print("--- TEST 1: Land Pad 1 -> No Completion UI ---")
	_simulate_landing(game, 1)
	await process_frame
	assert(not _is_completion_ui_visible(game), "TEST 1 FAILED: Completion UI appeared on Pad 1!")
	assert(game.current_pad == 1, "Pad must be 1")
	print("  ✅ TEST 1 PASSED: Pad 1 has no completion UI.")

	# -------------------------------------------------------------------------
	# TEST 2: Land Pad 10 -> no completion UI
	# -------------------------------------------------------------------------
	print("\n--- TEST 2: Land Pad 10 -> No Completion UI ---")
	_simulate_landing(game, 10)
	await process_frame
	assert(not _is_completion_ui_visible(game), "TEST 2 FAILED: Completion UI appeared on Pad 10!")
	assert(game.current_pad == 10, "Pad must be 10")
	print("  ✅ TEST 2 PASSED: Pad 10 has no completion UI.")

	# -------------------------------------------------------------------------
	# TEST 3: Land Pad 50 -> no completion UI
	# -------------------------------------------------------------------------
	print("\n--- TEST 3: Land Pad 50 -> No Completion UI ---")
	_simulate_landing(game, 50)
	await process_frame
	assert(not _is_completion_ui_visible(game), "TEST 3 FAILED: Completion UI appeared on Pad 50!")
	assert(game.current_pad == 50, "Pad must be 50")
	print("  ✅ TEST 3 PASSED: Pad 50 has no completion UI.")

	# -------------------------------------------------------------------------
	# TEST 4: Land Pad 99 -> no completion UI
	# -------------------------------------------------------------------------
	print("\n--- TEST 4: Land Pad 99 -> No Completion UI ---")
	_simulate_landing(game, 99)
	await process_frame
	assert(not _is_completion_ui_visible(game), "TEST 4 FAILED: Completion UI appeared on Pad 99!")
	assert(game.current_pad == 99, "Pad must be 99")
	assert(game.player.target_platform_ref.platform_index == 100, "Target from 99 must be Pad 100")
	print("  ✅ TEST 4 PASSED: Pad 99 has no completion UI and targets Pad 100.")

	# -------------------------------------------------------------------------
	# TEST 5: Land Pad 100 -> completion UI appears exactly once
	# -------------------------------------------------------------------------
	print("\n--- TEST 5: Land Pad 100 -> Completion UI Appears ---")
	_simulate_landing(game, 100)
	await process_frame
	assert(_is_completion_ui_visible(game), "TEST 5 FAILED: Completion UI did not appear on Pad 100!")
	assert(game.has_shown_journey_complete == true, "has_shown_journey_complete flag must be set!")
	print("  ✅ TEST 5 PASSED: Completion UI appeared on Pad 100.")

	# -------------------------------------------------------------------------
	# TEST 6: Verify current_pad never becomes 101+
	# -------------------------------------------------------------------------
	print("\n--- TEST 6: Verify current_pad Never Becomes 101+ ---")
	assert(game.current_pad == 100, "TEST 6 FAILED: current_pad should be 100, got %d" % game.current_pad)
	assert(game.current_checkpoint == 100, "TEST 6 FAILED: current_checkpoint should be 100, got %d" % game.current_checkpoint)
	print("  ✅ TEST 6 PASSED: current_pad is strictly clamped to 100.")

	# -------------------------------------------------------------------------
	# TEST 7: Verify best_pad never becomes 101+
	# -------------------------------------------------------------------------
	print("\n--- TEST 7: Verify best_pad Never Becomes 101+ ---")
	assert(game.best_pad <= 100, "TEST 7 FAILED: best_pad should be <= 100, got %d" % game.best_pad)
	print("  ✅ TEST 7 PASSED: best_pad is strictly clamped to %d <= 100." % game.best_pad)

	# -------------------------------------------------------------------------
	# TEST 8: Verify no Pad 101 is generated
	# -------------------------------------------------------------------------
	print("\n--- TEST 8: Verify No Pad 101 is Generated ---")
	var pad_101 = game.world_gen.get_platform_by_index(101)
	assert(pad_101 == null, "TEST 8 FAILED: Pad 101 was generated!")
	var pad_101_attempt = game.world_gen.ensure_checkpoint_exists(101)
	assert(pad_101_attempt == null, "TEST 8 FAILED: ensure_checkpoint_exists(101) returned non-null!")
	assert(game.player.target_platform_ref == null, "TEST 8 FAILED: Player should have no target after Pad 100")
	assert(game.camera.target_platform == null, "TEST 8 FAILED: Camera should have no target after Pad 100")
	print("  ✅ TEST 8 PASSED: No Pad 101 exists or can be spawned. Next target is null.")

	# -------------------------------------------------------------------------
	# TEST 9: Verify save file stores checkpoint_pad = 100 after Pad 100
	# -------------------------------------------------------------------------
	print("\n--- TEST 9: Verify Save File Stores checkpoint_pad = 100 ---")
	assert(FileAccess.file_exists(SAVE_PATH), "TEST 9 FAILED: Save file does not exist")
	var f9 = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json9 = JSON.parse_string(f9.get_as_text()) as Dictionary
	f9.close()
	assert(int(json9["checkpoint_pad"]) == 100, "TEST 9 FAILED: checkpoint_pad in file is not 100, got %s" % str(json9.get("checkpoint_pad")))
	assert(int(json9["next_target_pad"]) == 0, "TEST 9 FAILED: next_target_pad in file should be 0, got %s" % str(json9.get("next_target_pad")))
	assert(bool(json9["journey_complete"]) == true, "TEST 9 FAILED: journey_complete in file should be true")
	print("  ✅ TEST 9 PASSED: Save file correctly persists checkpoint_pad=100, target=0, complete=true.")

	# -------------------------------------------------------------------------
	# TEST 10: Restart after completion -> resume Pad 100 in completed state, not Pad 101
	# -------------------------------------------------------------------------
	print("\n--- TEST 10: Restart After Completion -> Resume Pad 100 In Completed State ---")
	var game_restarted = _spawn_fresh_game_instance()
	await process_frame
	await process_frame

	assert(game_restarted.current_checkpoint == 100, "TEST 10 FAILED: Checkpoint should be 100, got %d" % game_restarted.current_checkpoint)
	assert(game_restarted.current_pad == 100, "TEST 10 FAILED: current_pad should be 100, got %d" % game_restarted.current_pad)
	assert(game_restarted.player.target_platform_ref == null, "TEST 10 FAILED: Player must not target Pad 101 upon reopening")
	assert(game_restarted.world_gen.get_platform_by_index(101) == null, "TEST 10 FAILED: Pad 101 must not exist on reopen")
	print("  ✅ TEST 10 PASSED: Reopened game resumed safely on Pad 100 with zero Pad 101 targets.")

	_clean_save_files()
	print("\n=======================================================")
	print("   ALL 10 JOURNEY COMPLETION & BOUNDS TESTS PASSED! 🎉  ")
	print("=======================================================\n")
	quit(0)
