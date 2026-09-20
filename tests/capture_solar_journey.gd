extends SceneTree

const SunZoneData = preload("res://scripts/planet_data.gd")
const SolarBackground = preload("res://scripts/background.gd")
const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")
const SolarHUD = preload("res://scripts/hud.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")

const ARTIFACT_DIR = "C:/Users/aruvi/.gemini/antigravity-ide/brain/f75eeb4b-bf34-4366-b518-afc1bd64e4d0"

func _init() -> void:
	print("=== RUNNING EXPLORE SUN V2 VISUAL SHOWCASE CAPTURE ===")
	call_deferred("_run_capture")

func _run_capture() -> void:
	var packed = load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate() as SolarMain
	root.add_child(main)
	
	var hud = main.get_node("HUD") as SolarHUD
	var player = main.get_node("Player") as SolarPlayer
	var world_gen = main.get_node("WorldGenerator") as WorldGenerator
	var bg = main.get_node("Background") as SolarBackground
	
	await create_timer(0.4).timeout
	
	# Start game
	hud.emit_signal("play_game_requested")
	while main.current_state != SolarMain.GameState.PLAYING:
		await create_timer(0.05).timeout
	await create_timer(0.3).timeout
	
	# 1. Capture Zone 0: Solar Valley (Baseline Start)
	await _capture_screenshot("v2_zone0_solar_valley.png")
	
	# 2. Advance to Zone 1: Solar Craters (Pad 21)
	while world_gen.next_platform_idx <= 25:
		world_gen.spawn_next_route_pad()
	var pad_21 = world_gen.get_platform_by_index(21)
	if pad_21:
		player.spawn_on_platform(pad_21)
		main._on_player_landed(pad_21, true)
	await create_timer(0.6).timeout
	await _capture_screenshot("v2_zone1_solar_craters.png")
	
	# 3. Advance to Zone 2: Solar Mountains (Pad 41)
	while world_gen.next_platform_idx <= 45:
		world_gen.spawn_next_route_pad()
	var pad_41 = world_gen.get_platform_by_index(41)
	if pad_41:
		player.spawn_on_platform(pad_41)
		main._on_player_landed(pad_41, true)
	await create_timer(0.6).timeout
	await _capture_screenshot("v2_zone2_solar_mountains.png")
	
	# 4. Advance to Zone 4: Solar Core (Pad 81)
	while world_gen.next_platform_idx <= 85:
		world_gen.spawn_next_route_pad()
	var pad_81 = world_gen.get_platform_by_index(81)
	if pad_81:
		player.spawn_on_platform(pad_81)
		main._on_player_landed(pad_81, true)
	await create_timer(0.8).timeout
	await _capture_screenshot("v2_zone4_solar_core.png")
	
	# Brief wait for banner settling
	await create_timer(1.0).timeout
	
	# 5. Advance to Pad 100 (Sun Journey Complete)
	while world_gen.next_platform_idx <= 101:
		world_gen.spawn_next_route_pad()
	var pad_100 = world_gen.get_platform_by_index(100)
	if pad_100:
		player.spawn_on_platform(pad_100)
		main._on_player_landed(pad_100, true)
	await create_timer(0.6).timeout
	await _capture_screenshot("v2_pad100_completion.png")
	
	print("=== EXPLORE SUN V2 SHOWCASE CAPTURE COMPLETE ===")
	quit(0)

func _capture_screenshot(filename: String) -> void:
	await create_timer(0.1).timeout
	var vp = root.get_viewport()
	if vp:
		var tex = vp.get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				var path = ARTIFACT_DIR + "/" + filename
				var err = img.save_png(path)
				print("  📸 Saved screenshot %s (res=%d)" % [filename, err])
