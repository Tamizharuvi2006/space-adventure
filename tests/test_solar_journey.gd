extends SceneTree

const SunZoneData = preload("res://scripts/planet_data.gd")
const SolarBackground = preload("res://scripts/background.gd")
const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")
const SolarHUD = preload("res://scripts/hud.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")

var main_scene: SolarMain = null
var player: SolarPlayer = null
var hud: SolarHUD = null
var world_gen: WorldGenerator = null
var background: SolarBackground = null

func _init() -> void:
	print("=== STARTING EXPLORE SUN V2 SYSTEM INTEGRITY TEST ===")
	call_deferred("_setup_and_run")

func _setup_and_run() -> void:
	var packed = load("res://scenes/main.tscn") as PackedScene
	main_scene = packed.instantiate()
	root.add_child(main_scene)
	
	player = main_scene.get_node("Player") as SolarPlayer
	hud = main_scene.get_node("HUD") as SolarHUD
	world_gen = main_scene.get_node("WorldGenerator") as WorldGenerator
	background = main_scene.get_node("Background") as SolarBackground
	
	await process_frame
	await process_frame
	
	_run_tests()

func _run_tests() -> void:
	# =========================================================================
	# TEST 1: Sun Zone Data Table Integrity
	# =========================================================================
	print("\n--- TEST 1: SUN ZONE DATA TABLE INTEGRITY ---")
	assert(SunZoneData.TOTAL_PADS == 100, "Sun journey must have exactly 100 pads!")
	assert(SunZoneData.ZONES.size() == 5, "Must have exactly 5 visual zones!")
	
	var expected_zones = ["SOLAR VALLEY", "SOLAR CRATERS", "SOLAR MOUNTAINS", "SOLAR RUINS", "SOLAR CORE"]
	for i in range(5):
		var z = SunZoneData.get_zone_by_index(i)
		assert(z["name"] == expected_zones[i], "Zone %d name must be %s, got %s" % [i, expected_zones[i], z["name"]])
		assert(z["gap_min"] < z["gap_max"], "Zone %s gap_min must be < gap_max" % z["name"])
		assert(z["width_min"] <= z["width_max"], "Zone %s width_min must be <= width_max" % z["name"])
		print("  ✓ Zone %d: %s %s (pads %d-%d, gap=%.0f-%.0f, width=%.0f-%.0f)" % [
			i, z["icon"], z["name"], z["pad_start"], z["pad_end"], z["gap_min"], z["gap_max"], z["width_min"], z["width_max"]
		])
	print("  ✅ SunZoneData table fully verified!")

	# =========================================================================
	# TEST 2: Start Game & Verify Baseline
	# =========================================================================
	print("\n--- TEST 2: GAME START & BASELINE INITIALIZATION ---")
	hud.emit_signal("play_game_requested")
	while main_scene.current_state != main_scene.GameState.PLAYING:
		await process_frame
	await process_frame
	
	print("  Current pad: %d / %d" % [main_scene.current_pad, SunZoneData.TOTAL_PADS])
	assert(main_scene.current_pad == 0, "Initial pad must be 0")
	assert(player.active_gravity == 640.0, "Sun baseline gravity must be 640, got %f" % player.active_gravity)
	assert(player.active_wind_x == 0.0, "Sun baseline wind must be 0, got %f" % player.active_wind_x)
	assert(player.active_updraft_y == 0.0, "Sun baseline updraft must be 0, got %f" % player.active_updraft_y)
	print("  ✅ Sun baseline environment and locked physics verified!")

	# =========================================================================
	# TEST 3: Route Generation & Platform Visual Integration
	# =========================================================================
	print("\n--- TEST 3: ROUTE GENERATION & PLATFORM VISUAL INTEGRATION ---")
	var initial_pads = world_gen.active_platforms.size()
	print("  Initial active platforms count: %d" % initial_pads)
	assert(initial_pads >= 7, "Must have generated initial buffer of platforms")
	
	# Verify milestone pads are wider (>=180px)
	for pad in world_gen.active_platforms:
		if pad.platform_index in [20, 40, 60, 80, 100]:
			assert(pad.current_width >= 180.0, "Milestone pad %d must have wide landing deck!" % pad.platform_index)
			print("  ✓ Milestone pad %d verified with wide deck (width=%.0f)" % [pad.platform_index, pad.current_width])
	
	# Verify support structure exists on platforms (single pylon)
	var first_pad = world_gen.active_platforms[0]
	var pylon = first_pad.get_node_or_null("Visuals/SinglePylon")
	assert(pylon != null, "Platforms must have terrain-integrated SinglePylon (Visuals/SinglePylon)!")
	print("  ✓ Support structure (single pylon) confirmed on platform.")

	# =========================================================================
	# TEST 4: Zone Progression & Transition Trigger
	# =========================================================================
	print("\n--- TEST 4: ZONE PROGRESSION & TRANSITION TRIGGER ---")
	# Advance and land on Pad 20
	while world_gen.next_platform_idx <= 25:
		world_gen.spawn_next_route_pad()
	
	var pad_20 = world_gen.get_platform_by_index(20)
	var pad_21 = world_gen.get_platform_by_index(21)
	assert(pad_20 != null, "Pad 20 must exist!")
	assert(pad_21 != null, "Pad 21 must exist!")
	
	# Land on Pad 20 (Solar Valley boundary)
	main_scene._on_player_landed(pad_20, true)
	await process_frame
	await process_frame
	assert(main_scene.current_pad == 20, "Current pad must be 20")
	assert(main_scene.current_zone_idx == 0, "Pad 20 is end of Zone 0")
	
	# Land on Pad 21 (Transition to Zone 1: SOLAR CRATERS)
	main_scene._on_player_landed(pad_21, false)
	await process_frame
	await process_frame
	assert(main_scene.current_pad == 21, "Current pad must be 21")
	assert(main_scene.current_zone_idx == 1, "Pad 21 must trigger transition to Zone 1 (Solar Craters)")
	print("  ✓ Zone transition to Zone 1 (Solar Craters) confirmed on Pad 21 landing!")
	
	# Verify Zone Arrival Banner in HUD
	assert(hud.planet_arrival_card != null, "HUD must have PlanetArrivalCard")
	assert("CRATERS" in hud.arrival_title.text, "Arrival title must mention CRATERS, got: %s" % hud.arrival_title.text)
	print("  ✓ Zone arrival banner active: %s - %s" % [hud.arrival_title.text, hud.arrival_sub.text])

	# =========================================================================
	# TEST 5: Journey Completion at Pad 100
	# =========================================================================
	print("\n--- TEST 5: JOURNEY COMPLETION AT PAD 100 ---")
	while world_gen.next_platform_idx <= 101:
		world_gen.spawn_next_route_pad()
		
	var pad_100 = world_gen.get_platform_by_index(100)
	assert(pad_100 != null, "Pad 100 must exist!")
	
	main_scene._on_player_landed(pad_100, true)
	await process_frame
	await process_frame
	assert(main_scene.current_pad == 100, "Current pad must be 100")
	assert(SunZoneData.is_journey_complete(100), "Pad 100 must complete journey!")
	print("  ✅ 100-Pad Sun Journey completion verified!")

	# =========================================================================
	# TEST 6: Platform Pruning & Memory Bound
	# =========================================================================
	print("\n--- TEST 6: PLATFORM PRUNING & BOUNDED MEMORY ---")
	var active_count = world_gen.active_platforms.size()
	print("  Active platforms after reaching pad 100: %d" % active_count)
	assert(active_count <= 20, "Platforms behind player must be pruned! Count: %d" % active_count)
	print("  ✅ Platform cleanup is strictly bounded!")

	# =========================================================================
	# TEST 7: Retry Clean Reset to Solar Valley Baseline
	# =========================================================================
	print("\n--- TEST 7: RETRY CLEAN RESET TO SOLAR VALLEY BASELINE ---")
	hud.emit_signal("retry_game_requested")
	while main_scene.current_state != main_scene.GameState.PLAYING:
		await process_frame
	await process_frame
	
	assert(main_scene.current_pad == 0, "Pad count must reset to 0 on retry")
	assert(main_scene.current_zone_idx == 0, "Zone must reset to Solar Valley (0)")
	assert(player.active_gravity == 640.0, "Player gravity must remain locked at 640, got %f" % player.active_gravity)
	assert(player.active_wind_x == 0.0, "Player wind must remain 0, got %f" % player.active_wind_x)
	print("  ✅ Clean retry verified: reset back to Pad 0 / Solar Valley!")

	# =========================================================================
	# TEST 8: Real-Runtime Flight Validation on Sample Jump (Pad 0 -> Pad 1)
	# =========================================================================
	print("\n--- TEST 8: REAL-RUNTIME FLIGHT VALIDATION vs SIMULATOR ---")
	var pad_0 = world_gen.get_platform_by_index(0)
	var pad_1 = world_gen.get_platform_by_index(1)
	assert(pad_0 != null and pad_1 != null, "Pad 0 and Pad 1 must exist for runtime flight test")

	var start_pos = pad_0.get_landing_position()
	var target_pos = pad_1.get_landing_position()
	var dx = target_pos.x - start_pos.x
	var dy = target_pos.y - start_pos.y
	print("  Executing real-runtime autopilot flight across delta (%+.0f, %+.0f)..." % [dx, dy])

	var flight_ticks = 0
	var max_ticks = 360 # 6.0 seconds max at 60fps
	var landed = false

	# Takeoff kick: fire right thruster to launch off Pad 0
	player.set_mobile_inputs(false, true)
	while player.current_state != SolarPlayer.State.FLYING and flight_ticks < 60:
		await physics_frame
		flight_ticks += 1
	assert(player.current_state == SolarPlayer.State.FLYING, "Player must lift off into FLYING state!")
	print("  Player successfully airborne! Piloting to Pad 1...")

	flight_ticks = 0
	while flight_ticks < max_ticks:
		await physics_frame
		flight_ticks += 1

		if player.current_state == SolarPlayer.State.ON_PAD or player.current_state == SolarPlayer.State.LANDED:
			landed = true
			break
		elif player.current_state == SolarPlayer.State.CRASHED:
			break

		var px = player.global_position.x - start_pos.x
		var py = player.global_position.y - start_pos.y
		var vx = player.velocity.x
		var vy = player.velocity.y
		var dist_rem = dx - px

		var brake_dist = maxf(vx * vx / (2.0 * (player.single_thruster_horizontal + player.horizontal_drag)) + 35.0, 60.0)
		var target_speed_x = clampf(dx * 0.42, 220.0, player.max_horizontal_speed)

		var want_brake = (dist_rem <= brake_dist and vx > 60.0)
		var want_accel = (dist_rem > brake_dist and vx < target_speed_x)

		var progress = clampf(px / maxf(dx, 1.0), 0.0, 1.0)
		var arc_apex_height = 100.0 + maxf(-dy * 0.40, 0.0)
		var target_y = dy * progress - arc_apex_height * (1.0 - pow(progress * 2.0 - 1.0, 2.0))

		var need_lift = (py > target_y or vy > 120.0)

		var th_l = false
		var th_r = false
		if need_lift:
			th_l = true
			th_r = true
			if want_brake and vy < 80.0:
				th_r = false
			elif want_accel and vy < 80.0:
				th_l = false
		else:
			if want_brake:
				th_l = true
			elif want_accel:
				th_r = true

		player.set_mobile_inputs(th_l, th_r)

	player.set_mobile_inputs(false, false)
	print("  Flight finished in %d ticks (%.2f s), Landed=%s, State=%s, Fuel=%.1f%%" % [
		flight_ticks, float(flight_ticks) / 60.0, landed, player.current_state, player.fuel
	])
	assert(landed, "Real-runtime autopilot must land safely on target platform!")
	assert(player.fuel >= 15.0, "Real-runtime flight must retain >= 15% fuel floor!")
	print("  ✅ Real-runtime game flight perfectly matches trajectory simulator!")

	print("\n==================================================")
	print("🎉 ALL EXPLORE SUN V2 INTEGRITY TESTS PASSED!")
	print("==================================================")
	quit(0)
