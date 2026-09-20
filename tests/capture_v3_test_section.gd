extends SceneTree

const SunZoneData = preload("res://scripts/planet_data.gd")
const SolarBackground = preload("res://scripts/background.gd")
const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")
const SolarHUD = preload("res://scripts/hud.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")

const ARTIFACT_DIR = "C:/Users/aruvi/.gemini/antigravity-ide/brain/f75eeb4b-bf34-4366-b518-afc1bd64e4d0"

func _init() -> void:
	print("=== RUNNING EXPLORE SUN V3 TEST SECTION (PADS 18-22) CAPTURE ===")
	call_deferred("_run_capture")

func _run_capture() -> void:
	var packed = load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate() as SolarMain
	root.add_child(main)
	
	var hud = main.get_node("HUD") as SolarHUD
	var player = main.get_node("Player") as SolarPlayer
	var world_gen = main.get_node("WorldGenerator") as WorldGenerator
	var camera = main.get_node("Camera2D") as SolarCamera
	
	await create_timer(0.4).timeout
	
	# Start game
	hud.emit_signal("play_game_requested")
	while main.current_state != SolarMain.GameState.PLAYING:
		await create_timer(0.05).timeout
	await create_timer(0.3).timeout
	
	# Advance route generation to Pad 23
	while world_gen.next_platform_idx <= 24:
		world_gen.spawn_next_route_pad()
		
	# Place player on Pad 19 (in Solar Valley, facing the Pad 20 milestone and Pad 21 Solar Craters)
	var pad_19 = world_gen.get_platform_by_index(19)
	if pad_19:
		player.spawn_on_platform(pad_19)
		main._on_player_landed(pad_19, false)
		
	# Force camera update to snap smoothly to player & target
	if camera and pad_19:
		camera.global_position = pad_19.global_position + Vector2(0.0, -75.0)
		
	await create_timer(0.8).timeout
	await _capture_screenshot("v3_test_section_pads_18_22.png")
	
	# Simulate flight toward Pad 20
	var pad_20 = world_gen.get_platform_by_index(20)
	if pad_20 and pad_19:
		player.current_state = SolarPlayer.State.FLYING
		player.active_platform = null
		player.last_docked_platform = pad_19
		# Mid-air trajectory between Pad 19 and Pad 20
		player.global_position = pad_19.global_position.lerp(pad_20.global_position, 0.45) + Vector2(0.0, -110.0)
		player.velocity = Vector2(80.0, -40.0)
		if camera:
			camera.global_position = player.global_position + Vector2(30.0, -75.0)
			
	await create_timer(0.5).timeout
	await _capture_screenshot("v3_test_section_in_flight.png")
	
	print("=== V3 TEST SECTION CAPTURE FINISHED ===")
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
