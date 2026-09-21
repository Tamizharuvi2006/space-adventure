extends SceneTree

func _init() -> void:
	# Let's test ParallaxLayer behavior in Godot 4
	var pb = ParallaxBackground.new()
	var pl = ParallaxLayer.new()
	pl.motion_scale = Vector2(0.5, 0.5)
	pl.motion_mirroring = Vector2(2560, 0)
	pb.add_child(pl)
	root.add_child(pb)
	
	print("ParallaxLayer mirroring test initialized")
	quit()
