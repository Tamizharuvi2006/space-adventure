extends SceneTree

# Explore Sun V4 — Visual Capture Script
# Captures 5 key moments from Pads 18-22 to verify the "travelling planet" composition

const SunZoneData = preload("res://scripts/planet_data.gd")

var main_scene: Node = null
var player: Node = null
var world_gen: Node = null
var camera: Node = null
var frames_waited: int = 0
var capture_phase: int = 0

func _init() -> void:
	print("=== V4 VISUAL CAPTURE — PADS 18-22 ===")
	call_deferred("_setup")

func _setup() -> void:
	var packed = load("res://scenes/main.tscn") as PackedScene
	main_scene = packed.instantiate()
	root.add_child(main_scene)

	player = main_scene.get_node("Player")
	world_gen = main_scene.get_node("WorldGenerator")
	camera = main_scene.get_node("Camera2D")

	await process_frame
	await process_frame
	await process_frame

	# Start game
	main_scene.get_node("HUD").emit_signal("play_game_requested")
	while main_scene.current_state != main_scene.GameState.PLAYING:
		await process_frame

	# Spawn all pads up through 25
	while world_gen.next_platform_idx < 28:
		world_gen.spawn_next_route_pad()

	# Simulate landing on pads 1-18 to advance to Pad 18 as current
	for i in range(1, 19):
		var p = world_gen.get_platform_by_index(i)
		if p:
			main_scene._on_player_landed(p, true)
			await process_frame

	await process_frame
	await process_frame

	# ─── PHASE A: Player docked on Pad 18, looking toward Pad 19 ─────────────
	print("\n[CAPTURE A] Player on Pad 18, Pad 19 visible as next target...")
	var pad18 = world_gen.get_platform_by_index(18)
	if pad18:
		player.spawn_on_platform(pad18)
		world_gen.update_route_visuals(18)
		camera.global_position = pad18.global_position + Vector2(160.0, -75.0)

	# Run world terrain streaming a few frames so chunks are placed
	for _f in range(8):
		world_gen.update_terrain_streaming(camera.global_position.x)
		await process_frame

	_capture_screenshot("v4_a_docked_pad18.png")
	await process_frame

	# ─── PHASE B: Player mid-air flying from Pad 19 toward Pad 20 canyon ─────
	print("\n[CAPTURE B] Player mid-air approaching canyon crossing to Pad 20...")
	var pad19 = world_gen.get_platform_by_index(19)
	var pad20 = world_gen.get_platform_by_index(20)
	if pad19 and pad20:
		main_scene._on_player_landed(pad19, true)
		await process_frame
		player.spawn_on_platform(pad19)
		player.current_state = player.State.FLYING
		player.velocity = Vector2(280.0, -160.0)
		# Place player mid-jump over the chasm
		player.global_position = Vector2(
			pad19.global_position.x + 220.0,
			pad19.global_position.y - 95.0
		)
		camera.global_position = player.global_position + Vector2(160.0, -60.0)
		world_gen.update_terrain_streaming(camera.global_position.x)

	for _f in range(5):
		world_gen.update_terrain_streaming(camera.global_position.x)
		await process_frame

	_capture_screenshot("v4_b_inflight_canyon.png")
	await process_frame

	# ─── PHASE C: Player approaching Pad 20 — close final approach ────────────
	print("\n[CAPTURE C] Player on close approach to Pad 20 cliff station...")
	if pad20:
		player.global_position = Vector2(
			pad20.global_position.x - 80.0,
			pad20.global_position.y - 30.0
		)
		player.velocity = Vector2(180.0, 60.0)
		camera.global_position = player.global_position + Vector2(80.0, -70.0)
		world_gen.update_terrain_streaming(camera.global_position.x)

	for _f in range(4):
		world_gen.update_terrain_streaming(camera.global_position.x)
		await process_frame

	_capture_screenshot("v4_c_approach_pad20.png")
	await process_frame

	# ─── PHASE D: Player safely landed on Pad 20, Pad 21 summit visible ───────
	print("\n[CAPTURE D] Player landed on Pad 20, beacon shifts to Pad 21 summit...")
	if pad20:
		main_scene._on_player_landed(pad20, true)
		await process_frame
		player.spawn_on_platform(pad20)
		world_gen.update_route_visuals(20)
		camera.global_position = pad20.global_position + Vector2(120.0, -85.0)
		world_gen.update_terrain_streaming(camera.global_position.x)

	for _f in range(6):
		world_gen.update_terrain_streaming(camera.global_position.x)
		await process_frame

	_capture_screenshot("v4_d_landed_pad20.png")
	await process_frame

	# ─── PHASE E: Summit climb — player flying up toward Pad 21 ──────────────
	print("\n[CAPTURE E] Player ascending toward Pad 21 high summit...")
	var pad21 = world_gen.get_platform_by_index(21)
	if pad21 and pad20:
		player.current_state = player.State.FLYING
		player.velocity = Vector2(200.0, -280.0)
		player.global_position = Vector2(
			pad20.global_position.x + 150.0,
			pad20.global_position.y - 80.0
		)
		camera.global_position = player.global_position + Vector2(100.0, -100.0)
		world_gen.update_terrain_streaming(camera.global_position.x)

	for _f in range(5):
		world_gen.update_terrain_streaming(camera.global_position.x)
		await process_frame

	_capture_screenshot("v4_e_summit_climb.png")

	print("\n=== V4 CAPTURE COMPLETE ===")
	print("Screenshots saved to res://tests/")
	quit(0)

func _capture_screenshot(filename: String) -> void:
	var path = "res://tests/" + filename
	var img = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png(path)
		print("  📷 Saved: %s" % path)
	else:
		print("  ⚠️  Could not capture screenshot for %s" % filename)
