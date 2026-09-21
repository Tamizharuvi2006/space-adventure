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

	print("Viewport visible_rect: ", root.get_viewport().get_visible_rect())
	print("SkyLayer position: ", sky_layer.position, " motion_scale: ", sky_layer.motion_scale)
	print("SkyRect position: ", sky_rect.position, " size: ", sky_rect.size, " global_position: ", sky_rect.global_position)
	print("Camera position: ", camera.global_position, " zoom: ", camera.zoom)
	print("ParallaxBackground scroll_offset: ", bg.scroll_offset, " scroll_base_offset: ", bg.scroll_base_offset)

	for child in bg.get_children():
		if child is ParallaxLayer:
			print("Layer: ", child.name, " motion_scale: ", child.motion_scale, " mirroring: ", child.motion_mirroring, " pos: ", child.position)

	quit()
