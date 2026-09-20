extends CanvasLayer
class_name SolarHUD

signal play_game_requested
signal pause_game_requested
signal resume_game_requested
signal retry_game_requested
signal home_game_requested

# UI sections
@onready var gameplay_hud: Control = $GameplayHUD
@onready var top_margin_container: MarginContainer = $GameplayHUD/TopMarginContainer
@onready var bottom_margin_container: MarginContainer = $GameplayHUD/BottomMarginContainer
@onready var main_menu: Control = $MainMenu
@onready var countdown_overlay: Control = $CountdownOverlay
@onready var countdown_label: Label = $CountdownOverlay/CountdownLabel
@onready var pause_menu: Control = $PauseMenu
@onready var game_over_menu: Control = $GameOverMenu

# Gameplay HUD components
@onready var altitude_label: Label = $GameplayHUD/TopMarginContainer/TopBar/CenterCluster/AltitudeLabel
@onready var altitude_tag: Label = $GameplayHUD/TopMarginContainer/TopBar/CenterCluster/AltitudeTag
@onready var best_label: Label = $GameplayHUD/TopMarginContainer/TopBar/BestContainer/BestLabel
@onready var best_tag: Label = $GameplayHUD/TopMarginContainer/TopBar/BestContainer/BestTag
@onready var destination_label: Label = $GameplayHUD/TopMarginContainer/TopBar/CenterCluster/DestinationBadge/DestinationLabel
@onready var destination_badge: PanelContainer = $GameplayHUD/TopMarginContainer/TopBar/CenterCluster/DestinationBadge
@onready var fuel_bar: ProgressBar = $GameplayHUD/TopMarginContainer/TopBar/CenterCluster/FuelBarContainer/FuelBar
@onready var fuel_status_label: Label = $GameplayHUD/TopMarginContainer/TopBar/CenterCluster/FuelBarContainer/FuelStatusLabel
@onready var pause_button: Button = $GameplayHUD/TopMarginContainer/TopBar/PauseButton
@onready var alert_label: Label = $GameplayHUD/CenterAlert/AlertLabel
@onready var alert_container: Control = $GameplayHUD/CenterAlert
@onready var planet_arrival_card: PanelContainer = $GameplayHUD/PlanetArrivalCard
@onready var arrival_icon: Label = $GameplayHUD/PlanetArrivalCard/VBox/ArrivalIcon
@onready var arrival_title: Label = $GameplayHUD/PlanetArrivalCard/VBox/ArrivalTitle
@onready var arrival_sub: Label = $GameplayHUD/PlanetArrivalCard/VBox/ArrivalSub
@onready var left_indicator: PanelContainer = $GameplayHUD/BottomMarginContainer/IndicatorHBox/LeftIndicator
@onready var right_indicator: PanelContainer = $GameplayHUD/BottomMarginContainer/IndicatorHBox/RightIndicator
var offscreen_indicator: PanelContainer = null
var indicator_label: Label = null
@onready var debug_panel: PanelContainer = $GameplayHUD/DebugPanel
@onready var debug_label: Label = $GameplayHUD/DebugPanel/DebugLabel

# Menu components
@onready var menu_best_label: Label = $MainMenu/VBox/MenuBestLabel
@onready var play_button: Button = $MainMenu/VBox/PlayButton
@onready var resume_button: Button = $PauseMenu/VBox/ResumeButton
@onready var pause_retry_button: Button = $PauseMenu/VBox/PauseRetryButton
@onready var pause_home_button: Button = $PauseMenu/VBox/PauseHomeButton

# Game over components
@onready var final_alt_label: Label = $GameOverMenu/VBox/FinalAltitudeLabel
@onready var final_best_label: Label = $GameOverMenu/VBox/FinalBestLabel
@onready var reason_label: Label = $GameOverMenu/VBox/ReasonLabel
@onready var new_record_badge: Label = $GameOverMenu/VBox/NewRecordBadge
@onready var game_over_retry_button: Button = $GameOverMenu/VBox/GameOverRetryButton
@onready var game_over_home_button: Button = $GameOverMenu/VBox/GameOverHomeButton

