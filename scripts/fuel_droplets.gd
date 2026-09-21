extends Control
class_name FuelDroplets

## FuelDroplets (Multi-Tier Energy Flame Indicator) for Explore Sun
## 10 stylized sci-fi energy flames beneath the zone badge.
## Continuous 1–100 fuel mapping with 4 reactive energy states:
##   76–100%: Solar Flame   (Orange -> Gold -> Soft White)
##   51–75%:  Plasma Blue   (Deep Blue -> Bright Cyan -> Pale White)
##   26–50%:  Void Violet   (Deep Purple -> Violet -> Pink-White)
##    1–25%:  Danger Flame  (Deep Red -> Hot Orange -> Bright Yellow-White)
## Each active flame visibly contains an outer glow body, middle flame, and bright inner core.
## Each flame flickers and breathes independently with smooth transitions across fuel tiers.

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

# Color Palette Structure
class FlamePalette:
	var outer: Color
	var middle: Color
	var core: Color
	var rim: Color
	var socket_rim: Color
	
	func _init(p_outer: Color, p_middle: Color, p_core: Color, p_rim: Color, p_socket_rim: Color) -> void:
		outer = p_outer
		middle = p_middle
		core = p_core
		rim = p_rim
		socket_rim = p_socket_rim
		
	func lerp(other: FlamePalette, weight: float) -> FlamePalette:
		var w = clampf(weight, 0.0, 1.0)
		return FlamePalette.new(
			outer.lerp(other.outer, w),
			middle.lerp(other.middle, w),
			core.lerp(other.core, w),
			rim.lerp(other.rim, w),
			socket_rim.lerp(other.socket_rim, w)
		)

var _pal_solar: FlamePalette
var _pal_plasma: FlamePalette
var _pal_violet: FlamePalette
var _pal_danger: FlamePalette

var fuel_percent: float = 100.0 # 0.0 to 100.0
var _visual_fuel: float = 100.0
var _target_fuel: float = 100.0

var _refill_time: float = 0.0
var _refill_animating: bool = false
var _flicker_time: float = 0.0

