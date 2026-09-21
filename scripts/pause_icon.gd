class_name PauseIcon
extends Control

# Clean, minimal mobile-game vector pause icon
# Draws two vertical rounded bars centered in the control
@export var bar_color: Color = Color(0.92, 0.95, 0.98, 0.90)
@export var bar_width: float = 3.5
@export var bar_height: float = 16.0
@export var bar_spacing: float = 5.0
@export var corner_radius: int = 2

var _bar_style: StyleBoxFlat = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_init_style()

func _init_style() -> void:
	if _bar_style == null:
		_bar_style = StyleBoxFlat.new()
	_bar_style.bg_color = bar_color
	_bar_style.corner_radius_top_left = corner_radius
	_bar_style.corner_radius_top_right = corner_radius
	_bar_style.corner_radius_bottom_right = corner_radius
	_bar_style.corner_radius_bottom_left = corner_radius
	_bar_style.anti_aliasing = true

func set_icon_color(c: Color) -> void:
	bar_color = c
	if _bar_style:
		_bar_style.bg_color = c
	queue_redraw()

func _draw() -> void:
	if _bar_style == null:
		_init_style()
		
	var center = size * 0.5
	var total_w = bar_width * 2.0 + bar_spacing
	var start_x = floorf(center.x - total_w * 0.5)
	var start_y = floorf(center.y - bar_height * 0.5)
	
	var rect_left = Rect2(start_x, start_y, bar_width, bar_height)
	var rect_right = Rect2(start_x + bar_width + bar_spacing, start_y, bar_width, bar_height)
	
	draw_style_box(_bar_style, rect_left)
	draw_style_box(_bar_style, rect_right)
