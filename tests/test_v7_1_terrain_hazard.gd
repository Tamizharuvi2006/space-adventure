extends SceneTree

const SunZoneData = preload("res://scripts/planet_data.gd")
const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")
const SolarPlatform = preload("res://scripts/platform.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")
const SolarTerrainGenerator = preload("res://scripts/terrain_generator.gd")

var current_main: SolarMain = null

func _init() -> void:
	print("\n=======================================================")
	print("   TEST V7.1: TERRAIN HAZARD & INSTANT CRASH SUITE    ")
	print("=======================================================\n")
	call_deferred("_run_all_tests")

func _spawn_fresh_game_instance() -> SolarMain:
	Engine.time_scale = 1.0
	if is_instance_valid(current_main):
		root.remove_child(current_main)
		current_main.queue_free()
		current_main = null
		
	var packed = load("res://scenes/main.tscn") as PackedScene
	var inst = packed.instantiate() as SolarMain
	root.add_child(inst)
	current_main = inst
	return inst

func _run_all_tests() -> void:
	# -------------------------------------------------------------------------
	# SETUP CHECK: Verify Terrain Hazard Colliders Exist
	# -------------------------------------------------------------------------
	var game = _spawn_fresh_game_instance()
	await process_frame
	await process_frame
	
	var world_gen = game.world_gen
	var pad_0 = world_gen.get_platform_by_index(0)
	var pad_1 = world_gen.get_platform_by_index(1)
	assert(is_instance_valid(pad_0), "Pad 0 must exist!")
	assert(is_instance_valid(pad_1), "Pad 1 must exist!")
	
	var terrain_gen = world_gen.terrain_gen
	assert(is_instance_valid(terrain_gen), "Terrain generator must exist!")
	assert(terrain_gen.active_chunks.size() > 0, "Terrain generator must have active chunks!")
	
	var found_hazard = false
	for chunk_key in terrain_gen.active_chunks.keys():
		var chunk = terrain_gen.active_chunks[chunk_key]
		var hazard = chunk.get_node_or_null("TerrainHazard")
		if hazard and hazard is StaticBody2D:
			var col = hazard.get_node_or_null("TerrainCollision")
			if col and col is CollisionPolygon2D and col.polygon.size() > 2:
				found_hazard = true
				break
	assert(found_hazard, "Active chunks must contain TerrainHazard StaticBody2D with CollisionPolygon2D!")
	print("  Setup check: Terrain hazard collision shapes verified.")

	# -------------------------------------------------------------------------
	# TEST D: Landing Pad Deck Precedence (Safe Landing)
	# -------------------------------------------------------------------------
	print("\n--- TEST D: Land directly on valid pad deck -> Safe Landing ---")
	game = _spawn_fresh_game_instance()
	await process_frame
	await process_frame
	var player = game.player
	pad_1 = game.world_gen.get_platform_by_index(1)
	
	player.current_state = SolarPlayer.State.FLYING
	player.active_platform = null
	player.last_docked_platform = null
	player.launch_grace_timer = 0.0
	player.global_position = pad_1.global_position + Vector2(0.0, -80.0)
	player.velocity = Vector2(0.0, 70.0)
	player.rotation = 0.0
	
	var landed = false
	for _f in range(60):
		await physics_frame
		if player.current_state == SolarPlayer.State.ON_PAD:
			landed = true
			break
			
	assert(landed, "Player must land safely on platform deck inside tolerances!")
	assert(player.current_state == SolarPlayer.State.ON_PAD, "State must be ON_PAD!")
	print("  ✅ TEST D PASSED: Valid landing pad deck touchdown confirmed safe (State: ON_PAD).")

	# -------------------------------------------------------------------------
	# TEST A: Fly intentionally into left cliff -> Immediate Death
	# -------------------------------------------------------------------------
	print("\n--- TEST A: Fly intentionally into left cliff -> Immediate Death ---")
	game = _spawn_fresh_game_instance()
	await process_frame
	await process_frame
	player = game.player
	pad_0 = game.world_gen.get_platform_by_index(0)
	
	player.current_state = SolarPlayer.State.FLYING
	player.active_platform = null
	player.last_docked_platform = pad_0
	player.launch_grace_timer = 0.25 # Even during launch grace timer!
	var start_footing_y = pad_0.global_position.y + 74.0
	player.global_position = Vector2(pad_0.global_position.x - 120.0, start_footing_y + 20.0)
	player.velocity = Vector2(-250.0, 0.0)
	
	var died_left_cliff = false
	for _f in range(30):
		await physics_frame
		if player.current_state == SolarPlayer.State.CRASHED:
			died_left_cliff = true
			break
			
	assert(died_left_cliff, "Flying into cliff face must cause immediate death even during launch grace timer!")
	assert(player.velocity == Vector2.ZERO, "Velocity must be immediately zeroed upon terrain impact!")
	print("  ✅ TEST A PASSED: Left cliff impact caused immediate death with zeroed velocity.")

	# -------------------------------------------------------------------------
	# TEST B: Fly into mountain face -> Immediate Death
	# -------------------------------------------------------------------------
	print("\n--- TEST B: Fly into mountain face -> Immediate Death ---")
	game = _spawn_fresh_game_instance()
	await process_frame
	await process_frame
	player = game.player
	pad_1 = game.world_gen.get_platform_by_index(1)
	
	var pad_1_footing_y = pad_1.global_position.y + 74.0
	player.current_state = SolarPlayer.State.FLYING
	player.active_platform = null
	player.last_docked_platform = null
	player.launch_grace_timer = 0.0
	player.global_position = Vector2(pad_1.global_position.x - pad_1.current_width * 0.5 - 30.0, pad_1_footing_y + 10.0)
	player.velocity = Vector2(200.0, 0.0)
	
	var died_mountain = false
	for _f in range(30):
		await physics_frame
		if player.current_state == SolarPlayer.State.CRASHED:
			died_mountain = true
			break
			
	assert(died_mountain, "Flying into mountain/rock face must cause immediate death!")
	print("  ✅ TEST B PASSED: Mountain face contact caused immediate crash death.")

	# -------------------------------------------------------------------------
	# TEST C: Descend onto terrain beside a pad -> Death (Not a walkable floor)
	# -------------------------------------------------------------------------
	print("\n--- TEST C: Descend onto terrain beside a pad -> Death ---")
	game = _spawn_fresh_game_instance()
	await process_frame
	await process_frame
	player = game.player
	pad_1 = game.world_gen.get_platform_by_index(1)
	
	# Drop vertically beside pad 1 (to the left of pad 1, onto canyon rock slope)
	var pad_1_footing_y_c = pad_1.global_position.y + 74.0
	var beside_pad_1_x = pad_1.global_position.x - (pad_1.current_width * 0.5 + 40.0)
	
	player.current_state = SolarPlayer.State.FLYING
	player.active_platform = null
	player.last_docked_platform = null
	player.launch_grace_timer = 0.0
	player.global_position = Vector2(beside_pad_1_x, pad_1_footing_y_c - 40.0)
	player.velocity = Vector2(0.0, 160.0)
	
	var died_beside_pad = false
	for _f in range(40):
		await physics_frame
		if player.current_state == SolarPlayer.State.CRASHED:
			died_beside_pad = true
			break
			
	assert(died_beside_pad, "Descending onto rock beside pad must trigger instant death (terrain is not walkable)!")
	print("  ✅ TEST C PASSED: Terrain beside pad confirmed deadly environmental obstacle.")

	# -------------------------------------------------------------------------
	# TEST E: Fall through open canyon air -> Remain airborne until abyss boundary
	# -------------------------------------------------------------------------
	print("\n--- TEST E: Fall through open canyon air -> Airborne until abyss boundary ---")
	game = _spawn_fresh_game_instance()
	await process_frame
	await process_frame
	player = game.player
	pad_0 = game.world_gen.get_platform_by_index(0)
	pad_1 = game.world_gen.get_platform_by_index(1)
	
	var mid_x = (pad_0.global_position.x + pad_1.global_position.x) * 0.5
	var air_y = pad_0.global_position.y - 40.0 # High open canyon airspace
	player.current_state = SolarPlayer.State.FLYING
	player.active_platform = null
	player.last_docked_platform = pad_0
	player.launch_grace_timer = 0.0
	player.global_position = Vector2(mid_x, air_y)
	player.velocity = Vector2(50.0, 30.0)
	
	var died_in_air = false
	for _f in range(15):
		await physics_frame
		if player.current_state == SolarPlayer.State.CRASHED:
			died_in_air = true
			break
			
	assert(not died_in_air, "Open canyon air must remain completely flyable without premature death!")
	print("  ✅ TEST E PASSED: Open canyon airspace is empty and flyable.")

	# -------------------------------------------------------------------------
	# TEST F: Never allow player to appear visually underneath terrain
	# -------------------------------------------------------------------------
	print("\n--- TEST F: Never allow player to appear visually underneath terrain ---")
	game = _spawn_fresh_game_instance()
	await process_frame
	await process_frame
	player = game.player
	pad_1 = game.world_gen.get_platform_by_index(1)
	pad_1_footing_y = pad_1.global_position.y + 74.0
	
	# Drop vertically onto the rock slope to the left of pad 1
	var drop_x = pad_1.global_position.x - (pad_1.current_width * 0.5 + 25.0)
	player.current_state = SolarPlayer.State.FLYING
	player.active_platform = null
	player.last_docked_platform = pad_1
	player.launch_grace_timer = 0.0
	player.global_position = Vector2(drop_x, pad_1_footing_y - 50.0)
	player.velocity = Vector2(0.0, 200.0)
	
	# Fall into terrain
	var hit_terrain = false
	for _f in range(30):
		await physics_frame
		if player.current_state == SolarPlayer.State.CRASHED:
			hit_terrain = true
			break
			
	assert(hit_terrain, "Player must crash upon reaching terrain surface!")
	var impact_pos = player.global_position
	# Player must hit and stop on or above the rock footing (never sink beneath)
	assert(impact_pos.y <= pad_1_footing_y + 15.0, "Player must not sink beneath visible terrain surface!")
	assert(player.velocity == Vector2.ZERO, "Velocity must stay zeroed at impact!")
	
	# For the next 8 frames of the slow-motion burst, player must remain completely frozen at impact point
	for _f in range(8):
		await physics_frame
		assert(player.global_position.distance_to(impact_pos) < 0.1, "Player must remain frozen at impact position during death burst!")
		
	print("  ✅ TEST F PASSED: Player stops at terrain surface and never penetrates or sinks underneath.")

	print("\n=======================================================")
	print("   ALL 6 TERRAIN HAZARD TESTS (A–F) PASSED! 🎉        ")
	print("=======================================================\n")
	quit(0)
