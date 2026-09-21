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

	while world_gen.next_platform_idx <= 6:
		world_gen.spawn_next_route_pad()
		await process_frame

	var pad_1 = world_gen.get_platform_by_index(1)
	var pad_2 = world_gen.get_platform_by_index(2)

	# 1. Idle breathing on Pad 1
	player.spawn_on_platform(pad_1)
	camera.set_next_target_platform(pad_2)
	camera.snap_to_target()
	for _f in range(35): await physics_frame

	var img1 = root.get_viewport().get_texture().get_image()
	img1.save_png("res://v8_2_astronaut_idle_breathing.png")
	print("Saved v8_2_astronaut_idle_breathing.png")

	# 2. In-flight with right thruster steering (right arm braced, trailing legs)
	player.global_position = lerp(pad_1.get_landing_position(), pad_2.get_landing_position(), 0.45) + Vector2(0.0, -80.0)
	player.current_state = SolarPlayer.State.FLYING
	player.velocity = Vector2(210.0, -25.0)
	player.set_mobile_inputs(false, true)
	for _f in range(20): await physics_frame

	var img2 = root.get_viewport().get_texture().get_image()
	img2.save_png("res://v8_2_astronaut_thruster_steering.png")
	print("Saved v8_2_astronaut_thruster_steering.png")

	quit()
