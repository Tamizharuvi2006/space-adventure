extends SceneTree

const SunZoneData = preload("res://scripts/planet_data.gd")
const SolarBackground = preload("res://scripts/background.gd")
const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")
const SolarHUD = preload("res://scripts/hud.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")

const ARTIFACT_DIR = "C:/Users/aruvi/.gemini/antigravity-ide/brain/f75eeb4b-bf34-4366-b518-afc1bd64e4d0"

func _init() -> void:
	print("=== RUNNING EXPLORE SUN V4.2 TEST SECTION SHOWCASE CAPTURE ===")
	call_deferred("_run_capture")

func _run_capture() -> void:
	var packed = load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate() as SolarMain
	root.add_child(main)
	
	var hud = main.get_node("HUD") as SolarHUD
	var player = main.get_node("Player") as SolarPlayer
	var world_gen = main.get_node("WorldGenerator") as WorldGenerator
	var bg = main.get_node("Background") as SolarBackground
	
	await create_timer(0.3).timeout
	
	# Start game
	hud.emit_signal("play_game_requested")
	while main.current_state != SolarMain.GameState.PLAYING:
		await create_timer(0.05).timeout
	await create_timer(0.2).timeout
	
	# Pre-generate pads up to 25 so Pads 18, 19, 20, 21, 22 are all active in the world
	while world_gen.next_platform_idx <= 25:
		world_gen.spawn_next_route_pad()
	
	var pad_18 = world_gen.get_platform_by_index(18)
	var pad_19 = world_gen.get_platform_by_index(19)
	var pad_20 = world_gen.get_platform_by_index(20)
	var pad_21 = world_gen.get_platform_by_index(21)
	var pad_22 = world_gen.get_platform_by_index(22)
	
	# ──────────────────────────────────────────────────────────────────────────
	# SHOT A: Player landed on Pad 19 (Cliff Shelf)
	# ──────────────────────────────────────────────────────────────────────────
	if pad_19:
		player.spawn_on_platform(pad_19)
		main._on_player_landed(pad_19, true)
		main.camera.global_position = pad_19.global_position + Vector2(60.0, -40.0)
		world_gen.update_terrain_streaming(pad_19.global_position.x)
	await create_timer(0.5).timeout
	await _capture_screenshot("v4_2_a_pad19_cliff_shelf.png")
	
	# ──────────────────────────────────────────────────────────────────────────
	# SHOT B: Player flying from 19 → 20 across the deep canyon chasm
	# ──────────────────────────────────────────────────────────────────────────
	if pad_19 and pad_20:
		player.current_state = SolarPlayer.State.FLYING
		var mid_x = (pad_19.global_position.x + pad_20.global_position.x) * 0.5
		var mid_y = minf(pad_19.global_position.y, pad_20.global_position.y) - 95.0
		player.global_position = Vector2(mid_x, mid_y)
		player.velocity = Vector2(260.0, -30.0)
		player.rotation = deg_to_rad(12.0)
		main.camera.global_position = player.global_position + Vector2(40.0, -20.0)
		world_gen.update_terrain_streaming(mid_x)
		
		# Show thruster trail
		var left_jet = player.get_node_or_null("LeftJet") as CPUParticles2D
		var right_jet = player.get_node_or_null("RightJet") as CPUParticles2D
		if left_jet: left_jet.emitting = true
		if right_jet: right_jet.emitting = true
	await create_timer(0.4).timeout
	await _capture_screenshot("v4_2_b_flying_19_to_20_chasm.png")
	
	# ──────────────────────────────────────────────────────────────────────────
	# SHOT C: Player landed on Pad 20 (Mesa Plateau)
	# ──────────────────────────────────────────────────────────────────────────
	if pad_20:
		player.spawn_on_platform(pad_20)
		main._on_player_landed(pad_20, true)
		main.camera.global_position = pad_20.global_position + Vector2(60.0, -40.0)
		world_gen.update_terrain_streaming(pad_20.global_position.x)
		
		var left_jet = player.get_node_or_null("LeftJet") as CPUParticles2D
		var right_jet = player.get_node_or_null("RightJet") as CPUParticles2D
		if left_jet: left_jet.emitting = false
		if right_jet: right_jet.emitting = false
	await create_timer(0.5).timeout
	await _capture_screenshot("v4_2_c_pad20_mesa_plateau.png")
	
	# ──────────────────────────────────────────────────────────────────────────
	# SHOT D: Player flying from 20 → 21 (climbing toward Crater Rim)
	# ──────────────────────────────────────────────────────────────────────────
	if pad_20 and pad_21:
		player.current_state = SolarPlayer.State.FLYING
		var mid_x2 = (pad_20.global_position.x + pad_21.global_position.x) * 0.45
		var mid_y2 = (pad_20.global_position.y + pad_21.global_position.y) * 0.5 - 75.0
		player.global_position = Vector2(mid_x2, mid_y2)
		player.velocity = Vector2(240.0, -110.0)
		player.rotation = deg_to_rad(15.0)
		main.camera.global_position = player.global_position + Vector2(50.0, -30.0)
		world_gen.update_terrain_streaming(mid_x2)
		
		var left_jet = player.get_node_or_null("LeftJet") as CPUParticles2D
		var right_jet = player.get_node_or_null("RightJet") as CPUParticles2D
		if left_jet: left_jet.emitting = true
		if right_jet: right_jet.emitting = true
	await create_timer(0.4).timeout
	await _capture_screenshot("v4_2_d_flying_20_to_21_crater_climb.png")

	print("=== EXPLORE SUN V4.2 TEST SECTION SHOWCASE COMPLETE ===")
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
				print("  📸 Saved screenshot %s (code=%d)" % [filename, err])
