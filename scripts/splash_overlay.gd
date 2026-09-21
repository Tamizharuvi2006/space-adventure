extends CanvasLayer

signal splash_finished

var _loading_bar: Control
var _progress: float = 0.0
var _glow_pulse: float = 1.0
var _label: Label

var _sparkle_angle: float = 0.0
var _sparks: Array[Dictionary] = []
var _spark_spawn_timer: float = 0.0

const BAR_WIDTH: float = 320.0
const BAR_HEIGHT: float = 3.5

func _init() -> void:
	layer = 120

func _ready() -> void:
	# 1. Full-screen background and cover texture matching Godot boot splash
	var root_control = Control.new()
	root_control.name = "SplashRoot"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	
	var bg_rect = ColorRect.new()
	bg_rect.color = Color(0, 0, 0, 1.0)
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(bg_rect)
	
	var tex_rect = TextureRect.new()
	tex_rect.texture = preload("res://splash.png")
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(tex_rect)
	
	# 2. Loading Container placed near bottom in the dark lunar silhouette (Y ~ 83.5%)
	var load_container = Control.new()
	load_container.name = "LoadingContainer"
	load_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	load_container.anchor_left = 0.5
	load_container.anchor_right = 0.5
	load_container.anchor_top = 0.835
	load_container.anchor_bottom = 0.835
	load_container.offset_left = -BAR_WIDTH * 0.5
	load_container.offset_right = BAR_WIDTH * 0.5
	load_container.offset_top = 0.0
	load_container.offset_bottom = 35.0
	root_control.add_child(load_container)
	
	# 3. Custom drawn loading line
	_loading_bar = Control.new()
	_loading_bar.name = "LoadingLine"
	_loading_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_loading_bar.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_loading_bar.position = Vector2(0, 0)
	_loading_bar.draw.connect(_on_loading_bar_draw)
	load_container.add_child(_loading_bar)
	
	# 4. Text below: "INITIALIZING"
	_label = Label.new()
	_label.name = "InitLabel"
	_label.text = "INITIALIZING"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size = Vector2(BAR_WIDTH, 16.0)
	_label.position = Vector2(0, 9.0)
	
	var label_settings = LabelSettings.new()
	label_settings.font_size = 11
	label_settings.font_color = Color(1.0, 0.88, 0.72, 0.65)
	label_settings.outline_size = 2
	label_settings.outline_color = Color(0.02, 0.02, 0.04, 0.90)
	_label.label_settings = label_settings
	load_container.add_child(_label)
	
	# 5. Start smooth 2-second cinematic sequence
	_start_animation_sequence(root_control)

func _process(delta: float) -> void:
	_sparkle_angle += delta * 3.5
	
	# Emit trailing sparks while moving
	if _progress > 0.02 and _progress < 0.99:
		_spark_spawn_timer += delta
		if _spark_spawn_timer >= 0.045:
			_spark_spawn_timer = 0.0
			var h_center = Vector2(BAR_WIDTH * _progress, BAR_HEIGHT * 0.5)
			# Random gentle velocity drifting backward and slightly up/down
			var angle_rand = randf_range(PI * 0.75, PI * 1.25) # backward
			var speed = randf_range(12.0, 32.0)
			_sparks.append({
				"pos": h_center + Vector2(randf_range(-1.0, 1.0), randf_range(-2.0, 2.0)),
				"vel": Vector2(cos(angle_rand), sin(angle_rand)) * speed + Vector2(0, randf_range(-6.0, 6.0)),
				"life": 0.45,
				"max_life": 0.45,
				"size": randf_range(1.2, 2.5)
			})
	
	# Update active sparks
	var i = _sparks.size() - 1
	while i >= 0:
		var s = _sparks[i]
		s["life"] -= delta
		if s["life"] <= 0.0:
			_sparks.remove_at(i)
		else:
			s["pos"] += s["vel"] * delta
			s["vel"] *= 0.92
		i -= 1
	
	if _loading_bar:
		_loading_bar.queue_redraw()

