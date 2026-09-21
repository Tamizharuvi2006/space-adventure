extends SceneTree

const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")

func _init() -> void:
	call_deferred("_run_mobile_feel_test")

func _run_mobile_feel_test() -> void:
	print("=== RUNNING TEST 4: MOBILE FEEL ACROSS ASPECT RATIOS ===")

	var save_path = "user://explore_sun_save.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	var packed = load("res://scenes/main.tscn") as PackedScene
	var current_main = packed.instantiate() as SolarMain
	root.add_child(current_main)

	for _i in range(5):
		await process_frame

	var hud = current_main.hud
	var player = current_main.player
	var camera = current_main.camera
	var world_gen = current_main.world_gen

	hud.emit_signal("play_game_requested")
	while current_main.current_state != SolarMain.GameState.PLAYING:
		await physics_frame
	for _f in range(10): await physics_frame

	while world_gen.next_platform_idx <= 10:
		world_gen.spawn_next_route_pad()
		await process_frame

	var pad_0 = world_gen.get_platform_by_index(0)
	var pad_1 = world_gen.get_platform_by_index(1)
	player.spawn_on_platform(pad_0)
	camera.set_next_target_platform(pad_1)
	camera.snap_to_target()
	for _f in range(25): await physics_frame

	var aspect_configs = [
		{"name": "16:9 (Standard Phone / HD)", "size": Vector2i(1280, 720), "file": "v8_2_mobile_16_9.png"},
		{"name": "18:9 (2:1 Wide Phone)", "size": Vector2i(2160, 1080), "file": "v8_2_mobile_18_9.png"},
		{"name": "19.5:9 (Modern iPhone / Galaxy)", "size": Vector2i(2340, 1080), "file": "v8_2_mobile_19_5_9.png"},
		{"name": "20:9 (Ultra-tall Android Flagship)", "size": Vector2i(2400, 1080), "file": "v8_2_mobile_20_9.png"},
		{"name": "Tablet Landscape (4:3 iPad)", "size": Vector2i(1440, 1080), "file": "v8_2_mobile_tablet_4_3.png"},
		{"name": "Tablet Landscape (16:10 Android Tablet)", "size": Vector2i(1280, 800), "file": "v8_2_mobile_tablet_16_10.png"},
	]

	for cfg in aspect_configs:
		print("\nTesting %s [%dx%d]..." % [cfg.name, cfg.size.x, cfg.size.y])
		DisplayServer.window_set_size(cfg.size)
		root.size = cfg.size
		hud._update_safe_margins()

		player.spawn_on_platform(pad_0)
		camera.set_next_target_platform(pad_1)
		camera.snap_to_target()
		for _f in range(15): await physics_frame
		for _f in range(5): await process_frame

		var vp_rect = root.get_viewport().get_visible_rect()
		var vp_w = vp_rect.size.x
		var vp_h = vp_rect.size.y

		# 1. Check Composition: Astronaut and target pad screen coordinates
		var player_screen = camera.get_screen_position(player.global_position) if camera.has_method("get_screen_position") else (player.global_position - camera.global_position) * camera.zoom + vp_rect.size * 0.5
		var pad1_screen = (pad_1.global_position - camera.global_position) * camera.zoom + vp_rect.size * 0.5

		print("  Astronaut screen X: %.1f (%.1f%% width)" % [player_screen.x, (player_screen.x / vp_w) * 100.0])
		print("  Pad 1 screen X: %.1f (%.1f%% width)" % [pad1_screen.x, (pad1_screen.x / vp_w) * 100.0])

		# Astronaut must be in left-center comfort zone (20% to 60%)
		assert(player_screen.x > vp_w * 0.20 and player_screen.x < vp_w * 0.60, "Astronaut poorly composed on %s" % cfg.name)
		# Pad 1 must be in forward travel region (45% to 95%)
		assert(pad1_screen.x > vp_w * 0.45 and pad1_screen.x < vp_w * 0.95, "Target pad out of composition on %s" % cfg.name)

		# 2. Check HUD: Pause button within top-right corner, Altitude within center
		var pause_btn = hud.get_node("GameplayHUD/TopMarginContainer/TopBar/PauseButton")
		var alt_lbl = hud.get_node("GameplayHUD/TopMarginContainer/TopBar/CenterCluster/AltitudeLabel")
		var pause_screen_x = pause_btn.global_position.x
		print("  Pause button screen X: %.1f (%.1f%% canvas width)" % [pause_screen_x, (pause_screen_x / vp_w) * 100.0])
		assert(pause_screen_x > vp_w * 0.80, "Pause button misplaced on %s" % cfg.name)
		assert(absf(alt_lbl.global_position.x + alt_lbl.size.x * 0.5 - vp_w * 0.5) < 120.0, "HUD center cluster off-center on %s" % cfg.name)

		# 3. Check Background edge pixels (No gray!)
		var img = root.get_viewport().get_texture().get_image()
		if img != null:
			var img_w = img.get_width()
			var img_h = img.get_height()
			var is_left_gray = _pixel_is_gray(img.get_pixel(0, int(img_h * 0.5)))
			var is_right_gray = _pixel_is_gray(img.get_pixel(img_w - 1, int(img_h * 0.5)))
			assert(not is_left_gray, "Left edge gray detected on %s!" % cfg.name)
			assert(not is_right_gray, "Right edge gray detected on %s!" % cfg.name)

			# Save screenshot
			img.save_png("res://" + cfg.file)
			print("  -> PASSED: %s saved to %s" % [cfg.name, cfg.file])

		# 4. Verify Touch Zones at this resolution
		# Left zone touch
		var touch_l = InputEventScreenTouch.new()
		touch_l.index = 0
		touch_l.pressed = true
		touch_l.position = Vector2(vp_w * 0.25, vp_h * 0.5)
		hud._unhandled_input(touch_l)
		await physics_frame
		assert(hud.touch_steer_l == true and hud.touch_steer_r == false, "Left touch zone failed on %s" % cfg.name)

		# Right zone multi-touch
		var touch_r = InputEventScreenTouch.new()
		touch_r.index = 1
		touch_r.pressed = true
		touch_r.position = Vector2(vp_w * 0.75, vp_h * 0.5)
		hud._unhandled_input(touch_r)
		await physics_frame
		assert(hud.touch_steer_l == true and hud.touch_steer_r == true, "Multi-touch zone failed on %s" % cfg.name)

		# Release touches
		touch_l.pressed = false
		hud._unhandled_input(touch_l)
		touch_r.pressed = false
		hud._unhandled_input(touch_r)
		for _f in range(5): await physics_frame

	print("\n>>> ALL MOBILE FEEL AND ASPECT RATIO TESTS PASSED! <<<")
	quit()

func _pixel_is_gray(c: Color) -> bool:
	return absf(c.r - 0.298) < 0.02 and absf(c.g - 0.298) < 0.02 and absf(c.b - 0.298) < 0.02
