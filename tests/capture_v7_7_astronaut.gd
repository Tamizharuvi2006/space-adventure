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

	# Ensure pads up to 11 exist so Pad 10 is fully ready
	while world_gen.next_platform_idx <= 12:
		world_gen.spawn_next_route_pad()
		await process_frame

	var pad_10 = world_gen.get_platform_by_index(10)
	var pad_11 = world_gen.get_platform_by_index(11)

	# 1. Docked on Pad 10 (matching the reference image composition!)
	player.spawn_on_platform(pad_10)
	camera.set_next_target_platform(pad_11)
	camera.snap_to_target()
	for _f in range(25): await physics_frame

	var img1 = root.get_viewport().get_texture().get_image()
	img1.save_png("res://v7_7_astronaut_docked.png")
	print("Saved v7_7_astronaut_docked.png")

	# 2. In-flight toward Pad 11 with trailing limbs and thruster exhaust
	player.global_position = lerp(pad_10.get_landing_position(), pad_11.get_landing_position(), 0.40) + Vector2(0.0, -90.0)
	player.current_state = SolarPlayer.State.FLYING
	player.velocity = Vector2(180.0, -15.0)
	player.set_mobile_inputs(false, true) # Right thruster firing
	for _f in range(15): await physics_frame

	var img2 = root.get_viewport().get_texture().get_image()
	img2.save_png("res://v7_7_astronaut_inflight.png")
	print("Saved v7_7_astronaut_inflight.png")

	quit()
