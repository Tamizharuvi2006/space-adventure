extends Control
class_name FuelDroplets

## FuelDroplets (Solar Fire Energy Indicator) for Explore Sun
## 10 stylized sci-fi fire flames beneath the zone badge.
## Flame height and core brightness continuously represent fuel level (1–100).
## Color and glow are strictly confined INSIDE the flame silhouettes (no outside blur circles).

const FLAME_COUNT: int = 10
const FLAME_WIDTH: float = 12.0
const FLAME_HEIGHT: float = 15.0
const FLAME_SPACING: float = 5.5
const TOTAL_WIDTH: float = float(FLAME_COUNT) * FLAME_WIDTH + float(FLAME_COUNT - 1) * FLAME_SPACING # 169.5 px

# Iconic multi-tongue fire flame contour 🔥
const FLAME_SHAPE: Array[Vector2] = [
	Vector2( 0.00, -1.00), # Central flame tip
	Vector2( 0.38, -0.65), # Upper right slope
	Vector2( 0.68, -0.22), # Secondary right flame tooth
	Vector2( 0.52,  0.10), # Inward flame dip
	Vector2( 0.85,  0.48), # Lower right belly swell
	Vector2( 0.65,  0.82), # Bottom right curve
	Vector2( 0.00,  0.95), # Bottom base center
	Vector2(-0.65,  0.82), # Bottom left curve
	Vector2(-0.85,  0.48), # Lower left belly swell
	Vector2(-0.52,  0.10), # Inward flame dip
	Vector2(-0.68, -0.22), # Secondary left flame tooth
	Vector2(-0.38, -0.65), # Upper left slope
]

var fuel_percent: float = 100.0 # 0.0 to 100.0
var _visual_fuel: float = 100.0
var _target_fuel: float = 100.0

var _refill_time: float = 0.0
var _refill_animating: bool = false
var _flicker_time: float = 0.0

