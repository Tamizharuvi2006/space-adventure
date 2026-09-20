extends SceneTree

const SunZoneData = preload("res://scripts/planet_data.gd")
const SolarBackground = preload("res://scripts/background.gd")
const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")
const SolarHUD = preload("res://scripts/hud.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")

const ARTIFACT_DIR = "C:/Users/aruvi/.gemini/antigravity-ide/brain/f75eeb4b-bf34-4366-b518-afc1bd64e4d0"

func _init() -> void:
	print("=== RUNNING EXPLORE SUN V5 OPEN-WORLD SHOWCASE CAPTURE ===")
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
	
	# Start game
	hud.emit_signal("play_game_requested")
	while main.current_state != SolarMain.GameState.PLAYING:
		await create_timer(0.05).timeout
	await create_timer(0.2).timeout
	
	# Spawn pads up to 25 so Pads 18..22 exist in route
	while world_gen.next_platform_idx <= 25:
		world_gen.spawn_next_route_pad()
	
	var pad_18 = world_gen.get_platform_by_index(18)
	var pad_19 = world_gen.get_platform_by_index(19)
	var pad_20 = world_gen.get_platform_by_index(20)
	var pad_21 = world_gen.get_platform_by_index(21)
	var pad_22 = world_gen.get_platform_by_index(22)
	
	assert(pad_19 != null and pad_20 != null, "Pad 19 and 20 must exist!")
	
	# ──────────────────────────────────────────────────────────────────────────
	# STAGE A: Resting on Pad 19 (Cliff Shelf)
	# ──────────────────────────────────────────────────────────────────────────
	player.spawn_on_platform(pad_19)
	main._on_player_landed(pad_19, true)
	world_gen.update_route_visuals(19)
	camera.global_position = pad_19.global_position + Vector2(180.0, -50.0)
	world_gen.update_terrain_streaming(camera.global_position.x)
	await create_timer(0.5).timeout
	await _capture_screenshot("v5_a_resting_pad19.png")
	
	# ──────────────────────────────────────────────────────────────────────────
	# STAGE B: Takeoff from Pad 19
	# ──────────────────────────────────────────────────────────────────────────
	player.current_state = SolarPlayer.State.FLYING
	player.global_position = pad_19.global_position + Vector2(70.0, -110.0)
	player.velocity = Vector2(190.0, -140.0)
	player.rotation = deg_to_rad(14.0)
	camera.global_position = player.global_position + Vector2(160.0, -30.0)
	world_gen.update_terrain_streaming(camera.global_position.x)
	
	var left_jet = player.get_node_or_null("LeftJet") as CPUParticles2D
	var right_jet = player.get_node_or_null("RightJet") as CPUParticles2D
	if left_jet: left_jet.emitting = true
	if right_jet: right_jet.emitting = true
	await create_timer(0.4).timeout
	await _capture_screenshot("v5_b_takeoff_pad19.png")
	
	# ──────────────────────────────────────────────────────────────────────────
	# STAGE C: Mid-flight across the vast Canyon Chasm
	# ──────────────────────────────────────────────────────────────────────────
	var mid_x = pad_19.global_position.x + (pad_20.global_position.x - pad_19.global_position.x) * 0.48
	var mid_y = minf(pad_19.global_position.y, pad_20.global_position.y) - 160.0
	player.global_position = Vector2(mid_x, mid_y)
	player.velocity = Vector2(310.0, -10.0)
	player.rotation = deg_to_rad(8.0)
	camera.global_position = player.global_position + Vector2(120.0, -10.0)
	world_gen.update_terrain_streaming(camera.global_position.x)
	if left_jet: left_jet.emitting = true
	if right_jet: right_jet.emitting = true
	await create_timer(0.4).timeout
	await _capture_screenshot("v5_c_midflight_canyon.png")
	
	# ──────────────────────────────────────────────────────────────────────────
	# STAGE D: Approaching Pad 20 (Mesa Plateau)
	# ──────────────────────────────────────────────────────────────────────────
	var app_x = pad_20.global_position.x - 140.0
	var app_y = pad_20.global_position.y - 120.0
	player.global_position = Vector2(app_x, app_y)
	player.velocity = Vector2(160.0, 90.0)
	player.rotation = deg_to_rad(-6.0)
	camera.global_position = pad_20.global_position + Vector2(-60.0, -40.0)
	world_gen.update_terrain_streaming(camera.global_position.x)
	if left_jet: left_jet.emitting = true
	if right_jet: right_jet.emitting = true
	await create_timer(0.4).timeout
	await _capture_screenshot("v5_d_approaching_pad20.png")
	
	# ──────────────────────────────────────────────────────────────────────────
	# STAGE E: Landed on Pad 20 (Mesa Plateau)
	# ──────────────────────────────────────────────────────────────────────────
	player.spawn_on_platform(pad_20)
	main._on_player_landed(pad_20, true)
	world_gen.update_route_visuals(20)
	camera.global_position = pad_20.global_position + Vector2(140.0, -50.0)
	world_gen.update_terrain_streaming(camera.global_position.x)
	if left_jet: left_jet.emitting = false
	if right_jet: right_jet.emitting = false
	await create_timer(0.5).timeout
	await _capture_screenshot("v5_e_landed_pad20.png")

	print("=== EXPLORE SUN V5 OPEN-WORLD SHOWCASE COMPLETE ===")
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
				print("  📸 Saved screenshot %s (err=%d)" % [filename, err])
