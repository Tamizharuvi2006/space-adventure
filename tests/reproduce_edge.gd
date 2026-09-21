extends SceneTree

func _init() -> void:
	var save_path = "user://explore_sun_save.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	var packed = load("res://scenes/main.tscn") as PackedScene
	var current_main = packed.instantiate()
	root.add_child(current_main)

	for _i in range(5):
		await process_frame

	var hud = current_main.hud
	var player = current_main.player
	var camera = current_main.camera
	var world_gen = current_main.world_gen
	var bg = current_main.background

	hud.emit_signal("play_game_requested")
	while current_main.current_state != 1: # PLAYING
		await physics_frame
	for _f in range(10): await physics_frame

	while world_gen.next_platform_idx <= 23:
		world_gen.spawn_next_route_pad()
		await process_frame

	var pad_20 = world_gen.get_platform_by_index(20)
	var pad_21 = world_gen.get_platform_by_index(21)

	player.spawn_on_platform(pad_20)
	camera.set_next_target_platform(pad_21)
	camera.snap_to_target()
	bg.notify_pad_changed(20)
	for _f in range(25): await physics_frame

	var img = root.get_viewport().get_texture().get_image()
	var w = img.get_width()
	var h = img.get_height()
	print("Rendered image size: ", w, "x", h)
	for x in range(w - 15, w):
		var c100 = img.get_pixel(x, 100)
		var c360 = img.get_pixel(x, 360)
		print("x=%d -> top=%s mid=%s" % [x, c100, c360])

	quit()
