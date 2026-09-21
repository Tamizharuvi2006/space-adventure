extends SceneTree

const SolarMain = preload("res://scripts/main.gd")
const SolarHUD = preload("res://scripts/hud.gd")
const SolarPlayer = preload("res://scripts/player.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")

const ARTIFACT_DIR = "C:/Users/aruvi/.gemini/antigravity-ide/brain/f75eeb4b-bf34-4366-b518-afc1bd64e4d0"

func _init() -> void:
	print("\n=== RUNNING V7.4 PLANETARY LANDER & DESCENT CAMERA CAPTURE ===")
	call_deferred("_run_capture")

func _run_capture() -> void:
	var save_path = "user://explore_sun_save.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	var packed = load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate() as SolarMain
	root.add_child(main)
	
	var hud = main.get_node("HUD") as SolarHUD
	var player = main.get_node("Player") as SolarPlayer
	var world_gen = main.get_node("WorldGenerator") as WorldGenerator
	var camera = main.get_node("Camera2D") as Camera2D
	
	await create_timer(0.3).timeout
	
	# Start game
	hud.emit_signal("play_game_requested")
	while main.current_state != SolarMain.GameState.PLAYING:
		await create_timer(0.05).timeout
	await create_timer(0.4).timeout
	
	var pad_1 = world_gen.get_platform_by_index(1)
	var pad_2 = world_gen.get_platform_by_index(2)
	
	# -------------------------------------------------------------------------
	# 1. Docked Planetary Explorer Lander
	# -------------------------------------------------------------------------
	player.spawn_on_platform(pad_1)
	main._on_player_landed(pad_1, true)
	camera.snap_to_target()
	await create_timer(0.5).timeout
	await _capture_screenshot("v7_4_explorer_lander_docked.png")
	print("  📸 Captured Docked Planetary Explorer Lander on Pad 1.")
	
	# -------------------------------------------------------------------------
	# 2. High Ascent (Wide Mars-style Sky, Minimal Vertical Chasing)
	# -------------------------------------------------------------------------
	player.global_position.y -= 120.0
	player.global_position.x += 160.0
	player.current_state = SolarPlayer.State.FLYING
	player.launch_grace_timer = 1.0
	player.velocity = Vector2(100.0, -260.0)
	var left_jet = player.get_node_or_null("LeftJet")
	var right_jet = player.get_node_or_null("RightJet")
	if left_jet: left_jet.emitting = true
	if right_jet: right_jet.emitting = true
	await create_timer(0.35).timeout
	await _capture_screenshot("v7_4_high_ascent.png")
	print("  📸 Captured High Ascent with Wide Sky Framing.")
	
	# -------------------------------------------------------------------------
	# 3. Descent Look-Ahead (Revealing Lower Terrain & Upcoming Pad)
	# -------------------------------------------------------------------------
	player.global_position = (pad_1.global_position + pad_2.global_position) * 0.5 + Vector2(0.0, -180.0)
	player.velocity = Vector2(120.0, 320.0) # Falling towards Pad 2
	camera.set_next_target_platform(pad_2)
	await create_timer(0.4).timeout
	await _capture_screenshot("v7_4_descent_lookahead.png")
	print("  📸 Captured Descent Look-Ahead revealing lower terrain & Pad 2.")
	
	if left_jet: left_jet.emitting = false
	if right_jet: right_jet.emitting = false
	
	print("\n=== V7.4 CAPTURE COMPLETE ===")
	quit(0)

func _capture_screenshot(filename: String) -> void:
	await create_timer(0.15).timeout
	var vp = root.get_viewport()
	if vp:
		var tex = vp.get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				var path = ARTIFACT_DIR + "/" + filename
				var err = img.save_png(path)
				print("  Saved %s (err=%d)" % [filename, err])
