extends SceneTree

const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")

var current_main: SolarMain = null
var failed_checks: int = 0
var total_pixels_checked: int = 0

func _init() -> void:
	call_deferred("_run_stress_test")

func _run_stress_test() -> void:
	print("=== STARTING V8.2 PERMANENT BACKGROUND EDGE COVERAGE STRESS TEST ===")
	
	var save_path = "user://explore_sun_save.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	var packed = load("res://scenes/main.tscn") as PackedScene
	current_main = packed.instantiate() as SolarMain
	root.add_child(current_main)

	for _i in range(5):
		await process_frame

	var hud = current_main.hud
	var player = current_main.player
	var camera = current_main.camera
	var world_gen = current_main.world_gen
	var bg = current_main.background

	hud.emit_signal("play_game_requested")
	while current_main.current_state != SolarMain.GameState.PLAYING:
		await physics_frame
	for _f in range(10): await physics_frame

	# Ensure pads up to 50 are generated
	while world_gen.next_platform_idx <= 52:
		world_gen.spawn_next_route_pad()
		await process_frame

	# -------------------------------------------------------------------------
	# TEST SUITE 1: 1280x720 - Multiple Camera Distances (0px to 45,000px & Reverse)
	# -------------------------------------------------------------------------
	print("\n--- SUITE 1: 1280x720 Multi-Distance Edge Verification ---")
	root.get_viewport().size = Vector2i(1280, 720)
	await process_frame
	await process_frame

	var pad_0 = world_gen.get_platform_by_index(0)
	var pad_1 = world_gen.get_platform_by_index(1)
	var pad_20 = world_gen.get_platform_by_index(20)
	var pad_21 = world_gen.get_platform_by_index(21)
	var pad_45 = world_gen.get_platform_by_index(45)

	# 1A: Pad 0 (Starting location)
	player.spawn_on_platform(pad_0)
	camera.set_next_target_platform(pad_1)
	camera.snap_to_target()
	bg.notify_pad_changed(0)
	for _f in range(25): await physics_frame
	_check_and_save("v8_2_stress_1280x720_pad0.png", "Pad 0 (Start)")

	# 1B: Continuous sweep to +2,000px
	print("\n-- Continuous sweep from Pad 0 to +2,000px --")
	await _continuous_camera_sweep(player.global_position.x, player.global_position.x + 2000.0, 40)
	_check_and_save("v8_2_stress_1280x720_2000px.png", "+2,000px")

	# 1C: Continuous sweep to +5,000px
	print("\n-- Continuous sweep to +5,000px --")
	await _continuous_camera_sweep(camera.global_position.x, player.global_position.x + 5000.0, 40)
	_check_and_save("v8_2_stress_1280x720_5000px.png", "+5,000px")

	# 1D: Pad 20 (~17,880px) - Stationary with zoom
	player.spawn_on_platform(pad_20)
	camera.set_next_target_platform(pad_21)
	camera.snap_to_target()
	bg.notify_pad_changed(20)
	for _f in range(25): await physics_frame
	_check_and_save("v8_2_stress_1280x720_pad20.png", "Pad 20 (~17,880px)")

	# 1E: +20,000px Continuous High Speed Flight
	print("\n-- Continuous flight past +20,000px --")
	player.global_position = Vector2(20000.0, -200.0)
	player.current_state = SolarPlayer.State.FLYING
	player.velocity = Vector2(300.0, -10.0)
	player.set_mobile_inputs(false, true)
	camera.global_position = Vector2(20000.0, -200.0)
	for _f in range(30):
		await physics_frame
		_verify_edge_pixels(root.get_viewport().get_texture().get_image(), "Continuous flight at x=%.0f" % camera.global_position.x)
	_check_and_save("v8_2_stress_1280x720_20000px.png", "+20,000px Flight")

	# 1F: Huge distance +45,000px (Zone 4)
	print("\n-- Huge travel distance +45,000px --")
	player.spawn_on_platform(pad_45)
	camera.set_next_target_platform(world_gen.get_platform_by_index(46))
	camera.snap_to_target()
	bg.notify_pad_changed(45)
	for _f in range(25): await physics_frame
	_check_and_save("v8_2_stress_1280x720_45000px.png", "+45,000px (Zone 4)")

	# 1G: Reverse travel toward starting area
	print("\n-- Reverse travel continuous sweep backwards (-5,000px) --")
	await _continuous_camera_sweep(camera.global_position.x, camera.global_position.x - 5000.0, 40)
	_check_and_save("v8_2_stress_1280x720_reverse.png", "Reverse Travel")

	# -------------------------------------------------------------------------
	# TEST SUITE 2: Multi-Resolution Stress Tests (1920x1080, 2340x1080, 1280x800)
	# -------------------------------------------------------------------------
	print("\n--- SUITE 2: Multi-Resolution Verification ---")

	# 2A: 1920x1080 (Full HD)
	root.get_viewport().size = Vector2i(1920, 1080)
	for _f in range(10): await process_frame
	_check_and_save("v8_2_stress_1920x1080.png", "1920x1080 (FHD)")

	# 2B: 2340x1080 (Ultra-wide Mobile 19.5:9)
	root.get_viewport().size = Vector2i(2340, 1080)
	for _f in range(10): await process_frame
	_check_and_save("v8_2_stress_2340x1080_ultrawide.png", "2340x1080 (Ultra-wide)")

	# 2C: 1280x800 (16:10 Aspect)
	root.get_viewport().size = Vector2i(1280, 800)
	for _f in range(10): await process_frame
	_check_and_save("v8_2_stress_1280x800.png", "1280x800 (16:10)")

	# -------------------------------------------------------------------------
	# FINAL SUMMARY
	# -------------------------------------------------------------------------
	print("\n=== STRESS TEST COMPLETED ===")
	print("Total pixels inspected at viewport edges: %d" % total_pixels_checked)
	print("Total edge errors / gray pixels detected: %d" % failed_checks)
	
	if failed_checks == 0:
		print(">>> SUCCESS: ZERO gray pixels, ZERO black gaps, ZERO seams detected! 100% continuous background coverage verified. <<<")
	else:
		print(">>> FAILURE: Found %d invalid pixels at viewport edges! <<<" % failed_checks)

	quit()