var target_player: SolarPlayer = null
var current_fuel_ratio: float = 1.0
var tracked_target_platform: Node2D = null
var is_debug_mode: bool = false
var tracked_world_gen: WorldGenerator = null

# Robust Multi-Touch Tracking (Left 50% vs Right 50% screen regions)
var left_touch_fingers: Dictionary = {}
var right_touch_fingers: Dictionary = {}
var touch_steer_l: bool = false
var touch_steer_r: bool = false

# Fuel bar styling reference
var fuel_bar_fill_style: StyleBoxFlat = null

func _play_ui_click() -> void:
	var sm = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_click"):
		sm.play_click()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect all buttons with sound
	play_button.pressed.connect(func(): _play_ui_click(); emit_signal("play_game_requested"))
	pause_button.pressed.connect(func(): _play_ui_click(); emit_signal("pause_game_requested"))
	resume_button.pressed.connect(func(): _play_ui_click(); emit_signal("resume_game_requested"))
	pause_retry_button.pressed.connect(func(): _play_ui_click(); emit_signal("retry_game_requested"))
	pause_home_button.pressed.connect(func(): _play_ui_click(); emit_signal("home_game_requested"))
	game_over_retry_button.pressed.connect(func(): _play_ui_click(); emit_signal("retry_game_requested"))
	game_over_home_button.pressed.connect(func(): _play_ui_click(); emit_signal("home_game_requested"))
	
	alert_container.modulate.a = 0.0
	_ensure_offscreen_indicator()
	if offscreen_indicator:
		offscreen_indicator.modulate.a = 0.0
	if altitude_tag:
		altitude_tag.text = "☀️ SUN JOURNEY"
	if best_tag:
		best_tag.text = "BEST PAD"
		
	# Duplicate fuel fill stylebox so color modifications are local
	if fuel_bar:
		var fill = fuel_bar.get_theme_stylebox("fill")
		if fill is StyleBoxFlat:
			fuel_bar_fill_style = fill.duplicate()
			fuel_bar.add_theme_stylebox_override("fill", fuel_bar_fill_style)
			
	# Update safe area dynamically
	_update_safe_margins()
	get_viewport().size_changed.connect(_update_safe_margins)

func _update_safe_margins() -> void:
	if not is_inside_tree():
		return
		
	var safe_rect = DisplayServer.get_display_safe_area()
	var win_size = DisplayServer.window_get_size()
	var vp_size = get_viewport().get_visible_rect().size
	
	var scale_x = vp_size.x / maxf(float(win_size.x), 1.0)
	var scale_y = vp_size.y / maxf(float(win_size.y), 1.0)
	
	var margin_l = maxf(safe_rect.position.x * scale_x, 28.0)
	var margin_r = maxf((win_size.x - (safe_rect.position.x + safe_rect.size.x)) * scale_x, 28.0)
	var margin_t = maxf(safe_rect.position.y * scale_y, 16.0)
	var margin_b = maxf((win_size.y - (safe_rect.position.y + safe_rect.size.y)) * scale_y, 20.0)
	
	if top_margin_container:
		top_margin_container.add_theme_constant_override("margin_left", int(margin_l))
		top_margin_container.add_theme_constant_override("margin_right", int(margin_r))
		top_margin_container.add_theme_constant_override("margin_top", int(margin_t))
		
	if bottom_margin_container:
		bottom_margin_container.add_theme_constant_override("margin_left", int(margin_l))
		bottom_margin_container.add_theme_constant_override("margin_right", int(margin_r))
		bottom_margin_container.add_theme_constant_override("margin_bottom", int(margin_b))

func bind_player(player: SolarPlayer) -> void:
	target_player = player
	target_player.fuel_changed.connect(_on_fuel_changed)

func bind_world_gen(gen: WorldGenerator) -> void:
	tracked_world_gen = gen

func set_target_platform(platform: Node2D) -> void:
	tracked_target_platform = platform

