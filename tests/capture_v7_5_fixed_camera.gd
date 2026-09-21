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

	hud.emit_signal("play_game_requested")
	while current_main.current_state != SolarMain.GameState.PLAYING:
		await physics_frame
	for _f in range(10): await physics_frame

	# Ensure pads up to 6 exist
	while world_gen.next_platform_idx <= 6:
		world_gen.spawn_next_route_pad()
		await process_frame

	# 1. Docked on Pad 1
	var pad_1 = world_gen.get_platform_by_index(1)
	var pad_2 = world_gen.get_platform_by_index(2)
	player.spawn_on_platform(pad_1)
	camera.set_next_target_platform(pad_2)
	camera.snap_to_target()
	for _f in range(20): await physics_frame
	var img1 = root.get_viewport().get_texture().get_image()
	img1.save_png("res://v7_5_docked_mars_composition.png")
	print("Saved v7_5_docked_mars_composition.png")

	# 2. Launch upward: Fixed height (no giant sky, camera stays grounded)
	player.global_position = pad_1.get_landing_position() + Vector2(60.0, -120.0)
	player.current_state = SolarPlayer.State.FLYING
	player.velocity = Vector2(50.0, -180.0)
	for _f in range(20): await physics_frame
	var img2 = root.get_viewport().get_texture().get_image()
	img2.save_png("res://v7_5_takeoff_fixed_height.png")
	print("Saved v7_5_takeoff_fixed_height.png")

	# 3. Forward flight: Pad 2 revealed ahead in 65%–80% area
	player.global_position = lerp(pad_1.get_landing_position(), pad_2.get_landing_position(), 0.50)
	player.velocity = Vector2(120.0, 20.0)
	for _f in range(25): await physics_frame
	var img3 = root.get_viewport().get_texture().get_image()
	img3.save_png("res://v7_5_forward_flight_pad_reveal.png")
	print("Saved v7_5_forward_flight_pad_reveal.png")

	quit()
