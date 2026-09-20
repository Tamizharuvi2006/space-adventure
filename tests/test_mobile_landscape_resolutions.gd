extends SceneTree

const SunZoneData = preload("res://scripts/planet_data.gd")
const SolarBackground = preload("res://scripts/background.gd")
const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")
const SolarHUD = preload("res://scripts/hud.gd")
const SolarCamera = preload("res://scripts/camera_follow.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")

const ARTIFACT_DIR = "C:/Users/aruvi/.gemini/antigravity-ide/brain/f75eeb4b-bf34-4366-b518-afc1bd64e4d0"

const TARGET_RESOLUTIONS = [
	{ "name": "1280x720 (16:9 Baseline)",    "size": Vector2i(1280, 720),  "aspect": 16.0 / 9.0,  "file": "mobile_res_1280x720_ref.png" },
	{ "name": "1920x1080 (16:9 FHD)",        "size": Vector2i(1920, 1080), "aspect": 16.0 / 9.0,  "file": "mobile_res_1920x1080_fhd.png" },
	{ "name": "1600x900 (16:9 HD+)",         "size": Vector2i(1600, 900),  "aspect": 16.0 / 9.0,  "file": "mobile_res_1600x900_hd.png" },
	{ "name": "2340x1080 (19.5:9 Phone)",    "size": Vector2i(2340, 1080), "aspect": 2340.0 / 1080.0, "file": "mobile_res_2340x1080_19_5_9.png" },
	{ "name": "2400x1080 (20:9 Flagship)",   "size": Vector2i(2400, 1080), "aspect": 2400.0 / 1080.0, "file": "mobile_res_2400x1080_20_9.png" },
	{ "name": "2560x1080 (21:9 Ultra-wide)", "size": Vector2i(2560, 1080), "aspect": 2560.0 / 1080.0, "file": "mobile_res_2560x1080_21_9.png" }
]

func _init() -> void:
	print("=== RUNNING EXPLORE SUN MOBILE LANDSCAPE RESOLUTION SUITE ===")
	call_deferred("_run_suite")

