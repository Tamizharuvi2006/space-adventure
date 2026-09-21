extends SceneTree

func _init() -> void:
	var packed = load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate()
	root.add_child(main)

	await process_frame
	await process_frame

	var bg = main.get_node("Background") as ParallaxBackground
	var sky_rect = bg.get_node("SkyLayer/SkyRect")

	print("bg.layer: ", bg.layer)
	print("bg.transform: ", bg.transform)
	print("bg.offset: ", bg.offset)
	print("bg.scale: ", bg.scale)
	print("bg.scroll_offset: ", bg.scroll_offset)
	print("bg.scroll_base_offset: ", bg.scroll_base_offset)
	print("bg.scroll_base_scale: ", bg.scroll_base_scale)
	print("bg.scroll_limit_begin: ", bg.scroll_limit_begin)
	print("bg.scroll_limit_end: ", bg.scroll_limit_end)
	print("bg.scroll_ignore_camera_zoom: ", bg.scroll_ignore_camera_zoom)
	
	# Check sky_rect's global transform in canvas
	print("sky_rect get_global_transform_with_canvas: ", sky_rect.get_global_transform_with_canvas())

	quit()