func _ensure_offscreen_indicator() -> void:
	if not is_instance_valid(offscreen_indicator):
		offscreen_indicator = PanelContainer.new()
		offscreen_indicator.name = "DynamicOffscreenIndicator"
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.07, 0.14, 0.88)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.25, 0.90, 0.82, 0.80)
		style.corner_radius_bottom_left = 14
		style.corner_radius_bottom_right = 14
		style.corner_radius_top_left = 14
		style.corner_radius_top_right = 14
		style.content_margin_left = 14.0
		style.content_margin_right = 14.0
		style.content_margin_top = 6.0
		style.content_margin_bottom = 6.0
		offscreen_indicator.add_theme_stylebox_override("panel", style)
		
		indicator_label = Label.new()
		indicator_label.name = "IndicatorLabel"
		var settings = LabelSettings.new()
		settings.font_size = 13
		settings.font_color = Color(0.35, 0.95, 0.88, 1.0)
		settings.outline_size = 2
		settings.outline_color = Color(0.02, 0.04, 0.08, 0.90)
		indicator_label.label_settings = settings
		offscreen_indicator.add_child(indicator_label)
		
		offscreen_indicator.modulate.a = 0.0
		if gameplay_hud:
			gameplay_hud.add_child(offscreen_indicator)

func _sync_thrusters() -> void:
	touch_steer_l = not left_touch_fingers.is_empty()
	touch_steer_r = not right_touch_fingers.is_empty()
	if target_player:
		target_player.set_mobile_inputs(touch_steer_l, touch_steer_r)

func clear_touch_inputs() -> void:
	left_touch_fingers.clear()
	right_touch_fingers.clear()
	_sync_thrusters()

