extends SceneTree

const SunZoneData = preload("res://scripts/planet_data.gd")
const SolarBackground = preload("res://scripts/background.gd")
const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")
const SolarHUD = preload("res://scripts/hud.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")

const ARTIFACT_DIR = "C:/Users/aruvi/.gemini/antigravity-ide/brain/f75eeb4b-bf34-4366-b518-afc1bd64e4d0"

func _init() -> void:
	print("=== RUNNING EXPLORE SUN V5.4 100-PAD MACRO SHOWCASE CAPTURE ===")
	call_deferred("_run_capture")

func _run_capture() -> void:
	var packed = load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate() as SolarMain
	root.add_child(main)
	
	var hud = main.get_node("HUD") as SolarHUD
	var player = main.get_node("Player") as SolarPlayer
	var world_gen = main.get_node("WorldGenerator") as WorldGenerator
	var bg = main.get_node("Background") as SolarBackground
	var camera = main.get_node("Camera2D") as Camera2D
	
	await create_timer(0.3).timeout
	
	hud.emit_signal("play_game_requested")
	while main.current_state != SolarMain.GameState.PLAYING:
		await create_timer(0.05).timeout
	await create_timer(0.2).timeout
	
	var sample_pads = [1, 10, 20, 30, 40, 48, 60, 70, 80, 85, 100]
	var max_pad = 100
	
	# Spawn all route pads up to 100
	print("Pre-spawning all 100 pads for macro photography...")
	while world_gen.next_platform_idx <= max_pad:
		world_gen.spawn_next_route_pad()
	
	for pad_idx in sample_pads:
		var pad = world_gen.get_platform_by_index(pad_idx)
		if pad == null:
			print("Warning: Pad %d not found!" % pad_idx)
			continue
		
		var zone_idx = SunZoneData.get_zone_index(pad_idx)
		var zone = SunZoneData.ZONES[zone_idx]
		
		# Set player and camera to pad
		player.spawn_on_platform(pad)
		main.current_pad = pad_idx
		world_gen.update_route_visuals(pad_idx)
		camera.global_position = pad.global_position + Vector2(160.0, -40.0)
		world_gen.update_terrain_streaming(camera.global_position.x)
		bg.apply_zone_visuals_instant(zone)
		
		await create_timer(0.35).timeout
		var filename = "v5_4_macro_pad_%03d_%s.png" % [pad_idx, zone.name.to_lower().replace(" ", "_")]
		await _capture_screenshot(filename)
		print("Captured: %s at Pos=(%.1f, %.1f)" % [filename, pad.global_position.x, pad.global_position.y])
	
	print("=== ALL V5.4 MACRO SCREENSHOTS CAPTURED SUCCESSFULLY ===")
	quit()

func _capture_screenshot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img = root.get_viewport().get_texture().get_image()
	var dest_path = ARTIFACT_DIR + "/" + filename
	img.save_png(dest_path)
