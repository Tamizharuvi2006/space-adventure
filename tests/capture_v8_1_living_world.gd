extends SceneTree

const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")

var current_main: SolarMain = null

func _init() -> void:
	call_deferred("_run_captures")

func _run_captures() -> void:
	var save_path = "user://explore_sun_save.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	var packed = load("res://scenes/main.tscn") as PackedScene
	current_main = packed.instantiate() as SolarMain
	root.add_child(current_main)

	await process_frame
	await process_frame
	await process_frame

	var hud = current_main.hud
	var player = current_main.player
	var camera = current_main.camera
	var world_gen = current_main.world_gen
	var bg = current_main.background

	hud.emit_signal("play_game_requested")
	while current_main.current_state != SolarMain.GameState.PLAYING:
		await physics_frame
	for _f in range(10): await physics_frame

	# Ensure pads up to 23 are spawned so Pad 20, 21, 22 are fully generated
	while world_gen.next_platform_idx <= 23:
		world_gen.spawn_next_route_pad()
		await process_frame

	var pad_19 = world_gen.get_platform_by_index(19)
	var pad_20 = world_gen.get_platform_by_index(20)
	var pad_21 = world_gen.get_platform_by_index(21)

	# -------------------------------------------------------------------------
	# CAPTURE 1: Stationary on Pad 20
	# -------------------------------------------------------------------------
	player.spawn_on_platform(pad_20)
	camera.set_next_target_platform(pad_21)
	camera.snap_to_target()
	bg.notify_pad_changed(20)
	for _f in range(25): await physics_frame

	var img1 = root.get_viewport().get_texture().get_image()
	img1.save_png("res://v8_1_stationary_pad20.png")
	print("Saved v8_1_stationary_pad20.png")

	# -------------------------------------------------------------------------
	# CAPTURE 2: Slow Flight
	# -------------------------------------------------------------------------
	player.global_position = lerp(pad_19.get_landing_position(), pad_20.get_landing_position(), 0.35) + Vector2(0.0, -80.0)
	player.current_state = SolarPlayer.State.FLYING
	player.velocity = Vector2(90.0, -10.0)
	player.set_mobile_inputs(false, false)
	camera.set_next_target_platform(pad_20)
	for _f in range(25): await physics_frame

	var img2 = root.get_viewport().get_texture().get_image()
	img2.save_png("res://v8_1_slow_flight.png")
	print("Saved v8_1_slow_flight.png")

	# -------------------------------------------------------------------------
	# CAPTURE 3: Fast Flight (Active Thrusters)
	# -------------------------------------------------------------------------
	player.global_position = lerp(pad_19.get_landing_position(), pad_20.get_landing_position(), 0.70) + Vector2(0.0, -70.0)
	player.current_state = SolarPlayer.State.FLYING
	player.velocity = Vector2(275.0, -25.0)
	player.set_mobile_inputs(false, true) # Right thruster firing
	camera.set_next_target_platform(pad_20)
	for _f in range(20): await physics_frame

	var img3 = root.get_viewport().get_texture().get_image()
	img3.save_png("res://v8_1_fast_flight.png")
	print("Saved v8_1_fast_flight.png")

	# -------------------------------------------------------------------------
	# CAPTURE 4: Long Flight Across a Canyon
	# -------------------------------------------------------------------------
	player.global_position = lerp(pad_20.get_landing_position(), pad_21.get_landing_position(), 0.50) + Vector2(0.0, -110.0)
	player.current_state = SolarPlayer.State.FLYING
	player.velocity = Vector2(170.0, 15.0)
	player.set_mobile_inputs(true, true) # Dual stabilization
	camera.set_next_target_platform(pad_21)
	for _f in range(25): await physics_frame

	var img4 = root.get_viewport().get_texture().get_image()
	img4.save_png("res://v8_1_canyon_flight.png")
	print("Saved v8_1_canyon_flight.png")

	# -------------------------------------------------------------------------
	# CAPTURE 5: Entering a New Zone (Zone 1: Solar Craters)
	# -------------------------------------------------------------------------
	player.spawn_on_platform(pad_21)
	camera.set_next_target_platform(world_gen.get_platform_by_index(22))
	camera.snap_to_target()
	bg.notify_pad_changed(21) # triggers Zone 1 visual transition
	var zone1 = SunZoneData.get_zone_by_index(1)
	bg.apply_zone_visuals_instant(zone1)
	for _f in range(25): await physics_frame

	var img5 = root.get_viewport().get_texture().get_image()
	img5.save_png("res://v8_1_entering_new_zone.png")
	print("Saved v8_1_entering_new_zone.png")

	quit()