func _unhandled_input(event: InputEvent) -> void:
	# F3 Telemetry toggle
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			is_debug_mode = not is_debug_mode
			if debug_panel:
				debug_panel.visible = is_debug_mode
				if is_instance_valid(tracked_world_gen):
					tracked_world_gen.set_debug_labels(is_debug_mode)
				get_viewport().set_input_as_handled()
				return
		elif event.keycode == KEY_ESCAPE:
			if gameplay_hud.visible and not pause_menu.visible:
				emit_signal("pause_game_requested")
				get_viewport().set_input_as_handled()
				return
			elif pause_menu.visible:
				emit_signal("resume_game_requested")
				get_viewport().set_input_as_handled()
				return
		elif event.keycode == KEY_R and game_over_menu.visible:
			emit_signal("retry_game_requested")
			get_viewport().set_input_as_handled()
			return

	# Only accept gameplay touches when in active gameplay
	if not gameplay_hud.visible or pause_menu.visible or game_over_menu.visible or main_menu.visible:
		return

	var vp_width = get_viewport().get_visible_rect().size.x

	# Multi-touch handling
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < vp_width * 0.5:
				left_touch_fingers[event.index] = true
			else:
				right_touch_fingers[event.index] = true
		else:
			left_touch_fingers.erase(event.index)
			right_touch_fingers.erase(event.index)
		_sync_thrusters()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		left_touch_fingers.erase(event.index)
		right_touch_fingers.erase(event.index)
		if event.position.x < vp_width * 0.5:
			left_touch_fingers[event.index] = true
		else:
			right_touch_fingers[event.index] = true
		_sync_thrusters()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.position.x < vp_width * 0.5:
					left_touch_fingers[-1] = true
				else:
					right_touch_fingers[-1] = true
			else:
				left_touch_fingers.erase(-1)
				right_touch_fingers.erase(-1)
			_sync_thrusters()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		left_touch_fingers.erase(-1)
		right_touch_fingers.erase(-1)
		if event.position.x < vp_width * 0.5:
			left_touch_fingers[-1] = true
		else:
			right_touch_fingers[-1] = true
		_sync_thrusters()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not gameplay_hud.visible:
		return
		
	# 1. Smooth fuel bar animation & 4-State Visual Feedback
	if fuel_bar:
		var target_val = current_fuel_ratio * 100.0
		fuel_bar.value = lerpf(fuel_bar.value, target_val, 14.0 * delta)
		
		# 4 States: 100-40% normal, 40-20% amber warning, 20-0% critical red, 0% BOOST EMPTY
		if current_fuel_ratio > 0.40:
			if fuel_bar_fill_style:
				fuel_bar_fill_style.bg_color = Color(0.12, 0.85, 1.0, 1.0)
			if fuel_status_label:
				fuel_status_label.text = ""
		elif current_fuel_ratio > 0.20:
			var pulse_amber = 0.85 + sin(Time.get_ticks_msec() * 0.009) * 0.15
			if fuel_bar_fill_style:
				fuel_bar_fill_style.bg_color = Color(1.0, 0.72, 0.15, pulse_amber)
			if fuel_status_label:
				fuel_status_label.text = "LOW FUEL"
				fuel_status_label.modulate = Color(1.0, 0.75, 0.2, 0.9)
		elif current_fuel_ratio > 0.0:
			var pulse_red = 0.75 + sin(Time.get_ticks_msec() * 0.016) * 0.25
			if fuel_bar_fill_style:
				fuel_bar_fill_style.bg_color = Color(1.0, 0.25, 0.25, pulse_red)
			if fuel_status_label:
				fuel_status_label.text = "CRITICAL FUEL"
				fuel_status_label.modulate = Color(1.0, 0.3, 0.3, pulse_red)
		else:
			if fuel_bar_fill_style:
				fuel_bar_fill_style.bg_color = Color(0.25, 0.28, 0.35, 0.4)
			if fuel_status_label:
				fuel_status_label.text = "BOOST EMPTY"
				fuel_status_label.modulate = Color(1.0, 0.35, 0.35, 1.0)
		
	# 2. Side Indicators visual feedback (resting ~0.25 alpha, glowing when active)
	var key_l = Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	var key_r = Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
	var key_space = Input.is_key_pressed(KEY_SPACE)
	
	var is_left_firing = (touch_steer_l or key_l or key_space) and current_fuel_ratio > 0.0
	var is_right_firing = (touch_steer_r or key_r or key_space) and current_fuel_ratio > 0.0
	
	if left_indicator:
		if is_left_firing:
			left_indicator.modulate = Color(0.2, 0.95, 1.0, 0.95)
			left_indicator.scale = left_indicator.scale.lerp(Vector2(1.08, 1.08), 16.0 * delta)
		else:
			left_indicator.modulate = Color(1.0, 1.0, 1.0, 0.28)
			left_indicator.scale = left_indicator.scale.lerp(Vector2.ONE, 16.0 * delta)
			
	if right_indicator:
		if is_right_firing:
			right_indicator.modulate = Color(0.2, 0.95, 1.0, 0.95)
			right_indicator.scale = right_indicator.scale.lerp(Vector2(1.08, 1.08), 16.0 * delta)
		else:
			right_indicator.modulate = Color(1.0, 1.0, 1.0, 0.28)
			right_indicator.scale = right_indicator.scale.lerp(Vector2.ONE, 16.0 * delta)

	# 3. Emergency next-platform off-screen indicator
	_update_offscreen_indicator(delta)

	# 4. Debug telemetry (F3)
	if debug_panel and debug_panel.visible and target_player and gameplay_hud.visible:
		var py = target_player.global_position.y
		var pvy = target_player.velocity.y
		var pvx = target_player.velocity.x
		var ty = tracked_target_platform.global_position.y if is_instance_valid(tracked_target_platform) else 0.0
		var dy = ty - py
		var dx = (tracked_target_platform.global_position.x - target_player.global_position.x) if is_instance_valid(tracked_target_platform) else 0.0
		var curr_idx = target_player.last_docked_platform.platform_index if is_instance_valid(target_player.last_docked_platform) else 0
		var next_idx = tracked_target_platform.platform_index if is_instance_valid(tracked_target_platform) else 1
		
		debug_label.text = "TELEMETRY [F3]\nPlayer: (%.0f, %.0f) | Vel: (%.0f, %.0f)\nTarget Y: %.0f | ΔY: %.0f | ΔX: %.0f\nPad #%02d → Next: #%02d\nThrusters: L=%s R=%s" % [
			target_player.global_position.x, py, pvx, pvy, ty, dy, dx, curr_idx, next_idx, is_left_firing, is_right_firing
		]