func _run_suite() -> void:
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

	# -------------------------------------------------------------------------
	# TEST PHASE 1: Verify Each Mobile Landscape Resolution
	# -------------------------------------------------------------------------
	for res_info in TARGET_RESOLUTIONS:
		var target_size = res_info["size"] as Vector2i
		var res_name = res_info["name"] as String
		var file_name = res_info["file"] as String
		var exp_aspect = res_info["aspect"] as float
		
		print("\n--- TESTING RESOLUTION: %s ---" % res_name)
		
		# Apply resolution to window and viewport
		DisplayServer.window_set_size(target_size)
		root.set_size(target_size)
		camera.global_position = player.global_position + Vector2(0.0, camera.default_vertical_offset)
		
		# Let layout and camera update
		for _i in range(25):
			await create_timer(0.02).timeout
		
		var vp = root.get_viewport()
		var vp_rect = vp.get_visible_rect()
		var vp_w = vp_rect.size.x
		var vp_h = vp_rect.size.y
		var actual_aspect = vp_w / vp_h
		
		print("  Logical Viewport: %.1f × %.1f (Aspect = %.3f, Expected = %.3f)" % [vp_w, vp_h, actual_aspect, exp_aspect])
		
		# 1. Verify vertical framing stability (reference 720p height preserved)
		assert(absf(vp_h - 720.0) < 2.0, "Vertical viewport height MUST remain ~720 to preserve vertical gameplay framing!")
		
		# 2. Verify horizontal expansion on wide screens
		if exp_aspect > (16.0 / 9.0) + 0.05:
			assert(vp_w > 1285.0, "Wide screen MUST expand logical width beyond 1280 to reveal more world horizontally!")
			var extra_world_px = vp_w - 1280.0
			print("  ✓ Revealing %.1f px additional horizontal world (%.1f%% wider)" % [extra_world_px, (extra_world_px / 1280.0) * 100.0])
		else:
			assert(absf(vp_w - 1280.0) < 2.0, "16:9 screens must match 1280px logical width!")
		
		# 3. Verify Player Framing in viewport
		var player_screen_x = (player.global_position.x - camera.global_position.x) + vp_w * 0.5
		var player_screen_y = (player.global_position.y - camera.global_position.y) + vp_h * 0.5
		print("  Player Screen Position: (%.1f, %.1f)" % [player_screen_x, player_screen_y])
		
		# Player must be horizontally centered within comfortable deadzone
		assert(absf(player_screen_x - vp_w * 0.5) < 30.0, "Player must remain centered horizontally across all resolutions!")
		
		# Player must be safely framed vertically (not near edges)
		assert(player_screen_y >= vp_h * 0.45 and player_screen_y <= vp_h * 0.72, "Player must have ample vertical headroom and landing buffer!")
		
		# 4. Verify Camera Zoom Stability
		assert(camera.zoom == Vector2.ONE, "Camera zoom must stay rock-solid at neutral Vector2.ONE (no stretching or distortion)!")
		
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
		
		# Check touch controls positioning
		var left_ctrl = hud.get_node("GameplayHUD/BottomMarginContainer/IndicatorHBox/LeftIndicator") as PanelContainer
		var right_ctrl = hud.get_node("GameplayHUD/BottomMarginContainer/IndicatorHBox/RightIndicator") as PanelContainer
		assert(left_ctrl.global_position.x >= ml - 5, "Left touch control must be placed safely inside left boundary!")
		assert(right_ctrl.global_position.x + right_ctrl.size.x <= vp_w + 5, "Right touch control must be placed safely inside right boundary!")
		
		# 6. Capture screenshot at this resolution
		await _capture(file_name)
		print("  ✅ Resolution %s Verified & Captured!" % res_name)

	# -------------------------------------------------------------------------
	# TEST PHASE 2: Landing Approach on Modern Wide Phone (2340x1080)
	# -------------------------------------------------------------------------
	print("\n--- TESTING LANDING APPROACH ON 2340x1080 (19.5:9 WIDE PHONE) ---")
	DisplayServer.window_set_size(Vector2i(2340, 1080))
	root.set_size(Vector2i(2340, 1080))
	for _i in range(15):
		await create_timer(0.02).timeout
	
	# Simulate descent into Pad 21 approach
	player.set_physics_process(false)
	player.current_state = SolarPlayer.State.FLYING
	player.global_position = pad_21.global_position + Vector2(-150.0, -90.0)
	camera.snap_to_target()
	player.velocity = Vector2(80.0, 70.0)
	for _i in range(30):
		player.global_position += player.velocity * 0.02
		await create_timer(0.02).timeout
	player.set_physics_process(true)
	
	var vp_size = root.get_viewport().get_visible_rect().size
	var pad_21_screen = (pad_21.global_position - camera.global_position) + vp_size * 0.5
	print("  Pad 21 Screen Position during Descent: %s in Viewport %s" % [pad_21_screen, vp_size])
	
	# Pad 21 must be completely visible in lower portion of screen
	assert(pad_21_screen.x > 50.0 and pad_21_screen.x < vp_size.x - 50.0, "Pad 21 must be safely on screen horizontally!")
	assert(pad_21_screen.y > 100.0 and pad_21_screen.y < vp_size.y - 40.0, "Landing pad deck must NOT be cropped by bottom edge during landing!")
	
	await _capture("mobile_landing_2340x1080.png")
	print("  ✅ Landing Visibility on 2340x1080 Phone Verified!")

	print("\n=======================================================")
	print("🎉 ALL MOBILE LANDSCAPE DISPLAY STANDARDS FULLY PASSED!")
	print("=======================================================")
	quit()

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img = root.get_viewport().get_texture().get_image()
	var dest = ARTIFACT_DIR + "/" + filename
	img.save_png(dest)
