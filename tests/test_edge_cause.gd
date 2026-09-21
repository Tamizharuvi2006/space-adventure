extends SceneTree

func _init() -> void:
	var packed = load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate()
	root.add_child(main)

	await process_frame
	await process_frame

	var bg = main.get_node("Background")
	var sky_layer = bg.get_node("SkyLayer")
	var sky_rect = sky_layer.get_node("SkyRect")
	var camera = main.get_node("Camera2D")

	print("Viewport size: ", root.get_viewport().size)
	print("Viewport visible_rect: ", root.get_viewport().get_visible_rect())
	print("Canvas transform: ", root.get_viewport().get_canvas_transform())
	print("Global canvas transform: ", root.get_viewport().get_final_transform())
	print("bg layer transform: ", bg.get_canvas_transform() if bg.has_method("get_canvas_transform") else "N/A")
	print("SkyLayer position: ", sky_layer.position, " global_pos: ", sky_layer.global_position)
	print("SkyRect position: ", sky_rect.position, " size: ", sky_rect.size, " global_pos: ", sky_rect.global_position)
	print("Camera zoom: ", camera.zoom, " offset: ", camera.offset, " anchor_mode: ", camera.anchor_mode)

	# Let's inspect how ParallaxBackground works with CanvasLayer
	print("Background class: ", bg.get_class())
	print("Background scroll_offset: ", bg.scroll_offset)
	print("Background scroll_base_offset: ", bg.scroll_base_offset)
	print("Background scroll_base_scale: ", bg.scroll_base_scale)
	print("Background scroll_limit_begin: ", bg.scroll_limit_begin)
	print("Background scroll_limit_end: ", bg.scroll_limit_end)
	print("Background scroll_ignore_camera_zoom: ", bg.scroll_ignore_camera_zoom)

	quit()
