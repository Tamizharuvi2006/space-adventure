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

	print("--- CAMERA INITIAL ---")
	print("cam pos: ", camera.global_position, " zoom: ", camera.zoom)
	print("bg transform: ", bg.get_final_transform() if bg.has_method("get_final_transform") else "no method")
	print("bg canvas transform: ", bg.canvas_transform if "canvas_transform" in bg else "no attr")

	# Check what camera_follow does to camera.zoom!
	var cam_follow = main.get_node_or_null("CameraFollow")
	if cam_follow:
		print("CameraFollow found: current_zoom: ", cam_follow.get("current_zoom"))

	quit()
