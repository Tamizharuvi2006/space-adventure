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

	# 1. Docked Lander on Pad 1
	var pad_1 = world_gen.get_platform_by_index(1)
	player.spawn_on_platform(pad_1)
	for _f in range(15): await physics_frame
	var img1 = root.get_viewport().get_texture().get_image()
	img1.save_png("res://v7_4_explorer_lander_docked.png")
	print("Saved v7_4_explorer_lander_docked.png")

	# 2. Descent look-ahead
	player.global_position = pad_1.get_landing_position() + Vector2(280.0, -180.0)
	player.current_state = SolarPlayer.State.FLYING
	player.velocity = Vector2(100.0, 340.0)
	var pad_2 = world_gen.get_platform_by_index(2)
	camera.set_next_target_platform(pad_2)
	for _f in range(25): await physics_frame
	var img2 = root.get_viewport().get_texture().get_image()
	img2.save_png("res://v7_4_descent_lookahead.png")
	print("Saved v7_4_descent_lookahead.png")

	# 3. High ascent
	player.global_position = pad_1.get_landing_position() + Vector2(150.0, -280.0)
	player.velocity = Vector2(80.0, -260.0)
	for _f in range(15): await physics_frame
	var img3 = root.get_viewport().get_texture().get_image()
	img3.save_png("res://v7_4_high_ascent.png")
	print("Saved v7_4_high_ascent.png")

	quit()
