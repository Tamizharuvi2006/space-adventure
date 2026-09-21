extends SceneTree

func _init() -> void:
	var img = Image.load_from_file("res://v8_2_stress_1280x720_pad20.png")
	var w = img.get_width()
	var h = img.get_height()
	print("Image size: ", w, "x", h)
	for x in range(w - 12, w):
		var col_top = img.get_pixel(x, 100)
		var col_mid = img.get_pixel(x, 300)
		var col_bot = img.get_pixel(x, 500)
		print("x=%d -> top=%s mid=%s bot=%s" % [x, col_top, col_mid, col_bot])
	quit()