func _init() -> void:
	custom_minimum_size = Vector2(TOTAL_WIDTH, FLAME_HEIGHT + 4.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_init_palettes()

func _ready() -> void:
	custom_minimum_size = Vector2(TOTAL_WIDTH, FLAME_HEIGHT + 4.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_init_palettes()

func _init_palettes() -> void:
	# 76–100%: Solar Flame (Orange -> Gold -> Soft White)
	_pal_solar = FlamePalette.new(
		Color(1.00, 0.42, 0.05, 0.95), # Outer warm orange
		Color(1.00, 0.80, 0.16, 0.98), # Middle solar gold/yellow
		Color(1.00, 0.98, 0.92, 1.00), # Inner soft white
		Color(1.00, 0.88, 0.45, 0.95), # Crisp rim
		Color(0.45, 0.25, 0.10, 0.45)  # Dark socket rim
	)
	
	# 51–75%: Plasma Blue (Deep Blue -> Bright Cyan -> Pale White)
	_pal_plasma = FlamePalette.new(
		Color(0.08, 0.38, 0.98, 0.95), # Outer deep blue
		Color(0.18, 0.85, 1.00, 0.98), # Middle bright cyan
		Color(0.88, 0.96, 1.00, 1.00), # Inner pale blue/white
		Color(0.55, 0.92, 1.00, 0.95), # Crisp rim
		Color(0.10, 0.22, 0.45, 0.45)  # Dark socket rim
	)
	
	# 26–50%: Void Violet (Deep Purple -> Violet -> Pink-White)
	_pal_violet = FlamePalette.new(
		Color(0.48, 0.10, 0.88, 0.95), # Outer deep purple
		Color(0.80, 0.28, 1.00, 0.98), # Middle violet
		Color(1.00, 0.88, 0.96, 1.00), # Inner soft pink/white
		Color(0.92, 0.60, 1.00, 0.95), # Crisp rim
		Color(0.30, 0.12, 0.45, 0.45)  # Dark socket rim
	)
	
	# 1–25%: Danger Flame (Deep Red -> Hot Orange -> Bright Yellow-White)
	_pal_danger = FlamePalette.new(
		Color(0.92, 0.08, 0.12, 0.95), # Outer deep red
		Color(1.00, 0.46, 0.06, 0.98), # Middle hot orange
		Color(1.00, 0.95, 0.60, 1.00), # Inner bright yellow/white
		Color(1.00, 0.70, 0.30, 0.95), # Crisp rim
		Color(0.45, 0.12, 0.12, 0.45)  # Dark socket rim
	)

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
	_flicker_time += delta * 4.0
	if _flicker_time > TAU * 10.0:
		_flicker_time -= TAU * 10.0
		
	if _refill_animating:
		_refill_time += delta

	if not _refill_animating:
		_visual_fuel = lerpf(_visual_fuel, _target_fuel, clampf(14.0 * delta, 0.0, 1.0))

	queue_redraw()

## Computes the smoothly blended palette for the current fuel percentage
func get_current_palette(fuel_val: float) -> FlamePalette:
	if _pal_solar == null:
		_init_palettes()
		
	var v = clampf(fuel_val, 0.0, 100.0)
	
	# Smooth transitions around 25%, 50%, and 75% with a 6% blend window
	if v > 78.0:
		return _pal_solar
	elif v >= 72.0:
		var t = smoothstep(72.0, 78.0, v)
		return _pal_plasma.lerp(_pal_solar, t)
	elif v > 53.0:
		return _pal_plasma
	elif v >= 47.0:
		var t = smoothstep(47.0, 53.0, v)
		return _pal_violet.lerp(_pal_plasma, t)
	elif v > 28.0:
		return _pal_violet
	elif v >= 22.0:
		var t = smoothstep(22.0, 28.0, v)
		return _pal_danger.lerp(_pal_violet, t)
	else:
		return _pal_danger

func _draw() -> void:
	var total_w = TOTAL_WIDTH
	var h = size.y
	var start_x = (size.x - total_w) * 0.5
	var cy = h * 0.5
	
	var half_w = FLAME_WIDTH * 0.5
	var half_h = FLAME_HEIGHT * 0.5
	
	var cur_palette = get_current_palette(_visual_fuel)
	
	for i in range(FLAME_COUNT):
		var cx = start_x + float(i) * (FLAME_WIDTH + FLAME_SPACING) + half_w
		
		# Fill factor f for this flame slot in [0.0, 1.0]
		var flame_min = float(i) * 10.0
		var f: float = clampf((_visual_fuel - flame_min) / 10.0, 0.0, 1.0)
		
		_draw_flame(Vector2(cx, cy), half_w, half_h, f, i, cur_palette)

func _draw_flame(center: Vector2, hw: float, hh: float, fill: float, index: int, pal: FlamePalette) -> void:
	var n_pts = FLAME_SHAPE.size()
	var y_base = center.y + hh * 0.95
	
	# Refill ignition wave flare
	var refill_ignite: float = 0.0
	if _refill_animating:
		var wave_pos = (_visual_fuel / 10.0)
		var dist = absf(float(index) - wave_pos)
		if dist < 1.5:
			refill_ignite = (1.5 - dist) / 1.5
	
	# Independent harmonic micro-flicker and breathing per flame
	var phase: float = float(index) * 1.73 + 0.35
	var flicker_x: float = 0.0
	var flicker_y: float = 0.0
	var breathe_w: float = 1.0
	var core_brightness: float = 1.0
	
	if fill > 0.001:
		flicker_x = (sin(_flicker_time * 3.2 + phase) * 0.38 + cos(_flicker_time * 5.1 + phase * 0.7) * 0.16) * fill
		flicker_y = sin(_flicker_time * 2.5 + phase * 1.2) * (0.08 * fill)
		breathe_w = 1.0 + sin(_flicker_time * 2.0 + phase * 0.8) * 0.035
		core_brightness = 0.88 + sin(_flicker_time * 3.6 + phase * 1.4) * 0.12
	
	# 1. Base Empty Flame Socket (strictly inside flame silhouette, no outer blur circles)
	var empty_poly = PackedVector2Array()
	empty_poly.resize(n_pts)
	for k in range(n_pts):
		var pt = FLAME_SHAPE[k]
		empty_poly[k] = Vector2(center.x + pt.x * hw, center.y + pt.y * hh)
		
	var empty_closed = empty_poly.duplicate()
	empty_closed.append(empty_poly[0])
	
	if fill < 0.999:
		# Draw dark unlit socket for empty / unfilled portion
		var soot_col = Color(0.10, 0.08, 0.09, 0.68)
		draw_colored_polygon(empty_poly, soot_col)
		draw_polyline(empty_closed, pal.socket_rim, 1.0, true)
	
	if fill <= 0.001:
		return
		
	var w_scale = (sqrt(fill) * 0.55 + 0.45) * breathe_w
	
	# 2. LAYER 1: OUTER FLAME GLOW BODY
	var outer_poly = PackedVector2Array()
	outer_poly.resize(n_pts)
	for k in range(n_pts):
		var pt = FLAME_SHAPE[k]
		var px = center.x + pt.x * hw * w_scale
		if k == 0:
			px += flicker_x * hw
			
		var py_target = center.y + (pt.y + flicker_y) * hh
		var py = y_base - (y_base - py_target) * fill
		outer_poly[k] = Vector2(px, py)
	
	var outer_col = pal.outer
	if refill_ignite > 0.01:
		outer_col = outer_col.lerp(Color(1.0, 0.98, 0.85, 1.0), refill_ignite * 0.70)
	draw_colored_polygon(outer_poly, outer_col)
	
	# 3. LAYER 2: MIDDLE FLAME BODY (Vibrant Gold / Cyan / Violet / Orange)
	if fill > 0.06:
		var mid_poly = PackedVector2Array()
		mid_poly.resize(n_pts)
		var mid_w = w_scale * 0.70
		var mid_fill_progress = clampf((fill - 0.06) / 0.94, 0.0, 1.0)
		
		for k in range(n_pts):
			var pt = FLAME_SHAPE[k]
			var px = center.x + pt.x * hw * mid_w
			if k == 0:
				px += flicker_x * hw * 0.65
				
			var py_target = center.y + (pt.y * 0.84 + 0.08) * hh
			var py = y_base - (y_base - py_target) * fill
			mid_poly[k] = Vector2(px, py)
			
		var mid_col = pal.middle
		if refill_ignite > 0.01:
			mid_col = mid_col.lerp(Color(1.0, 1.0, 0.95, 1.0), refill_ignite * 0.60)
		draw_colored_polygon(mid_poly, mid_col)
	
	# 4. LAYER 3: INNER CORE (Soft White / Pale Tint with Living Pulse)
	if fill > 0.18:
		var core_poly = PackedVector2Array()
		core_poly.resize(n_pts)
		var core_w = w_scale * 0.40
		var core_fill_progress = clampf((fill - 0.18) / 0.82, 0.0, 1.0)
		
		for k in range(n_pts):
			var pt = FLAME_SHAPE[k]
			var px = center.x + pt.x * hw * core_w
			if k == 0:
				px += flicker_x * hw * 0.35
				
			var py_target = center.y + (pt.y * 0.64 + 0.22) * hh
			var py = y_base - (y_base - py_target) * fill
			core_poly[k] = Vector2(px, py)
			
		var core_col = pal.core
		# Apply living brightness pulse
		core_col.a = clampf(core_col.a * core_brightness * core_fill_progress + refill_ignite * 0.15, 0.0, 1.0)
		draw_colored_polygon(core_poly, core_col)
	
	# 5. LAYER 4: CRISP LUMINOUS RIM CONTOUR
	var fire_closed = outer_poly.duplicate()
	fire_closed.append(outer_poly[0])
	var rim_col = pal.rim
	if refill_ignite > 0.01:
		rim_col = rim_col.lerp(Color(1.0, 1.0, 1.0, 1.0), refill_ignite * 0.70)
	draw_polyline(fire_closed, rim_col, 1.0, true)
