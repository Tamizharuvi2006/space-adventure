extends SceneTree

const SolarMain = preload("res://scripts/main.gd")
const SolarHUD = preload("res://scripts/hud.gd")
const SolarPlayer = preload("res://scripts/player.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")

const ARTIFACT_DIR = "C:/Users/aruvi/.gemini/antigravity-ide/brain/f75eeb4b-bf34-4366-b518-afc1bd64e4d0"

func _init() -> void:
	print("\n=== RUNNING V7.3 PAUSE / MENU ICON CAPTURE ===")
	call_deferred("_run_capture")

func _run_capture() -> void:
	# Clear save file so we start clean
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
	var pause_btn = hud.pause_button
	
	await create_timer(0.3).timeout
	
	# Start game
	hud.emit_signal("play_game_requested")
	while main.current_state != SolarMain.GameState.PLAYING:
		await create_timer(0.05).timeout
	await create_timer(0.3).timeout
	
	# -------------------------------------------------------------------------
	# 1. Normal Gameplay (Calm, understated top-right pause button)
	# -------------------------------------------------------------------------
	await _capture_screenshot("v7_3_normal_gameplay.png")
	print("  📸 Captured Normal Gameplay HUD with clean pause button.")
	
	# -------------------------------------------------------------------------
	# 2. Pressed Pause Button (Scale 0.95, highlight border & brighter icon)
	# -------------------------------------------------------------------------
	pause_btn.scale = Vector2(0.95, 0.95)
	var icon = pause_btn.get_node_or_null("PauseIcon")
	if icon and icon.has_method("set_icon_color"):
		icon.set_icon_color(Color(1.0, 1.0, 1.0, 1.0))
	pause_btn.add_theme_stylebox_override("normal", pause_btn.get_theme_stylebox("pressed"))
	await create_timer(0.15).timeout
	await _capture_screenshot("v7_3_pressed_pause_button.png")
	print("  📸 Captured Pressed Pause Button tactile state.")
	
	# Restore normal button state
	pause_btn.scale = Vector2(1.0, 1.0)
	if icon and icon.has_method("set_icon_color"):
		icon.set_icon_color(Color(0.92, 0.95, 0.98, 0.90))
	pause_btn.remove_theme_stylebox_override("normal")
	await create_timer(0.1).timeout
	
	# -------------------------------------------------------------------------
	# 3. Pause Menu (Menu open over gameplay)
	# -------------------------------------------------------------------------
	hud.show_pause_menu()
	await create_timer(0.25).timeout
	await _capture_screenshot("v7_3_pause_menu.png")
	print("  📸 Captured Pause Menu.")
	
	print("\n=== V7.3 PAUSE / MENU ICON CAPTURE COMPLETE ===")
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
