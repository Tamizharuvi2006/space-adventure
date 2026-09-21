extends SceneTree

func _init() -> void:
	var hud_packed = load("res://scenes/hud.tscn") as PackedScene
	var hud = hud_packed.instantiate()
	root.add_child(hud)

	await process_frame
	await process_frame

	var tmc = hud.get_node("GameplayHUD/TopMarginContainer")
	var tb = tmc.get_node("TopBar")
	var pb = tb.get_node("PauseButton")

	print("Initial:")
	print("vp visible rect: ", root.get_viewport().get_visible_rect())
	print("tmc size: ", tmc.size, " global_pos: ", tmc.global_position)
	print("tb size: ", tb.size, " size_flags_h: ", tb.size_flags_horizontal)
	print("pb size: ", pb.size, " global_pos: ", pb.global_position)

	# Now change viewport
	root.size = Vector2i(2340, 1080)
	await process_frame
	await process_frame

	print("\nAfter resizing to 2340x1080:")
	print("vp visible rect: ", root.get_viewport().get_visible_rect())
	print("tmc size: ", tmc.size, " global_pos: ", tmc.global_position)
	print("tb size: ", tb.size)
	print("pb size: ", pb.size, " global_pos: ", pb.global_position)

	quit()
