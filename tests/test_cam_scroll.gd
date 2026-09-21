extends SceneTree

func _init() -> void:
	var packed = load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate()
	root.add_child(main)

	await process_frame
	await process_frame

	var camera = main.get_node("Camera2D")
	var bg = main.get_node("Background")
	var sky_layer = bg.get_node("SkyLayer")
	var sky_rect = sky_layer.get_node("SkyRect")

	for test_x in [0.0, 2000.0, 5000.0, 20000.0]:
		camera.global_position.x = test_x
		camera.zoom = Vector2(0.95, 0.95)
		await process_frame
		await process_frame
		print("\n--- CAM X = %d (zoom 0.95) ---" % test_x)
		print("camera global_pos: ", camera.global_position)
		print("bg scroll_offset: ", bg.scroll_offset)
		print("sky_layer pos: ", sky_layer.position, " global_pos: ", sky_layer.global_position)
		print("sky_rect pos: ", sky_rect.position, " size: ", sky_rect.size, " global_pos: ", sky_rect.global_position)
		var canvas_xform = root.get_viewport().get_canvas_transform()
		print("viewport canvas_xform: ", canvas_xform)

	quit()
