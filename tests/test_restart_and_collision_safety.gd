extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const SunZoneData = preload("res://scripts/planet_data.gd")
const SolarTerrainGenerator = preload("res://scripts/terrain_generator.gd")

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("\n=======================================================")
	print("   TEST: RESTART BUTTON FROM 1 & COLLISION SAFETY      ")
	print("=======================================================\n")

	# ─────────────────────────────────────────────────────────────
	# TEST 1: Collision Safety across all terrain motifs
	# ─────────────────────────────────────────────────────────────
	print("--- TEST 1: Terrain Motif Flight Corridor Collision Safety ---")
	var dummy_root = Node2D.new()
	root.add_child(dummy_root)
	var terrain_gen = SolarTerrainGenerator.new()
	dummy_root.add_child(terrain_gen)

	# Mock two platforms at arbitrary heights
	var platform_scene = preload("res://scenes/platform.tscn")
	var pad_a = platform_scene.instantiate() as SolarPlatform
	var pad_b = platform_scene.instantiate() as SolarPlatform
	dummy_root.add_child(pad_a)
	dummy_root.add_child(pad_b)
	pad_a.platform_index = 1
	pad_a.global_position = Vector2(500.0, 400.0)
	pad_a.set_platform_width(180.0)
	pad_b.platform_index = 2
	pad_b.global_position = Vector2(1700.0, 380.0)
	pad_b.set_platform_width(160.0)

	var motifs = [
		SolarTerrainGenerator.FormationType.MESA,
		SolarTerrainGenerator.FormationType.VALLEY_SHELF,
		SolarTerrainGenerator.FormationType.CLIFF_LEFT,
		SolarTerrainGenerator.FormationType.CLIFF_RIGHT,
		SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK,
		SolarTerrainGenerator.FormationType.CRATER_RIM
	]

	var pad_min_y = minf(pad_a.global_position.y, pad_b.global_position.y) # higher on screen

	for m in motifs:
		terrain_gen.build_canyon_segment(pad_a, pad_b, m)
		var chunk = terrain_gen.active_chunks[2]
		assert(chunk != null, "Chunk must exist for Pad 2")
		var rock_body = chunk.get_node_or_null("RockBody") as Polygon2D
		assert(rock_body != null, "RockBody polygon must exist")
		
		# Verify all surface points are safely below the pads (greater Y in Godot)
		for pt in rock_body.polygon:
			# abyss points have y = 3600.0, surface points must be > pad_min_y + 40.0
			assert(pt.y > pad_min_y + 40.0, "Motif %s generated a point at Y=%.1f which intrudes above pad corridor (min_y=%.1f)!" % [m, pt.y, pad_min_y])
		print("  ✅ Motif %d verified: All polygon vertices safely beneath flight corridor." % m)

	dummy_root.queue_free()

	# ─────────────────────────────────────────────────────────────
	# TEST 2: Restart from 1 via HUD signal
	# ─────────────────────────────────────────────────────────────
	print("\n--- TEST 2: Restart From 1 Functionality ---")
	var main_node = MainScene.instantiate() as SolarMain
	root.add_child(main_node)
	await process_frame
	await process_frame

	# Simulate having progressed to Pad 15 with Best Pad 20
	main_node.current_checkpoint = 15
	main_node.current_pad = 15
	main_node.best_pad = 20
	main_node.save_game_progress()
	print("  Simulated save state: Checkpoint Pad 15, Best Pad 20")

	# Trigger restart request (as if clicking Restart in Pause Menu or Main Menu)
	main_node.hud.emit_signal("restart_game_requested")
	await process_frame
	await process_frame

	assert(main_node.current_checkpoint == 1, "After restart, current_checkpoint must be 1, got %d" % main_node.current_checkpoint)
	assert(main_node.current_pad == 1, "After restart, current_pad must be 1, got %d" % main_node.current_pad)
	assert(main_node.best_pad == 20, "High score best_pad must be preserved (20), got %d" % main_node.best_pad)
	assert(main_node.player.target_platform_ref.platform_index == 2, "Target platform after restart must be Pad 2, got %d" % main_node.player.target_platform_ref.platform_index)

	# Verify disk save was updated to checkpoint 1
	var loaded_save = main_node._load_raw_save_data()
	assert(int(loaded_save["checkpoint_pad"]) == 1, "Saved checkpoint on disk must be 1, got %s" % str(loaded_save["checkpoint_pad"]))
	assert(int(loaded_save["best_pad"]) == 20, "Saved best_pad on disk must be 20, got %s" % str(loaded_save["best_pad"]))
	print("  ✅ Disk save verified: Checkpoint reset to 1, Best pad preserved at 20.")

	# ─────────────────────────────────────────────────────────────
	# TEST 3: MainMenu Continue / Restart button visibility
	# ─────────────────────────────────────────────────────────────
	print("\n--- TEST 3: MainMenu Dynamic Continue & Restart Buttons ---")
	# When checkpoint is 1
	main_node.hud.show_main_menu(20, 1)
	assert(main_node.hud.play_button.text == "▶ PLAY", "Play button should say '▶ PLAY' when checkpoint is 1")
	if main_node.hud.menu_restart_button:
		assert(not main_node.hud.menu_restart_button.visible, "MenuRestartButton should be hidden when checkpoint is 1")

	# When checkpoint > 1 (e.g. 15)
	main_node.hud.show_main_menu(20, 15)
	assert("CONTINUE" in main_node.hud.play_button.text, "Play button should say CONTINUE when checkpoint > 1")
	if main_node.hud.menu_restart_button:
		assert(main_node.hud.menu_restart_button.visible, "MenuRestartButton should be visible when checkpoint > 1")
	print("  ✅ MainMenu dynamic buttons verified.")

	# Clean up
	main_node.queue_free()
	print("\n🎉 ALL TESTS PASSED SUCCESSFULLY! 🎉\n")
	quit(0)
