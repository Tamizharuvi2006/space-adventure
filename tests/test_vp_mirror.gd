extends SceneTree

func _init() -> void:
	# Test how Godot renders ParallaxLayer when viewport width is 2340 and motion_mirroring is 2560 or different
	var packed = load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate()
	root.add_child(main)

	await process_frame
	await process_frame

	print("Viewport size: ", root.get_viewport().size)
	quit()
