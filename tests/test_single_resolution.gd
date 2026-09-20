extends SceneTree

const SunZoneData = preload("res://scripts/planet_data.gd")
const SolarBackground = preload("res://scripts/background.gd")
const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")
const SolarHUD = preload("res://scripts/hud.gd")
const SolarCamera = preload("res://scripts/camera_follow.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")

const ARTIFACT_DIR = "C:/Users/aruvi/.gemini/antigravity-ide/brain/f75eeb4b-bf34-4366-b518-afc1bd64e4d0"

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var args = OS.get_cmdline_user_args()
	var res_name = args[0] if args.size() > 0 else "1280x720 (Baseline)"
	var out_filename = args[1] if args.size() > 1 else "mobile_test.png"
	var test_landing = (args[2] == "true") if args.size() > 2 else false

	print("\n=======================================================")
	print("TESTING MOBILE RESOLUTION: %s" % res_name)
	print("=======================================================")

	var packed = load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate() as SolarMain
	root.add_child(main)

	var hud = main.get_node("HUD") as SolarHUD
	var player = main.get_node("Player") as SolarPlayer
	var world_gen = main.get_node("WorldGenerator") as WorldGenerator
	var bg = main.get_node("Background") as SolarBackground
	var camera = main.get_node("Camera2D") as SolarCamera

	await create_timer(0.3).timeout

	hud.emit_signal("play_game_requested")
	while main.current_state != SolarMain.GameState.PLAYING:
		await create_timer(0.05).timeout
	await create_timer(0.2).timeout

	# Pre-spawn pads up to 25
	while world_gen.next_platform_idx <= 25:
		world_gen.spawn_next_route_pad()

	var pad_20 = world_gen.get_platform_by_index(20)
	var pad_21 = world_gen.get_platform_by_index(21)
	assert(pad_20 != null and pad_21 != null, "Pads 20 and 21 must exist!")

	main.current_state = SolarMain.GameState.PLAYING
	player.set_control_enabled(true)
	player.spawn_on_platform(pad_20)
	main.current_pad = 20
	main._update_target_platform(21)
	camera.global_position = player.global_position + Vector2(0.0, -45.0)

	# Allow layout and camera to stabilize
	for _i in range(30):
		await create_timer(0.02).timeout

	var vp = root.get_viewport()
	var vp_rect = vp.get_visible_rect()
	var vp_w = vp_rect.size.x
	var vp_h = vp_rect.size.y
	var actual_aspect = vp_w / vp_h

	print("  Logical Viewport: %.1f × %.1f (Aspect = %.3f)" % [vp_w, vp_h, actual_aspect])

	# 1. Verify vertical framing stability (reference 720p height preserved)
	assert(absf(vp_h - 720.0) < 3.0, "Vertical viewport height MUST remain ~720 to preserve vertical gameplay framing!")

	# 2. Verify horizontal world reveal
	if actual_aspect > (16.0 / 9.0) + 0.02:
		assert(vp_w >= 1280.0, "Wide screen MUST expand logical width beyond 1280 to reveal more world horizontally!")
		var extra_world_px = vp_w - 1280.0
		print("  ✓ Revealing %.1f px additional horizontal world (%.1f%% wider)" % [extra_world_px, (extra_world_px / 1280.0) * 100.0])
	else:
		assert(absf(vp_w - 1280.0) < 10.0, "16:9 screens must match ~1280px logical width!")
		print("  ✓ Standard 16:9 reference framing (1280 × 720)")

	# 3. Verify Player Framing in viewport
	var player_screen_x = (player.global_position.x - camera.global_position.x) + vp_w * 0.5
	var player_screen_y = (player.global_position.y - camera.global_position.y) + vp_h * 0.5
	print("  Player Screen Position: (%.1f, %.1f)" % [player_screen_x, player_screen_y])

	# Player must be horizontally centered within comfortable deadzone
	assert(absf(player_screen_x - vp_w * 0.5) < 30.0, "Player must remain centered horizontally across all resolutions!")

	# Player must be safely framed vertically
	assert(player_screen_y >= vp_h * 0.45 and player_screen_y <= vp_h * 0.65, "Player must have ample vertical headroom and landing buffer!")

	# 4. Verify Camera Zoom Stability
	assert(camera.zoom == Vector2.ONE, "Camera zoom must stay rock-solid at neutral Vector2.ONE!")

	# 5. Verify HUD and Safe Area Anchors
	var top_bar = hud.get_node("GameplayHUD/TopMarginContainer") as MarginContainer
	var bottom_bar = hud.get_node("GameplayHUD/BottomMarginContainer") as MarginContainer
	assert(top_bar != null and bottom_bar != null, "HUD margin containers must exist!")

	var ml = top_bar.get_theme_constant("margin_left")
	var mr = top_bar.get_theme_constant("margin_right")
	var mb = bottom_bar.get_theme_constant("margin_bottom")
	print("  HUD Safe Margins: Left=%d, Right=%d, Bottom=%d" % [ml, mr, mb])
	assert(ml >= 24 and mr >= 24, "HUD margins must respect minimum 24px safe boundaries for notches/cutouts!")
	assert(mb >= 16, "Bottom HUD margin must clear gesture bars and lower bezels!")

	# Capture main resting state screenshot
	await _capture(out_filename)
	print("  ✅ Captured resting state screenshot: %s" % out_filename)

	# 6. Test Landing Approach if requested
	if test_landing:
		print("\n--- SIMULATING LANDING APPROACH ON THIS ASPECT RATIO ---")
		main.current_state = SolarMain.GameState.PLAYING
		player.set_control_enabled(true)
		player.current_state = SolarPlayer.State.FLYING
		hud.game_over_menu.visible = false
		hud.gameplay_hud.visible = true

		player.global_position = pad_21.global_position + Vector2(-220.0, -110.0)
		camera.global_position = player.global_position + Vector2(0.0, -45.0)
		for _i in range(30):
			player.velocity = Vector2(80.0, 60.0)
			await create_timer(0.02).timeout

		var pad_21_screen = (pad_21.global_position - camera.global_position) + vp_rect.size * 0.5
		print("  Pad 21 Screen Position during Landing: %s in Viewport %s" % [pad_21_screen, vp_rect.size])

		assert(pad_21_screen.x > 40.0 and pad_21_screen.x < vp_w - 40.0, "Pad 21 must be safely on-screen horizontally!")
		assert(pad_21_screen.y > 100.0 and pad_21_screen.y < vp_h - 30.0, "Landing pad deck must NOT be cropped by bottom edge during landing!")

		var landing_out = "mobile_landing_" + out_filename
		await _capture(landing_out)
		print("  ✅ Captured landing approach screenshot: %s" % landing_out)

	print("\n🎉 %s: PASSED ALL CHECKS!" % res_name)
	quit(0)

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img = root.get_viewport().get_texture().get_image()
	var dest = ARTIFACT_DIR + "/" + filename
	img.save_png(dest)
