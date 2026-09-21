extends SceneTree

const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
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

	var pad_0 = world_gen.get_platform_by_index(0)
	var pad_1 = world_gen.get_platform_by_index(1)
	player.spawn_on_platform(pad_0)
	camera.set_next_target_platform(pad_1)
	camera.snap_to_target()
	for _f in range(25): await physics_frame

	# 1. Capture Resting Clean Screen (No buttons visible!)
	var img_resting = root.get_viewport().get_texture().get_image()
	img_resting.save_png("res://v8_2_controls_clean_resting.png")
	print("Saved v8_2_controls_clean_resting.png")

	# Check bottom-left and bottom-right button areas - must be clean background (alpha = 0 for button box)
	var left_ind = hud.get_node("GameplayHUD/BottomMarginContainer/IndicatorHBox/LeftIndicator")
	var right_ind = hud.get_node("GameplayHUD/BottomMarginContainer/IndicatorHBox/RightIndicator")
	print("Resting left indicator modulate.a: ", left_ind.modulate.a)
	print("Resting right indicator modulate.a: ", right_ind.modulate.a)
	assert(left_ind.modulate.a < 0.05, "Left indicator should be invisible at rest!")
	assert(right_ind.modulate.a < 0.05, "Right indicator should be invisible at rest!")

	# 2. Simulate Left Touch Zone press (finger on left 50%)
	var vp_w = root.get_viewport().get_visible_rect().size.x
	var touch_l = InputEventScreenTouch.new()
	touch_l.index = 0
	touch_l.pressed = true
	touch_l.position = Vector2(vp_w * 0.25, 400.0)
	hud._unhandled_input(touch_l)

	for _f in range(15): await physics_frame
	print("Left pressed - touch_steer_l: ", hud.touch_steer_l, " touch_steer_r: ", hud.touch_steer_r)
	print("Left indicator modulate.a: ", left_ind.modulate.a)
	assert(hud.touch_steer_l == true, "Left thruster must be active!")
	assert(hud.touch_steer_r == false, "Right thruster must be inactive!")
	assert(left_ind.modulate.a > 0.4, "Left indicator should illuminate on touch!")

	var img_left = root.get_viewport().get_texture().get_image()
	img_left.save_png("res://v8_2_controls_left_active.png")
	print("Saved v8_2_controls_left_active.png")

	# 3. Simulate Multi-touch: Second finger on right 50%
	var touch_r = InputEventScreenTouch.new()
	touch_r.index = 1
	touch_r.pressed = true
	touch_r.position = Vector2(vp_w * 0.75, 400.0)
	hud._unhandled_input(touch_r)

	for _f in range(15): await physics_frame
	print("Dual touch - touch_steer_l: ", hud.touch_steer_l, " touch_steer_r: ", hud.touch_steer_r)
	assert(hud.touch_steer_l == true and hud.touch_steer_r == true, "Both thrusters must be active with multi-touch!")

	var img_dual = root.get_viewport().get_texture().get_image()
	img_dual.save_png("res://v8_2_controls_dual_touch.png")
	print("Saved v8_2_controls_dual_touch.png")

	# 4. Release fingers
	touch_l.pressed = false
	hud._unhandled_input(touch_l)
	touch_r.pressed = false
	hud._unhandled_input(touch_r)

	for _f in range(25): await physics_frame
	assert(hud.touch_steer_l == false and hud.touch_steer_r == false, "Thrusters must deactivate on release!")
	print("Released - left indicator modulate.a: ", left_ind.modulate.a)
	assert(left_ind.modulate.a < 0.05, "Indicator must fade back to invisible!")

	print(">>> ALL TOUCH ZONE CONTROLS VERIFIED SUCCESSFULLY! <<<")
	quit()
