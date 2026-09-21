extends SceneTree

const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")
const SunZoneData = preload("res://scripts/planet_data.gd")

const SAVE_PATH = "user://explore_sun_save.json"

func _init() -> void:
	print("===============================================================")
	print("=== STARTING LONG-RUN CONTINUOUS TEST: PAD 0 TO PAD 100 ===")
	print("===============================================================\n")
	call_deferred("_run_long_run_suite")

func _clean_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func _run_long_run_suite() -> void:
	_clean_save()

	var packed = load("res://scenes/main.tscn") as PackedScene
	var main_node = packed.instantiate() as SolarMain
	root.add_child(main_node)

	for _i in range(5):
		await process_frame

	var hud = main_node.hud
	var player = main_node.player
	var camera = main_node.camera
	var world_gen = main_node.world_gen

	# Start game
	hud.emit_signal("play_game_requested")
	while main_node.current_state != SolarMain.GameState.PLAYING:
		await physics_frame
	for _f in range(10): await physics_frame

	print("[TEST] Game started into PLAYING state.")

	var initial_mem = OS.get_static_memory_usage()
	print("[MEM] Initial static memory usage: %.2f MB" % (initial_mem / (1024.0 * 1024.0)))

	var inspected_pads: int = 0
	var edge_checks_passed: int = 0
	var memory_checkpoints: Dictionary = {}

	# We will step through Pad 0 to Pad 100
	for pad_idx in range(0, 101):
		# Ensure pad exists
		var current_pad = world_gen.ensure_checkpoint_exists(pad_idx)
		assert(current_pad != null, "FATAL: Pad %d failed to spawn!" % pad_idx)
		assert(is_instance_valid(current_pad), "FATAL: Pad %d is not an instance!" % pad_idx)

		# Check next pad reachability if pad_idx < 100
		if pad_idx < 100:
			var next_pad = world_gen.ensure_checkpoint_exists(pad_idx + 1)
			assert(next_pad != null, "FATAL: Next target Pad %d failed to spawn!" % (pad_idx + 1))
			
			var dx = next_pad.global_position.x - current_pad.global_position.x
			var dy = next_pad.global_position.y - current_pad.global_position.y
			
			assert(dx > 100.0, "Pad %d to %d spacing X too small: %.1f" % [pad_idx, pad_idx + 1, dx])
			assert(dx < 1600.0, "Pad %d to %d spacing X too large (unreachable): %.1f" % [pad_idx, pad_idx + 1, dx])
			assert(absf(dy) < 650.0, "Pad %d to %d altitude gap too steep: %.1f" % [pad_idx, pad_idx + 1, dy])

		# Simulate player arrival on pad_idx
		player.spawn_on_platform(current_pad)
		if pad_idx < 100:
			var target_pad = world_gen.ensure_checkpoint_exists(pad_idx + 1)
			camera.set_next_target_platform(target_pad)
		camera.snap_to_target()

		# Run 5 physics frames for camera, background parallax and HUD update
		for _f in range(5):
			await physics_frame

		# Verify camera position is not NaN or Inf
		assert(not is_nan(camera.global_position.x) and not is_inf(camera.global_position.x), "Camera X invalid at Pad %d" % pad_idx)
		assert(not is_nan(camera.global_position.y) and not is_inf(camera.global_position.y), "Camera Y invalid at Pad %d" % pad_idx)

		# Background edge checks at milestones and zone transitions
		if pad_idx % 10 == 0 or pad_idx == 100:
			var img = root.get_viewport().get_texture().get_image()
			if img != null:
				var w = img.get_width()
				var h = img.get_height()
				# Sample 10 points along the right edge and 10 points along the left edge
				for step in range(10):
					var sample_y = int((step / 9.0) * (h - 1))
					var left_c = img.get_pixel(0, sample_y)
					var right_c = img.get_pixel(w - 1, sample_y)
					assert(not _is_gray(left_c), "Left edge gray at Pad %d (y=%d): %s" % [pad_idx, sample_y, left_c])
					assert(not _is_gray(right_c), "Right edge gray at Pad %d (y=%d): %s" % [pad_idx, sample_y, right_c])
				edge_checks_passed += 1

			var cur_mem = OS.get_static_memory_usage()
			var mem_mb = cur_mem / (1024.0 * 1024.0)
			memory_checkpoints[pad_idx] = mem_mb
			print("  [PAD %3d/100] Position=(%.0f, %.0f) | Zone=%s | Static Mem=%.2f MB" % [
				pad_idx,
				current_pad.global_position.x,
				current_pad.global_position.y,
				SunZoneData.get_zone_for_pad(pad_idx)["name"],
				mem_mb
			])

		# Checkpoint & Rewind test at Pad 25
		if pad_idx == 25:
			print("\n  >>> Testing Checkpoint & Rewind at Pad 25...")
			main_node._on_player_landed(current_pad, true)
			for _f in range(5): await physics_frame
			assert(main_node.current_checkpoint == 25, "Checkpoint should be 25")

			# Simulate a crash
			print("      Simulating hazard crash...")
			main_node._on_player_crashed("Hazard collision test")
			while main_node.current_state == SolarMain.GameState.REWINDING:
				await process_frame
			for _f in range(15): await physics_frame

			# Verify player is restored at pad 25
			var landed_pad = player.active_platform
			assert(landed_pad != null and landed_pad.platform_index == 25, "Rewind failed to restore player at Pad 25!")
			assert(player.current_state == SolarPlayer.State.ON_PAD, "Player must be ON_PAD after rewind!")
			assert(player.fuel > 90.0, "Fuel must be replenished after rewind!")
			print("  >>> Checkpoint & Rewind test at Pad 25 PASSED! Continuous journey resuming...\n")

		# Checkpoint & Rewind test at Pad 75
		if pad_idx == 75:
			print("\n  >>> Testing Checkpoint & Rewind at Pad 75...")
			main_node._on_player_landed(current_pad, true)
			for _f in range(5): await physics_frame
			assert(main_node.current_checkpoint == 75, "Checkpoint should be 75")

			# Simulate a crash
			print("      Simulating hazard crash...")
			main_node._on_player_crashed("Hazard collision test")
			while main_node.current_state == SolarMain.GameState.REWINDING:
				await process_frame
			for _f in range(15): await physics_frame

			var landed_pad = player.active_platform
			assert(landed_pad != null and landed_pad.platform_index == 75, "Rewind failed to restore player at Pad 75!")
			assert(player.current_state == SolarPlayer.State.ON_PAD, "Player must be ON_PAD after rewind!")
			print("  >>> Checkpoint & Rewind test at Pad 75 PASSED! Continuous journey resuming...\n")

		inspected_pads += 1

	# Test Final Completion at Pad 100
	print("\n>>> Testing Final Arrival on Pad 100...")
	var pad_100 = world_gen.get_platform_by_index(100)
	main_node._on_player_landed(pad_100, true)
	for _f in range(10): await physics_frame

	assert(main_node.current_pad == 100, "Current pad must be 100")
	var arrival_card = hud.planet_arrival_card
	var arrival_title = hud.arrival_title
	assert(arrival_card != null and arrival_card.visible, "Arrival card must appear on Pad 100!")
	assert(arrival_title != null and arrival_title.text == "SUN JOURNEY COMPLETE", "Arrival title must be SUN JOURNEY COMPLETE, got: %s" % arrival_title.text)
	print(">>> Journey completion at Pad 100 PASSED!")

	# Save final screenshot at Pad 100
	var final_img = root.get_viewport().get_texture().get_image()
	if final_img != null:
		final_img.save_png("res://v8_2_long_run_pad100.png")
		print(">>> Saved Pad 100 victory screenshot: res://v8_2_long_run_pad100.png")

	# Memory growth evaluation
	print("\n=== MEMORY USAGE ANALYSIS ===")
	for p in memory_checkpoints.keys():
		print("  Pad %3d: %.2f MB" % [p, memory_checkpoints[p]])
	var net_mem_growth = memory_checkpoints[100] - memory_checkpoints[0]
	print("  Net static memory growth over 100 pads: %.2f MB" % net_mem_growth)
	assert(net_mem_growth < 50.0, "Memory growth excessive: %.2f MB" % net_mem_growth)

	print("\n===============================================================")
	print("=== ALL 100 PADS LONG-RUN VERIFICATION COMPLETED SUCCESSFULLY ===")
	print("===============================================================")
	quit()

func _is_gray(c: Color) -> bool:
	return absf(c.r - 0.298) < 0.02 and absf(c.g - 0.298) < 0.02 and absf(c.b - 0.298) < 0.02