func _update_offscreen_indicator(delta: float) -> void:
	if not offscreen_indicator:
		return
		
	if not gameplay_hud.visible or not is_instance_valid(tracked_target_platform) or not is_instance_valid(target_player):
		offscreen_indicator.modulate.a = move_toward(offscreen_indicator.modulate.a, 0.0, 8.0 * delta)
		return
		
	var cam = get_viewport().get_camera_2d()
	if not cam:
		offscreen_indicator.modulate.a = move_toward(offscreen_indicator.modulate.a, 0.0, 8.0 * delta)
		return
		
	var view_size = get_viewport().get_visible_rect().size
	var target_world_pos = tracked_target_platform.global_position
	var screen_pos = (target_world_pos - cam.global_position) * cam.zoom.x + view_size * 0.5
	
	var margin_x = 90.0
	var margin_y_top = 80.0
	var margin_y_bottom = 110.0
	var is_offscreen = (screen_pos.x < margin_x or screen_pos.x > view_size.x - margin_x or 
	                    screen_pos.y < margin_y_top or screen_pos.y > view_size.y - margin_y_bottom)
	
	if is_offscreen:
		var clamped_x = clampf(screen_pos.x, margin_x, view_size.x - margin_x)
		var clamped_y = clampf(screen_pos.y, margin_y_top, view_size.y - margin_y_bottom)
		offscreen_indicator.position = Vector2(clamped_x - 70.0, clamped_y - 17.0)
		
		var delta_to_target = target_world_pos - target_player.global_position
		var arrow = "▶"
		if delta_to_target.y < -120.0 and absf(delta_to_target.x) < 180.0:
			arrow = "▲"
		elif delta_to_target.y > 120.0 and absf(delta_to_target.x) < 180.0:
			arrow = "▼"
		elif delta_to_target.x < 0.0:
			arrow = "◀"
		else:
			arrow = "▶"
			
		var dist_m = int(delta_to_target.length() * 0.25)
		indicator_label.text = "%s %d m" % [arrow, dist_m]
		offscreen_indicator.modulate.a = move_toward(offscreen_indicator.modulate.a, 0.95, 6.0 * delta)
	else:
		offscreen_indicator.modulate.a = move_toward(offscreen_indicator.modulate.a, 0.0, 8.0 * delta)

func show_main_menu(best_pad_count: int) -> void:
	clear_touch_inputs()
	main_menu.visible = true
	main_menu.modulate.a = 1.0
	menu_best_label.text = "BEST PAD %d" % best_pad_count
	
	gameplay_hud.visible = false
	pause_menu.visible = false
	game_over_menu.visible = false
	countdown_overlay.visible = false

func start_countdown(on_finished: Callable) -> void:
	clear_touch_inputs()
	main_menu.visible = false
	pause_menu.visible = false
	game_over_menu.visible = false
	gameplay_hud.visible = true
	countdown_overlay.visible = true
	
	var steps = ["3", "2", "1", "GO!"]
	var tween = create_tween()
	
	for i in range(steps.size()):
		var text = steps[i]
		tween.tween_callback(func():
			countdown_label.text = text
			countdown_overlay.scale = Vector2(1.3, 1.3)
			countdown_overlay.modulate.a = 1.0
		)
		tween.parallel().tween_property(countdown_overlay, "scale", Vector2.ONE, 0.22)
		tween.tween_interval(0.26)
		
	tween.tween_property(countdown_overlay, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		countdown_overlay.visible = false
		on_finished.call()
	)

func show_gameplay_hud() -> void:
	clear_touch_inputs()
	gameplay_hud.visible = true
	main_menu.visible = false
	pause_menu.visible = false
	game_over_menu.visible = false
	countdown_overlay.visible = false

func show_pause_menu() -> void:
	clear_touch_inputs()
	gameplay_hud.visible = false
	pause_menu.visible = true
	pause_menu.modulate.a = 1.0

func hide_pause_menu() -> void:
	clear_touch_inputs()
	pause_menu.visible = false
	gameplay_hud.visible = true

