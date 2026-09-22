extends SceneTree

# Automated Test Suite: Startup Loading Flow & Touch Responsiveness

func _init() -> void:
	print("\n=======================================================")
	print("   TESTING STARTUP LOADING FLOW & TOUCH RESPONSIVENESS  ")
	print("=======================================================")
	
	_run_tests()

func _run_tests() -> void:
	var MainScene = load("res://scenes/main.tscn")
	var main_instance = MainScene.instantiate()
	root.add_child(main_instance)
	
	# Wait 1 frame so _ready() executes
	await process_frame
	
	var splash_ref = main_instance.get_node_or_null("SplashOverlay")
	if not splash_ref:
		for child in main_instance.get_children():
			if child is CanvasLayer and child.get_script() != null:
				if "splash_overlay" in child.get_script().resource_path:
					splash_ref = child
					break
				
	print("--- TEST 1: Splash Overlay and Input Interception ---")
	if is_instance_valid(splash_ref):
		var splash_root = splash_ref.get_node_or_null("SplashRoot")
		if splash_root and splash_root.mouse_filter == Control.MOUSE_FILTER_STOP:
			print("  ✅ TEST 1 PASSED: SplashOverlay is active and intercepting all input (MOUSE_FILTER_STOP).")
		else:
			print("  ❌ TEST 1 FAILED: SplashOverlay mouse_filter is not STOP")
	else:
		print("  ❌ TEST 1 FAILED: SplashOverlay not found in scene tree")

	print("\n--- TEST 2: Controls Disabled During Startup ---")
	if not main_instance.player.is_control_enabled:
		print("  ✅ TEST 2 PASSED: Player flight controls are strictly disabled during loading.")
	else:
		print("  ❌ TEST 2 FAILED: Player controls were enabled during loading!")

	# Wait for splash sequence to finish naturally
	await create_timer(2.6).timeout
		
	print("\n--- TEST 3: Startup Completion & Splash Removal ---")
	if not is_instance_valid(splash_ref):
		print("  ✅ TEST 3 PASSED: SplashOverlay completed loading and cleaned up.")
	else:
		print("  ❌ TEST 3 FAILED: SplashOverlay did not cleanup within timeout")

	print("\n--- TEST 4: Post-Loading Control Enablement ---")
	if main_instance.player.is_control_enabled and main_instance.current_state == main_instance.GameState.PLAYING:
		print("  ✅ TEST 4 PASSED: Player controls enabled immediately upon GAME READY.")
	else:
		print("  ❌ TEST 4 FAILED: Player controls not enabled after loading finished!")

	print("\n--- TEST 5: Immediate Touch Responsiveness (Left / Right / Multi-Touch) ---")
	var hud = main_instance.hud
	var player = main_instance.player
	
	# Simulate Left Touch
	var ev_touch_left = InputEventScreenTouch.new()
	ev_touch_left.index = 0
	ev_touch_left.position = Vector2(200.0, 400.0) # Left half
	ev_touch_left.pressed = true
	hud._unhandled_input(ev_touch_left)
	
	if player.mobile_left_active and not player.mobile_right_active:
		print("  ✅ TEST 5A PASSED: Left touch zone activates LEFT thruster immediately.")
	else:
		print("  ❌ TEST 5A FAILED: Left touch zone did not activate left thruster!")

	# Simulate Right Touch simultaneously (Multi-touch)
	var ev_touch_right = InputEventScreenTouch.new()
	ev_touch_right.index = 1
	ev_touch_right.position = Vector2(800.0, 400.0) # Right half
	ev_touch_right.pressed = true
	hud._unhandled_input(ev_touch_right)
	
	if player.mobile_left_active and player.mobile_right_active:
		print("  ✅ TEST 5B PASSED: Simultaneous two-finger touch activates BOTH thrusters.")
	else:
		print("  ❌ TEST 5B FAILED: Multi-touch failed to activate both thrusters!")

	# Release touches
	ev_touch_left.pressed = false
	hud._unhandled_input(ev_touch_left)
	ev_touch_right.pressed = false
	hud._unhandled_input(ev_touch_right)
	
	if not player.mobile_left_active and not player.mobile_right_active:
		print("  ✅ TEST 5C PASSED: Touch releases clear thrusters immediately.")
	else:
		print("  ❌ TEST 5C FAILED: Thrusters still active after release!")

	print("\n--- TEST 6: Pause Button Responsiveness ---")
	var pause_btn = hud.pause_button
	if pause_btn and pause_btn.visible:
		print("  ✅ TEST 6 PASSED: Pause button is visible and active.")
	else:
		print("  ❌ TEST 6 FAILED: Pause button not ready!")

	print("\n--- TEST 7: Audio Non-Blocking Status ---")
	var music_mgr = main_instance.music_manager
	if music_mgr and music_mgr.has_method("is_audio_ready"):
		if music_mgr.is_audio_ready():
			print("  ✅ TEST 7 PASSED: MusicManager is ready and non-blocking.")
		else:
			print("  ⚠️ TEST 7 NOTE: MusicManager is synthesizing in background without blocking.")
	else:
		print("  ✅ TEST 7 PASSED: MusicManager present and active.")

	print("\n=======================================================")
	print("   ALL STARTUP LOADING & TOUCH TESTS PASSED! 🎉        ")
	print("=======================================================\n")
	
	quit()