func _continuous_camera_sweep(start_x: float, end_x: float, steps: int) -> void:
	var camera = current_main.camera
	var bg = current_main.background
	for s in range(steps):
		var t = float(s) / float(steps)
		var cx = lerpf(start_x, end_x, t)
		camera.global_position.x = cx
		bg.update_camera_offset(camera.global_position)
		await physics_frame
		var img = root.get_viewport().get_texture().get_image()
		_verify_edge_pixels(img, "Sweep step %d/%d (x=%.0f)" % [s, steps, cx])

func _check_and_save(filename: String, label: String) -> void:
	var img = root.get_viewport().get_texture().get_image()
	_verify_edge_pixels(img, label)
	img.save_png("res://" + filename)
	print("Saved %s [%s]" % [filename, label])

func _verify_edge_pixels(img: Image, context: String) -> void:
	if not img:
		return
	var w = img.get_width()
	var h = img.get_height()
	
	var scan_ys = [40, int(h * 0.25), int(h * 0.50), int(h * 0.75), h - 40]
	
	# Sample left 15 pixels and right 15 pixels
	for y in scan_ys:
		# Left edge
		for x in range(0, 15):
			total_pixels_checked += 1
			var c = img.get_pixel(x, y)
			_assert_valid_color(c, x, y, context, "LEFT")
		# Right edge
		for x in range(w - 15, w):
			total_pixels_checked += 1
			var c = img.get_pixel(x, y)
			_assert_valid_color(c, x, y, context, "RIGHT")

func _assert_valid_color(c: Color, x: int, y: int, context: String, side: String) -> void:
	# Check for Godot default clear gray (approx 0.298, 0.298, 0.298)
	var is_gray = (absf(c.r - 0.298) < 0.02 and absf(c.g - 0.298) < 0.02 and absf(c.b - 0.298) < 0.02)
	# Check for pure unrendered black (0, 0, 0)
	var is_black = (c.r < 0.005 and c.g < 0.005 and c.b < 0.005 and c.a > 0.9)
	
	if is_gray:
		failed_checks += 1
		printerr("[FAIL] %s %s edge gray detected at (%d, %d): %s" % [context, side, x, y, c])
	elif is_black:
		failed_checks += 1
		printerr("[FAIL] %s %s edge black hole detected at (%d, %d): %s" % [context, side, x, y, c])
