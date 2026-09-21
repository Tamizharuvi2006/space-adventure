extends SceneTree

func _init() -> void:
	print("Godot version: ", Engine.get_version_info().string)
	
	# Let's check ParallaxBackground properties
	var pb = ParallaxBackground.new()
	print("scroll_ignore_camera_zoom default: ", pb.scroll_ignore_camera_zoom)
	
	var pl = ParallaxLayer.new()
	pb.add_child(pl)
	print("motion_mirroring: ", pl.motion_mirroring)
	
	quit()
