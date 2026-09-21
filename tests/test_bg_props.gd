extends SceneTree

func _init() -> void:
	var packed = load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate()
	root.add_child(main)
	await process_frame

	var bg = main.get_node("Background") as ParallaxBackground
	print("scroll_ignore_camera_zoom: ", bg.scroll_ignore_camera_zoom)
	print("scroll_base_scale: ", bg.scroll_base_scale)
	print("scroll_limit_begin: ", bg.scroll_limit_begin)
	print("scroll_limit_end: ", bg.scroll_limit_end)

	var camera = main.get_node("Camera2D") as Camera2D
	print("Camera zoom: ", camera.zoom)
	print("Camera ignore_rotation: ", camera.ignore_rotation)

	# Test camera zoom 0.95
	camera.zoom = Vector2(0.95, 0.95)
	await process_frame
	await process_frame

	var img = root.get_viewport().get_texture().get_image()
	var w = img.get_width()
	var h = img.get_height()
	print("Testing with camera zoom 0.95:")
	for x in [w - 30, w - 20, w - 10, w - 5, w - 1]:
		print("x=%d, y=100 -> %s" % [x, img.get_pixel(x, 100)])

	quit()