func _init() -> void:
	custom_minimum_size = Vector2(TOTAL_WIDTH, FLAME_HEIGHT + 4.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	custom_minimum_size = Vector2(TOTAL_WIDTH, FLAME_HEIGHT + 4.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_fuel_ratio(ratio: float, immediate: bool = false) -> void:
	set_fuel_percent(clampf(ratio * 100.0, 0.0, 100.0), immediate)

func set_fuel_percent(pct: float, immediate: bool = false) -> void:
	_target_fuel = clampf(pct, 0.0, 100.0)
	fuel_percent = _target_fuel
	if immediate:
		_visual_fuel = _target_fuel

func animate_refill(duration: float = 0.50) -> void:
	_target_fuel = 100.0
	fuel_percent = 100.0
	_refill_animating = true
	_refill_time = 0.0
	var tween = create_tween()
	tween.tween_property(self, "_visual_fuel", 100.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): _refill_animating = false)

func _process(delta: float) -> void:
	_flicker_time += delta * 4.5
	if _flicker_time > TAU * 10.0:
		_flicker_time -= TAU * 10.0
		
	if _refill_animating:
		_refill_time += delta

	if not _refill_animating:
		_visual_fuel = lerpf(_visual_fuel, _target_fuel, clampf(14.0 * delta, 0.0, 1.0))

	queue_redraw()

func _draw() -> void:
	var total_w = TOTAL_WIDTH
	var h = size.y
	var start_x = (size.x - total_w) * 0.5
	var cy = h * 0.5
	
	var half_w = FLAME_WIDTH * 0.5
	var half_h = FLAME_HEIGHT * 0.5
	
	for i in range(FLAME_COUNT):
		var cx = start_x + float(i) * (FLAME_WIDTH + FLAME_SPACING) + half_w
		
		# Fill factor f for this flame in [0.0, 1.0]
		var flame_min = float(i) * 10.0
		var f: float = clampf((_visual_fuel - flame_min) / 10.0, 0.0, 1.0)
		
		_draw_flame(Vector2(cx, cy), half_w, half_h, f, i)

func _draw_flame(center: Vector2, hw: float, hh: float, fill: float, index: int) -> void:
	var n_pts = FLAME_SHAPE.size()
	var y_base = center.y + hh * 0.95
	
	# Refill ignition wave
	var refill_ignite: float = 0.0
	if _refill_animating:
		var wave_pos = (_visual_fuel / 10.0)
		var dist = absf(float(index) - wave_pos)
		if dist < 1.5:
			refill_ignite = (1.5 - dist) / 1.5
	
	# Subtle living flicker on active flame tip
	var flicker_x: float = 0.0
	if fill > 0.01:
		flicker_x = sin(_flicker_time + float(index) * 1.2) * (0.35 * fill)
	
	# 1. Base empty flame socket (strictly no outside halo)
	var empty_poly = PackedVector2Array()
	empty_poly.resize(n_pts)
	for k in range(n_pts):
		var pt = FLAME_SHAPE[k]
		empty_poly[k] = Vector2(center.x + pt.x * hw, center.y + pt.y * hh)
		
	var empty_closed = empty_poly.duplicate()
	empty_closed.append(empty_poly[0])
	
	if fill < 0.999:
		# Draw dark unlit socket for empty / unfilled portion
		var soot_col = Color(0.12, 0.07, 0.04, 0.65)
		var soot_rim = Color(0.42, 0.26, 0.14, 0.50)
		draw_colored_polygon(empty_poly, soot_col)
		draw_polyline(empty_closed, soot_rim, 1.0, true)
	
	if fill <= 0.001:
		return
		
	# 2. Fire Fill Polygon (scaled from base upward according to fill level)
	var fire_poly = PackedVector2Array()
	fire_poly.resize(n_pts)
	
	var w_scale = (sqrt(fill) * 0.55 + 0.45)
	for k in range(n_pts):
		var pt = FLAME_SHAPE[k]
		var px = center.x + pt.x * hw * w_scale
		if k == 0:
			px += flicker_x * hw # Flickering tip
			
		var py = y_base - (y_base - (center.y + pt.y * hh)) * fill
		fire_poly[k] = Vector2(px, py)
	
	# Vibrant solar fire body
	var flame_body_col = Color(1.0, 0.55, 0.08, 1.0)
	if refill_ignite > 0.01:
		flame_body_col = flame_body_col.lerp(Color(1.0, 0.96, 0.75, 1.0), refill_ignite * 0.65)
	elif fill < 0.35:
		# Low fuel embers turn deep crimson
		var t = fill / 0.35
		flame_body_col = Color(1.0, lerpf(0.28, 0.55, t), 0.06, 0.95)
		
	draw_colored_polygon(fire_poly, flame_body_col)
	
	# 3. Inner Golden Flame Core
	if fill > 0.15:
		var core_poly = PackedVector2Array()
		core_poly.resize(n_pts)
		var core_fill = (fill - 0.15) / 0.85
		var core_w = w_scale * 0.55
		
		for k in range(n_pts):
			var pt = FLAME_SHAPE[k]
			var px = center.x + pt.x * hw * core_w
			if k == 0:
				px += flicker_x * hw * 0.5
			var py = y_base - (y_base - (center.y + (pt.y * 0.82 + 0.10) * hh)) * fill
			core_poly[k] = Vector2(px, py)
			
		var core_col = Color(1.0, 0.88, 0.28, 0.92 * core_fill + refill_ignite * 0.08)
		draw_colored_polygon(core_poly, core_col)
		
		# White-hot spark center
		if fill > 0.45:
			var white_poly = PackedVector2Array()
			white_poly.resize(n_pts)
			var white_w = core_w * 0.50
			for k in range(n_pts):
				var pt = FLAME_SHAPE[k]
				var px = center.x + pt.x * hw * white_w
				var py = y_base - (y_base - (center.y + (pt.y * 0.65 + 0.24) * hh)) * fill
				white_poly[k] = Vector2(px, py)
			draw_colored_polygon(white_poly, Color(1.0, 1.0, 0.90, 0.95 * fill))
	
	# 4. Crisp Golden Flame Contour
	var fire_closed = fire_poly.duplicate()
	fire_closed.append(fire_poly[0])
	var fire_rim_col = Color(1.0, 0.82, 0.32, 0.95 + refill_ignite * 0.05)
	draw_polyline(fire_closed, fire_rim_col, 1.0, true)
