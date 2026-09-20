extends SceneTree

const ARTIFACT_DIR = "C:/Users/aruvi/.gemini/antigravity-ide/brain/f75eeb4b-bf34-4366-b518-afc1bd64e4d0"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed = load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate()
	root.add_child(main)

	var hud = main.get_node("HUD")
	var player = main.get_node("Player")
	var camera = main.get_node("Camera2D")

	await create_timer(0.4).timeout

	# 1. Capture Main Menu / Pad 0 docked
	await _capture("real_gameplay_01_main_menu.png")
	print("Captured 01: Main menu at Pad 0")

	# 2. Click Play
	hud.emit_signal("play_game_requested")
	# Wait for countdown
	while main.current_state != 2: # PLAYING
		await create_timer(0.05).timeout
	await create_timer(0.1).timeout

	await _capture("real_gameplay_02_playing_start.png")
	print("Captured 02: Playing start at Pad 0. Cam pos = %s, Player pos = %s" % [camera.global_position, player.global_position])

	# 3. Thrust upwards for 1.5 seconds
	player.set_mobile_inputs(true, true)
	for i in range(40):
		await create_timer(0.02).timeout
	await _capture("real_gameplay_03_thrust_upward.png")
	print("Captured 03: Upward thrust. Cam pos = %s, Player pos = %s" % [camera.global_position, player.global_position])

	# 4. Fly right towards Pad 1
	player.set_mobile_inputs(false, true)
	for i in range(40):
		await create_timer(0.02).timeout
	await _capture("real_gameplay_04_flying_right.png")
	print("Captured 04: Flying right. Cam pos = %s, Player pos = %s" % [camera.global_position, player.global_position])

	# 5. Free fall descent
	player.set_mobile_inputs(false, false)
	for i in range(40):
		await create_timer(0.02).timeout
	await _capture("real_gameplay_05_descent.png")
	print("Captured 05: Descent. Cam pos = %s, Player pos = %s" % [camera.global_position, player.global_position])

	print("=== CAPTURE REAL GAMEPLAY COMPLETE ===")
	quit(0)

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img = root.get_viewport().get_texture().get_image()
	var dest = ARTIFACT_DIR + "/" + filename
	img.save_png(dest)