func _on_loading_bar_draw() -> void:
	if not _loading_bar:
		return
	var w = BAR_WIDTH
	var h = BAR_HEIGHT
	var y = h * 0.5
	
	# 1. Dark transparent track with antialiased rounded ends
	var track_col = Color(0.14, 0.10, 0.08, 0.60)
	_loading_bar.draw_line(Vector2(0, y), Vector2(w, y), track_col, h, true)
	
	# 2. Draw trailing floating ember sparks
	for s in _sparks:
		var life_frac = s["life"] / s["max_life"]
		var spark_alpha = clampf(life_frac, 0.0, 1.0) * 0.75
		var spark_col = Color(1.0, 0.75, 0.22, spark_alpha)
		var spark_size = s["size"] * (0.5 + 0.5 * life_frac)
		_loading_bar.draw_circle(s["pos"], spark_size, spark_col)
		_loading_bar.draw_circle(s["pos"], spark_size * 0.4, Color(1.0, 0.98, 0.85, spark_alpha))
	
	# 3. Progress fill
	if _progress > 0.001:
		var fill_w = clampf(w * _progress, 0.0, w)
		var fill_col = Color(1.0, 0.65, 0.18, 0.95)
		_loading_bar.draw_line(Vector2(0, y), Vector2(fill_w, y), fill_col, h, true)
		
		var head_center = Vector2(fill_w, y)
		
		# 4. Multi-layered coronal glow
		var outer_r = 8.5 * _glow_pulse
		var outer_col = Color(1.0, 0.60, 0.12, 0.38 * _glow_pulse)
		_loading_bar.draw_circle(head_center, outer_r, outer_col)
		
		var mid_r = 4.2 * _glow_pulse
		var mid_col = Color(1.0, 0.82, 0.40, 0.75 * _glow_pulse)
		_loading_bar.draw_circle(head_center, mid_r, mid_col)
		
		# 5. Brilliant 4-Point Rotating Star Sparkle
		var star_r_outer = 15.0 * _glow_pulse
		var star_w_outer = 2.4 * _glow_pulse
		_draw_diamond_star(head_center, star_r_outer, star_w_outer, _sparkle_angle, Color(1.0, 0.70, 0.15, 0.45 * _glow_pulse))
		
		var star_r_inner = 8.5 * _glow_pulse
		var star_w_inner = 1.6 * _glow_pulse
		_draw_diamond_star(head_center, star_r_inner, star_w_inner, _sparkle_angle, Color(1.0, 0.98, 0.88, 0.95))
		
		# White-hot star core pip
		_loading_bar.draw_circle(head_center, 1.8, Color(1.0, 1.0, 0.96, 1.0))

func _draw_diamond_star(center: Vector2, radius: float, inner_w: float, angle: float, col: Color) -> void:
	var pts = PackedVector2Array()
	for k in range(4):
		var a_tip = angle + (k * PI * 0.5)
		var a_in = a_tip + (PI * 0.25)
		pts.append(center + Vector2(cos(a_tip), sin(a_tip)) * radius)
		pts.append(center + Vector2(cos(a_in), sin(a_in)) * inner_w)
	_loading_bar.draw_colored_polygon(pts, col)

func _start_animation_sequence(root_control: Control) -> void:
	# Subtle breathing pulse on the glowing head
	var pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(self, "_glow_pulse", 1.25, 0.35).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(self, "_glow_pulse", 0.90, 0.35).set_trans(Tween.TRANS_SINE)
	
	# Main 0% -> 100% progress animation (~1.65 seconds)
	var main_tween = create_tween()
	main_tween.tween_method(func(val: float):
		_progress = val
		if _loading_bar:
			_loading_bar.queue_redraw()
	, 0.0, 1.0, 1.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# At 1.65s: 100% reached -> dramatic starburst bloom flash
	main_tween.tween_callback(func():
		pulse_tween.kill()
		_progress = 1.0
		_glow_pulse = 2.4
		if _loading_bar:
			_loading_bar.queue_redraw()
	)
	main_tween.tween_property(self, "_glow_pulse", 1.0, 0.14).set_trans(Tween.TRANS_QUAD)
	
	# At ~1.77s: smoothly fade out the entire splash overlay over 0.35s
	main_tween.tween_property(root_control, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# At ~2.12s: finish and cleanup
	main_tween.tween_callback(func():
		splash_finished.emit()
		queue_free()
	)