func show_game_over(current_pad_count: int, best_pad_count: int, is_new_record: bool, reason: String) -> void:
	clear_touch_inputs()
	gameplay_hud.visible = false
	pause_menu.visible = false
	game_over_menu.visible = true
	final_alt_label.text = "PAD %d" % current_pad_count
	final_best_label.text = "BEST PAD %d" % best_pad_count
	reason_label.text = reason
	new_record_badge.visible = is_new_record
	
	if is_new_record:
		var sm = get_node_or_null("/root/SoundManager")
		if sm and sm.has_method("play_record"):
			sm.play_record()
		new_record_badge.scale = Vector2(0.8, 0.8)
		var b_tween = create_tween().set_loops(3)
		b_tween.tween_property(new_record_badge, "scale", Vector2(1.15, 1.15), 0.22)
		b_tween.tween_property(new_record_badge, "scale", Vector2.ONE, 0.22)
	
	game_over_menu.modulate.a = 1.0

func hide_game_over() -> void:
	clear_touch_inputs()
	game_over_menu.visible = false
	gameplay_hud.visible = true

func update_progress(current_pad_count: int, total_pads: int, best_pad_count: int) -> void:
	if altitude_label:
		altitude_label.text = "%d / %d" % [current_pad_count, total_pads]
		# Scale-in animation on progress change
		altitude_label.scale = Vector2(1.12, 1.12)
		var t = create_tween()
		t.tween_property(altitude_label, "scale", Vector2.ONE, 0.15)
	if best_label:
		best_label.text = "PAD %d" % best_pad_count

func update_zone_name(zone_name: String) -> void:
	if destination_label:
		destination_label.text = "  ☀️ %s  " % zone_name

var banner_tween: Tween = null

func show_zone_arrival_banner(zone: Dictionary) -> void:
	if not planet_arrival_card:
		return
		
	arrival_icon.text = zone.get("icon", "☀️")
	arrival_title.text = zone.get("name", "NEW ZONE")
	arrival_sub.text = zone.get("subtitle", "")
	
	if banner_tween and banner_tween.is_valid():
		banner_tween.kill()
		
	planet_arrival_card.scale = Vector2(0.85, 0.85)
	planet_arrival_card.modulate.a = 0.0
	
	banner_tween = create_tween()
	banner_tween.set_parallel(true)
	banner_tween.tween_property(planet_arrival_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tween.tween_property(planet_arrival_card, "modulate:a", 1.0, 0.25)
	banner_tween.chain().tween_interval(2.2)
	banner_tween.chain().tween_property(planet_arrival_card, "modulate:a", 0.0, 0.5)

# Legacy compatibility
func show_planet_arrival_banner(planet: Dictionary) -> void:
	show_zone_arrival_banner(planet)

func show_journey_complete(current_pad_count: int, total_pads: int) -> void:
	if not planet_arrival_card:
		return
		
	arrival_icon.text = "🌞"
	arrival_title.text = "SUN JOURNEY COMPLETE"
	arrival_sub.text = "%d / %d — SUN MASTERED" % [current_pad_count, total_pads]
	
	if banner_tween and banner_tween.is_valid():
		banner_tween.kill()
		
	planet_arrival_card.scale = Vector2(0.80, 0.80)
	planet_arrival_card.modulate.a = 0.0
	
	banner_tween = create_tween()
	banner_tween.set_parallel(true)
	banner_tween.tween_property(planet_arrival_card, "scale", Vector2(1.05, 1.05), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tween.tween_property(planet_arrival_card, "modulate:a", 1.0, 0.35)
	banner_tween.chain().tween_interval(4.0)
	banner_tween.chain().tween_property(planet_arrival_card, "modulate:a", 0.0, 0.6)

func show_landing_alert(text: String, is_perfect: bool) -> void:
	if alert_label:
		alert_label.text = text
		alert_label.modulate = Color(0.2, 1.0, 0.8) if is_perfect else Color(0.3, 0.9, 1.0)
		
	alert_container.modulate.a = 1.0
	alert_container.scale = Vector2(1.15, 1.15)
	
	var tween = create_tween()
	tween.tween_property(alert_container, "scale", Vector2.ONE, 0.12)
	tween.tween_property(alert_container, "modulate:a", 0.0, 0.5).set_delay(0.5)

func _on_fuel_changed(current: float, max_val: float) -> void:
	current_fuel_ratio = current / max_val if max_val > 0.0 else 0.0
