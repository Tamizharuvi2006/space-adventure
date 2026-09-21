extends ParallaxBackground
class_name SolarBackground

# ── Explore Sun V8.1 — Living World Parallax Background ──────────────────────
# 6 parallax layers give strong sense of depth and motion at every speed.
#
# Layer stack (back → front):
#   FarRidge      0.08x — Distant massive mountain range with tall peaks
#   NeedlePillar  0.15x — Isolated thin rock needle spires
#   LandmarkLayer 0.12x — Zone-specific recognizable structures (10 per zone)
#   DistantRidge  0.20x — Mesa plateaus: flat tops + sheer cliff faces
#   MidMountain   0.45x — Pillar spikes, canyon walls, shadow facets
#   CloseFg       0.68x — Large rock masses at bottom only (Y ≥ 510, flight clear)
#
# Public API (unchanged from V8):
#   update_camera_offset(cam_pos)        — called every frame from main.gd
#   apply_zone_visuals_instant(zone)     — instant color switch
#   transition_to_zone(zone, duration)   — animated zone color change
#   notify_pad_changed(pad_idx)          — triggers landmark rebuild per zone

const SunZoneData = preload("res://scripts/planet_data.gd")

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var base_sky_rect:  ColorRect        = $SkyLayer/BaseSkyRect
@onready var sky_rect:       ColorRect        = $SkyLayer/SkyRect
@onready var far_ridge:      Polygon2D        = $FarRidgeLayer/FarRidgePolygon
@onready var landmark_layer: Node             = $LandmarkLayer
@onready var needle_layer:   Node             = $NeedlePillarLayer
@onready var distant_ridge:  Polygon2D        = $DistantRidgeLayer/RidgePolygon
@onready var mid_mountain:   Polygon2D        = $MidMountainLayer/MidPolygon
@onready var close_fg_layer: Node             = $CloseFgLayer
@onready var fg_terrain:     Polygon2D        = $ForegroundLayer/FgPolygon

var sky_material:     ShaderMaterial = null
var current_tween:    Tween          = null
var _active_zone_idx: int            = -1

func _ready() -> void:
	if sky_rect and sky_rect.material:
		sky_material = sky_rect.material.duplicate() as ShaderMaterial
		sky_rect.material = sky_material

	_rebuild_parallax_shapes()

	# Terrain generator owns the foreground mesh — keep hidden here
	if fg_terrain:
		fg_terrain.visible = false

	_update_viewport_layout()
	get_viewport().size_changed.connect(_update_viewport_layout)

	var zone0 = SunZoneData.get_zone_by_index(0)
	apply_zone_visuals_instant(zone0)

func _update_viewport_layout() -> void:
	if not is_inside_tree():
		return
	var vp_size = get_viewport().get_visible_rect().size
	var w := maxf(vp_size.x, 1280.0)
	var h := maxf(vp_size.y, 720.0)
	var margin_x := maxf(w * 3.0, 6000.0)
	var margin_y := maxf(h * 3.0, 3000.0)
	var bg_pos := Vector2(-margin_x, -margin_y)
	var bg_size := Vector2(w + margin_x * 2.0, h + margin_y * 2.0)
	if base_sky_rect:
		base_sky_rect.position = bg_pos
		base_sky_rect.size = bg_size
	if sky_rect:
		sky_rect.position = bg_pos
		sky_rect.size = bg_size
	if sky_material:
		var aspect = vp_size.x / maxf(vp_size.y, 1.0)
		sky_material.set_shader_parameter("aspect_ratio", aspect)

# ── Parallax Shape Profiles ────────────────────────────────────────────────────
func _rebuild_parallax_shapes() -> void:

	# ── LAYER 1: FAR RIDGE (0.08x) ────────────────────────────────────────────
	# Distant massive mountain range with 240px seamless boundary overlap.
	if far_ridge:
		far_ridge.polygon = PackedVector2Array([
			Vector2(-120, 3600), Vector2(-120, 358),
			Vector2(0,    368),
			Vector2(120,  355),  Vector2(260,  338),
			Vector2(380,  270),  # ─ TALL PEAK
			Vector2(460,  302),  Vector2(540,  285),
			Vector2(660,  265),  # ─ TALLEST PEAK
			Vector2(760,  292),  Vector2(860,  318),
			Vector2(980,  338),  Vector2(1100, 325),
			Vector2(1220, 305),  Vector2(1340, 278),  # ─ TALL PEAK
			Vector2(1440, 298),  Vector2(1560, 322),
			Vector2(1680, 345),  Vector2(1800, 328),
			Vector2(1920, 310),  Vector2(2040, 282),  # ─ PEAK
			Vector2(2160, 318),  Vector2(2300, 345),
			Vector2(2440, 358),  Vector2(2560, 368),
			Vector2(2680, 355),
			Vector2(2680, 3600),
		])
		far_ridge.visible = true

	# ── LAYER 2: NEEDLE PILLARS (0.15x) ─────────────────────────────────────
	# Isolated tall rock spires between far ridge and distant mesas.
	# Created dynamically as separate Polygon2D children.
	_build_needle_pillars()

	# ── LAYER 3: DISTANT RIDGE (0.20x) ───────────────────────────────────────
	# Mesa plateaus: flat wide tops + sheer cliff faces with 200px boundary overlap.
	if distant_ridge:
		var ridge_layer = get_node_or_null("DistantRidgeLayer")
		if ridge_layer:
			for child in ridge_layer.get_children():
				if child != distant_ridge:
					child.queue_free()

		distant_ridge.polygon = PackedVector2Array([
			Vector2(-100, 3600), Vector2(-100, 442),
			Vector2(0,    435),
			Vector2(80,   414),
			Vector2(160,  368),  # ─ MESA 1 RAMP UP
			Vector2(230,  336),  # ─ MESA 1 FLAT TOP START (280px wide)
			Vector2(510,  336),  # ─ MESA 1 FLAT TOP END
			Vector2(598,  378),  # ─ CLIFF FACE DROP
			Vector2(678,  430),
			Vector2(780,  462),  # VALLEY FLOOR
			Vector2(882,  440),
			Vector2(960,  402),
			Vector2(1040, 352),  # ─ MESA 2 TOP START (210px)
			Vector2(1250, 352),  # ─ MESA 2 TOP END
			Vector2(1340, 398),  # ─ CLIFF DROP
			Vector2(1430, 450),
			Vector2(1535, 474),  # DEEP VALLEY
			Vector2(1640, 456),
			Vector2(1742, 410),
			Vector2(1824, 362),  # ─ MESA 3 TOP START (210px)
			Vector2(2036, 362),  # ─ MESA 3 TOP END
			Vector2(2132, 410),  # ─ CLIFF DROP
			Vector2(2232, 456),
			Vector2(2340, 464),
			Vector2(2462, 442),
			Vector2(2560, 435),
			Vector2(2640, 414),
			Vector2(2640, 3600),
		])
		distant_ridge.visible = true

	# ── LAYER 4: MID MOUNTAIN (0.45x) ────────────────────────────────────────
	# Pillar spikes, canyon walls, cliff faces with 246px boundary overlap.
	if mid_mountain:
		var mid_layer = get_node_or_null("MidMountainLayer")
		if mid_layer:
			for child in mid_layer.get_children():
				if child != mid_mountain:
					child.queue_free()

		mid_mountain.polygon = PackedVector2Array([
			Vector2(-128, 3600),
			Vector2(-128, 440),
			Vector2(-82,  416),
			Vector2(-20,  464),
			Vector2(0,    488),
			Vector2(62,   470),
			Vector2(118,  432),  # cliff ascent
			Vector2(148,  400),
			Vector2(162,  392),  # ─ PILLAR PEAK A (narrow)
			Vector2(178,  402),
			Vector2(242,  448),
			Vector2(322,  480),
			Vector2(422,  492),
			Vector2(502,  464),
			Vector2(558,  420),
			Vector2(585,  390),  # ─ PILLAR PEAK B
			Vector2(598,  390),
			Vector2(622,  418),
			Vector2(702,  460),
			Vector2(818,  492),
			Vector2(920,  472),
			Vector2(978,  442),
			Vector2(1028, 402),
			Vector2(1044, 384),  # ─ PILLAR PEAK C (narrowest)
			Vector2(1058, 402),
			Vector2(1108, 442),
			Vector2(1202, 476),
			Vector2(1318, 502),
			Vector2(1408, 482),
			Vector2(1468, 448),
			Vector2(1518, 410),  # ─ CANYON WALL
			Vector2(1542, 392),  # ─ WALL TOP
			Vector2(1558, 398),
			Vector2(1602, 442),
			Vector2(1682, 474),
			Vector2(1782, 494),
			Vector2(1872, 472),
			Vector2(1942, 434),
			Vector2(1982, 402),
			Vector2(1998, 386),  # ─ PILLAR PEAK D
			Vector2(2014, 402),
			Vector2(2062, 444),
			Vector2(2162, 484),
			Vector2(2282, 494),
			Vector2(2362, 470),
			Vector2(2432, 440),
			Vector2(2478, 416),
			Vector2(2540, 464),
			Vector2(2560, 488),
			Vector2(2622, 470),
			Vector2(2678, 432),
			Vector2(2678, 3600),
		])
		mid_mountain.visible = true

		# Shadow facets on right faces of pillar peaks
		if mid_layer:
			for sh_pts in [
				PackedVector2Array([Vector2(162,392), Vector2(242,448), Vector2(260,462), Vector2(178,418)]),
				PackedVector2Array([Vector2(598,390), Vector2(702,460), Vector2(720,472), Vector2(614,418)]),
				PackedVector2Array([Vector2(1044,384), Vector2(1108,442), Vector2(1128,454), Vector2(1058,412)]),
				PackedVector2Array([Vector2(1998,386), Vector2(2062,444), Vector2(2082,458), Vector2(2014,414)]),
			]:
				var f := Polygon2D.new()
				f.polygon = sh_pts
				f.color = Color(0, 0, 0, 0.24)
				f.z_index = 2
				mid_layer.add_child(f)

	# ── LAYER 5: CLOSE FOREGROUND (0.68x) ────────────────────────────────────
	# Fast-moving rock masses at BOTTOM ONLY. All top edges ≥ Y=510.
	# Keeps the center flight corridor completely clear.
	_build_close_fg()

# ── Needle Pillars (NeedlePillarLayer 0.15x) ──────────────────────────────────
# 8 isolated thin rock spires tiled across 2560px with boundary overlap.
# Each has a highlight on the left face for depth.
func _build_needle_pillars() -> void:
	if not is_instance_valid(needle_layer):
		return
	for child in needle_layer.get_children():
		child.queue_free()

	var base := Color(0.11, 0.045, 0.030, 0.74)
	# [center_x, peak_y, base_y, top_half_width, base_width]
	var needles: Array = [
		[-174, 346, 484, 9,  24], # ─ Boundary overlap left (2386 - 2560)
		[180,  348, 484, 9,  24],
		[492,  328, 484, 11, 28],
		[748,  358, 484, 8,  20],
		[1052, 338, 484, 10, 26],
		[1354, 324, 484, 12, 30],
		[1704, 352, 484, 9,  22],
		[2058, 335, 484, 10, 26],
		[2386, 346, 484, 9,  24],
		[2740, 348, 484, 9,  24], # ─ Boundary overlap right (2560 + 180)
		[3052, 328, 484, 11, 28], # ─ Boundary overlap right (2560 + 492)
	]
	for nd in needles:
		var cx := float(nd[0])
		var py := float(nd[1])
		var by := float(nd[2])
		var wt := float(nd[3])
		var wb := float(nd[4])

		# Main needle silhouette
		var body := Polygon2D.new()
		body.polygon = PackedVector2Array([
			Vector2(cx - wb * 0.5, by),
			Vector2(cx - wt * 0.5, py + 16),
			Vector2(cx,            py),
			Vector2(cx + wt * 0.5, py + 16),
			Vector2(cx + wb * 0.5, by),
			Vector2(cx + wb * 0.5, 3600),
			Vector2(cx - wb * 0.5, 3600),
		])
		body.color = base
		needle_layer.add_child(body)

		# Lit left face (catches the "sun" from the right)
		var lit := Polygon2D.new()
		lit.polygon = PackedVector2Array([
			Vector2(cx - wb * 0.5, by),
			Vector2(cx - wt * 0.5, py + 16),
			Vector2(cx,            py),
			Vector2(cx - wt * 0.2, py + 22),
			Vector2(cx - wb * 0.35, by),
		])
		lit.color = Color(base.r + 0.07, base.g + 0.025, base.b + 0.015, 0.52)
		needle_layer.add_child(lit)

# ── Close Foreground (CloseFgLayer 0.68x) ─────────────────────────────────────
# 5 large rock masses with boundary overlap. ALL top edges at Y ≥ 510.
# Keeps the center flight corridor completely clear.
func _build_close_fg() -> void:
	if not is_instance_valid(close_fg_layer):
		return
	for child in close_fg_layer.get_children():
		child.queue_free()

	var rock  := Color(0.095, 0.038, 0.022, 0.97)
	var shade := Color(0.055, 0.022, 0.012, 0.94)

	# Formation 1: Wide cliff base — far left with overlap to -120
	_cfp(PackedVector2Array([
		Vector2(-120, 3600), Vector2(-120, 514),
		Vector2(-76,  514),  Vector2(0,    524),
		Vector2(58,   514),  Vector2(148,  516),
		Vector2(228,  512),  Vector2(312,  518),
		Vector2(392,  528),  Vector2(432,  540),
		Vector2(432,  3600),
	]), rock)

	# Formation 2: Overhang boulder — center-left
	_cfp(PackedVector2Array([
		Vector2(510,  3600), Vector2(510,  534),
		Vector2(558,  520),  Vector2(642,  512),
		Vector2(722,  516),  Vector2(792,  522),
		Vector2(852,  542),  Vector2(908,  560),
		Vector2(908,  3600),
	]), rock)
	_cfp(PackedVector2Array([  # undercut shadow
		Vector2(642,  512), Vector2(722, 516), Vector2(715, 528), Vector2(638, 524),
	]), shade)

	# Formation 3: Wide slab — center
	_cfp(PackedVector2Array([
		Vector2(1048, 3600), Vector2(1048, 510),
		Vector2(1088, 510),  Vector2(1128, 516),
		Vector2(1204, 512),  Vector2(1284, 518),
		Vector2(1368, 514),  Vector2(1448, 520),
		Vector2(1448, 3600),
	]), rock)

	# Formation 4: Rocky outcrop — center-right
	_cfp(PackedVector2Array([
		Vector2(1588, 3600), Vector2(1588, 540),
		Vector2(1644, 524),  Vector2(1726, 514),
		Vector2(1806, 514),  Vector2(1888, 520),
		Vector2(1968, 510),  Vector2(2048, 516),
		Vector2(2108, 528),  Vector2(2108, 3600),
	]), rock)
	_cfp(PackedVector2Array([  # shadow under lip
		Vector2(1968, 510), Vector2(2048, 516), Vector2(2042, 528), Vector2(1964, 524),
	]), shade)

	# Formation 5: Flat slab — far right with overlap to 2680
	_cfp(PackedVector2Array([
		Vector2(2208, 3600), Vector2(2208, 528),
		Vector2(2286, 516),  Vector2(2386, 512),
		Vector2(2484, 514),  Vector2(2560, 520),
		Vector2(2618, 514),  Vector2(2680, 516),
		Vector2(2680, 3600),
	]), rock)

func _cfp(pts: PackedVector2Array, col: Color) -> void:
	if not is_instance_valid(close_fg_layer):
		return
	var p := Polygon2D.new()
	p.polygon = pts
	p.color   = col
	close_fg_layer.add_child(p)

# ── Camera Celestial Parallax ─────────────────────────────────────────────────
func update_camera_offset(cam_pos: Vector2) -> void:
	if sky_material:
		var offset := Vector2(
			cam_pos.x * 0.00004,
			clampf((cam_pos.y - 420.0) * 0.00028, -0.22, 0.22)
		)
		sky_material.set_shader_parameter("cam_offset", offset)

# ── Zone Visuals ──────────────────────────────────────────────────────────────
func apply_zone_visuals_instant(zone: Dictionary) -> void:
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	_set_zone_colors(zone)

func _set_zone_colors(zone: Dictionary) -> void:
	var sky_c  := zone.get("sky_color",     Color(0.04, 0.03, 0.08, 1.0)) as Color
	var hor_c  := zone.get("horizon_color", Color(0.24, 0.08, 0.06, 1.0)) as Color
	var bot_c  := zone.get("bottom_color",  Color(0.55, 0.22, 0.08, 1.0)) as Color
	var far_c  := zone.get("far_color",     Color(0.08, 0.030, 0.018, 0.56)) as Color
	var far2_c := zone.get("terrain_far",   Color(0.13, 0.052, 0.030, 0.76)) as Color
	var mid_c  := zone.get("terrain_mid",   Color(0.10, 0.040, 0.026, 0.93)) as Color
	var sun_c  := zone.get("sun_color",     Color(1.0,  0.78,  0.35,  1.0)) as Color
	var haze_i := zone.get("haze_intensity", 0.28) as float

	if base_sky_rect:
		base_sky_rect.color = sky_c
	RenderingServer.set_default_clear_color(sky_c)

	if sky_material:
		sky_material.set_shader_parameter("sky_color",      sky_c)
		sky_material.set_shader_parameter("horizon_color",  hor_c)
		sky_material.set_shader_parameter("bottom_color",   bot_c)
		sky_material.set_shader_parameter("sun_color",      sun_c)
		sky_material.set_shader_parameter("haze_intensity", haze_i)
		if zone.has("sun_radius"):
			sky_material.set_shader_parameter("sun_radius", float(zone["sun_radius"]))

	if far_ridge:     far_ridge.color    = far_c
	if distant_ridge: distant_ridge.color = far2_c
	if mid_mountain:  mid_mountain.color  = mid_c

	# Tint needle pillars to match zone depth
	if is_instance_valid(needle_layer):
		var needle_col := Color(far_c.r * 1.3, far_c.g * 1.3, far_c.b * 1.3, 0.74)
		for child in needle_layer.get_children():
			if child is Polygon2D:
				(child as Polygon2D).color = Color(
					needle_col.r, needle_col.g, needle_col.b, (child as Polygon2D).color.a)

func transition_to_zone(zone: Dictionary, duration: float = 2.0) -> void:
	if current_tween and current_tween.is_valid():
		current_tween.kill()

	current_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var sky_c  := zone.get("sky_color",     Color(0.04, 0.03, 0.08, 1.0)) as Color
	var hor_c  := zone.get("horizon_color", Color(0.24, 0.08, 0.06, 1.0)) as Color
	var bot_c  := zone.get("bottom_color",  Color(0.55, 0.22, 0.08, 1.0)) as Color
	var far_c  := zone.get("far_color",     Color(0.08, 0.030, 0.018, 0.56)) as Color
	var far2_c := zone.get("terrain_far",   Color(0.13, 0.052, 0.030, 0.76)) as Color
	var mid_c  := zone.get("terrain_mid",   Color(0.10, 0.040, 0.026, 0.93)) as Color
	var sun_c  := zone.get("sun_color",     Color(1.0,  0.78,  0.35,  1.0)) as Color

	if base_sky_rect:
		current_tween.tween_property(base_sky_rect, "color", sky_c, duration)
	RenderingServer.set_default_clear_color(sky_c)

	if sky_material:
		current_tween.tween_method(
			func(c: Color): sky_material.set_shader_parameter("sky_color", c),
			sky_material.get_shader_parameter("sky_color"), sky_c, duration)
		current_tween.tween_method(
			func(c: Color): sky_material.set_shader_parameter("horizon_color", c),
			sky_material.get_shader_parameter("horizon_color"), hor_c, duration)
		current_tween.tween_method(
			func(c: Color): sky_material.set_shader_parameter("bottom_color", c),
			sky_material.get_shader_parameter("bottom_color"), bot_c, duration)
		current_tween.tween_method(
			func(c: Color): sky_material.set_shader_parameter("sun_color", c),
			sky_material.get_shader_parameter("sun_color"), sun_c, duration)

	if far_ridge:     current_tween.tween_property(far_ridge,     "color", far_c,  duration)
	if distant_ridge: current_tween.tween_property(distant_ridge, "color", far2_c, duration)
	if mid_mountain:  current_tween.tween_property(mid_mountain,  "color", mid_c,  duration)

# ── Landmark System ───────────────────────────────────────────────────────────
# 10 evenly-spaced slots across the 2560px tile (~256px apart) plus boundary overlap.
# Zone changes trigger a full landmark rebuild.
func notify_pad_changed(pad_idx: int) -> void:
	var zone_idx := SunZoneData.get_zone_index(pad_idx)
	if zone_idx != _active_zone_idx:
		_active_zone_idx = zone_idx
		_rebuild_zone_landmarks(zone_idx)

func _rebuild_zone_landmarks(zone_idx: int) -> void:
	if not is_instance_valid(landmark_layer):
		return
	for child in landmark_layer.get_children():
		child.queue_free()
	# 10 primary slots (~256px apart) + 2 boundary overlap slots (-156.0 and 2660.0)
	var slots: Array = [
		[-156.0, 9],
		[100.0, 0],
		[356.0, 1],
		[612.0, 2],
		[868.0, 3],
		[1124.0, 4],
		[1380.0, 5],
		[1636.0, 6],
		[1892.0, 7],
		[2148.0, 8],
		[2404.0, 9],
		[2660.0, 0],
	]
	for sl in slots:
		_spawn_landmark(zone_idx, float(sl[0]), int(sl[1]))

func _spawn_landmark(zone_idx: int, x: float, slot: int) -> void:
	match zone_idx:
		0: _landmark_solar_valley(x, slot)
		1: _landmark_solar_craters(x, slot)
		2: _landmark_solar_mountains(x, slot)
		3: _landmark_solar_ruins(x, slot)
		4: _landmark_solar_core(x, slot)

# ── Zone 0 — Solar Valley: antennas, spires, outcroppings ────────────────────
func _landmark_solar_valley(x: float, slot: int) -> void:
	var base   := Color(0.20, 0.09, 0.05, 0.90)
	var accent := Color(1.00, 0.62, 0.20, 0.94)
	var rock   := Color(0.28, 0.12, 0.07, 0.86)
	match slot % 5:
		0: # Tall communication tower + cross bars
			_rp(x, 395, 5, 114, base)
			_rp(x - 26, 406, 54, 4, base)
			_rp(x - 18, 432, 38, 3, base)
			_rp(x - 11, 456, 24, 3, base)
			_rp(x - 3,  390, 8,  8, accent)
			_ap(PackedVector2Array([
				Vector2(x+6,  406), Vector2(x+28, 395),
				Vector2(x+32, 406), Vector2(x+13, 420)
			]), base)
			# Guy wires
			_ap(PackedVector2Array([Vector2(x-20,512), Vector2(x-2,492), Vector2(x,496)]),
				Color(base.r, base.g, base.b, 0.52))
			_ap(PackedVector2Array([Vector2(x+20,512), Vector2(x+2,492), Vector2(x,496)]),
				Color(base.r, base.g, base.b, 0.52))

		1: # Dramatic tapered rock spire
			_ap(PackedVector2Array([
				Vector2(x-10, 534), Vector2(x-24, 492), Vector2(x-18, 442),
				Vector2(x-10, 395), Vector2(x,    368),
				Vector2(x+10, 395), Vector2(x+20, 442), Vector2(x+26, 492), Vector2(x+12, 534)
			]), rock)
			_ap(PackedVector2Array([   # shadow — right face
				Vector2(x,    368), Vector2(x+10, 395), Vector2(x+20, 442),
				Vector2(x+26, 492), Vector2(x+16, 502), Vector2(x+8,  450), Vector2(x+2,  396)
			]), Color(0, 0, 0, 0.26))
			_rp(x - 5, 362, 10, 7, accent)  # glowing tip

		2: # Rock outcrop cluster (3 masses, varied heights)
			var heights: Array[float] = [46.0, 62.0, 38.0]
			for i in range(3):
				var ox := x - 30.0 + i * 28.0
				var h: float = heights[i]
				_ap(PackedVector2Array([
					Vector2(ox-15, 534), Vector2(ox-19, 534 - h*0.42),
					Vector2(ox-10, 534 - h), Vector2(ox,    534 - h - 8),
					Vector2(ox+10, 534 - h), Vector2(ox+18, 534 - h*0.42),
					Vector2(ox+14, 534)
				]), Color(rock.r + i*0.018, rock.g + i*0.006, rock.b + i*0.003, 0.86))

		3: # Multi-bar antenna mast with base struts
			_rp(x, 416, 4, 98, base)
			for i in range(5):
				_rp(x - 15, 428 + i*18, 30, 2, base)
			_rp(x - 3, 412, 8, 6, accent)
			_ap(PackedVector2Array([Vector2(x-18,514),Vector2(x-4,504),Vector2(x,508)]), base)
			_ap(PackedVector2Array([Vector2(x+18,514),Vector2(x+4,504),Vector2(x,508)]), base)

		4: # Monitoring station (low-profile, horizontal)
			_rp(x - 32, 504, 66, 16, base)
			_rp(x - 22, 492, 18, 14, Color(base.r+0.06, base.g+0.025, base.b, 0.82))
			_rp(x + 12, 492, 15, 12, Color(base.r+0.06, base.g+0.025, base.b, 0.82))
			_rp(x + 5,  466, 3,  28, base)
			_rp(x - 9,  463, 18, 3,  accent)
			_cp(x + 4, 463, 5, accent)

# ── Zone 1 — Solar Craters: rims, volcanic cones, mineral shards ──────────────
func _landmark_solar_craters(x: float, slot: int) -> void:
	var base := Color(0.155, 0.048, 0.038, 0.90)
	var glow := Color(0.88,  0.40,  0.08,  0.84)
	var rim  := Color(0.225, 0.085, 0.055, 0.88)
	match slot % 5:
		0: # Large crater rim (100px radius)
			_ap(PackedVector2Array([
				Vector2(x-104,534), Vector2(x-104,508), Vector2(x-74,476),
				Vector2(x-44, 460), Vector2(x-18,  452), Vector2(x+18, 452),
				Vector2(x+44, 460), Vector2(x+74, 476), Vector2(x+104,508), Vector2(x+104,534)
			]), rim)
			_ap(PackedVector2Array([   # inner shadow trough
				Vector2(x-76,534), Vector2(x-76,512), Vector2(x-52,482),
				Vector2(x+52,482), Vector2(x+76,512), Vector2(x+76,534)
			]), Color(0, 0, 0, 0.20))
			_ap(PackedVector2Array([   # glowing rim lip
				Vector2(x-18,452), Vector2(x+18,452), Vector2(x+18,460), Vector2(x-18,460)
			]), glow)

		1: # Tall volcanic cone with lava vent
			_ap(PackedVector2Array([
				Vector2(x-48,534), Vector2(x-16,428),
				Vector2(x-8, 400), Vector2(x+8,  400),
				Vector2(x+16,428), Vector2(x+48, 534)
			]), base)
			_ap(PackedVector2Array([   # shadow — right face
				Vector2(x+8, 400), Vector2(x+16, 428), Vector2(x+48, 534),
				Vector2(x+30,534), Vector2(x+8,  434)
			]), Color(0, 0, 0, 0.24))
			_ap(PackedVector2Array([   # vent opening
				Vector2(x-8,400), Vector2(x-4,388), Vector2(x+4,388), Vector2(x+8,400)
			]), glow)
			_rp(x - 3, 382, 6, 6, Color(1.0, 0.90, 0.50, 0.92))

		2: # Mineral shard field (5 shards)
			for i in range(5):
				var ox := x - 40.0 + i * 18.0
				var h  := 30.0 + (i % 3) * 15.0
				_ap(PackedVector2Array([
					Vector2(ox-6, 534), Vector2(ox-2, 534-h),
					Vector2(ox+2, 534-h), Vector2(ox+6, 534)
				]), Color(base.r+0.09, base.g+0.035, base.b+0.020, 0.86))
				_rp(ox-4, 534-h-6, 8, 7, glow)

		3: # Double crater with connecting ridge
			for side in [-1, 1]:
				var ox := x + float(side) * 46.0
				_ap(PackedVector2Array([
					Vector2(ox-46,534), Vector2(ox-46,510), Vector2(ox-26,480),
					Vector2(ox,   464), Vector2(ox+26, 480), Vector2(ox+46,510), Vector2(ox+46,534)
				]), rim)
			_rp(x - 7, 494, 16, 18, rim)

		4: # Fumarole cluster (3 vents)
			for i in range(3):
				var ox := x - 24.0 + i * 24.0
				_ap(PackedVector2Array([
					Vector2(ox-11,534), Vector2(ox-6,492),
					Vector2(ox,   478), Vector2(ox+6,492), Vector2(ox+11,534)
				]), base)
				_rp(ox-5, 472, 10, 7, glow)
				_ap(PackedVector2Array([  # heat shimmer wedge
					Vector2(ox-6,472), Vector2(ox,460), Vector2(ox+6,472)
				]), Color(glow.r, glow.g, glow.b, 0.52))

# ── Zone 2 — Solar Mountains: massive pillars, icy peaks, ridges ──────────────
func _landmark_solar_mountains(x: float, slot: int) -> void:
	var base := Color(0.155, 0.068, 0.195, 0.88)
	var snow := Color(0.88,  0.90,  0.96,  0.94)
	var rock := Color(0.215, 0.095, 0.255, 0.84)
	match slot % 5:
		0: # Massive central pillar with snow cap
			_ap(PackedVector2Array([
				Vector2(x-30,534), Vector2(x-36,480), Vector2(x-26,402),
				Vector2(x-12,374), Vector2(x,    360),
				Vector2(x+12,374), Vector2(x+26, 402), Vector2(x+36,480), Vector2(x+30,534)
			]), base)
			_ap(PackedVector2Array([   # shadow — right face
				Vector2(x+12,374), Vector2(x+26,402), Vector2(x+36,480),
				Vector2(x+25,490), Vector2(x+14,410), Vector2(x+4, 376)
			]), Color(0, 0, 0, 0.26))
			_ap(PackedVector2Array([   # snow cap
				Vector2(x-14,394), Vector2(x-20,386), Vector2(x-12,374),
				Vector2(x,   360), Vector2(x+12,374), Vector2(x+20,386), Vector2(x+14,394)
			]), snow)

		1: # Twin peaks
			for i in range(2):
				var ox   := x - 30.0 + i * 52.0
				var peak := 376.0 - float(i) * 26.0
				_ap(PackedVector2Array([
					Vector2(ox-24,534), Vector2(ox-12,peak+20),
					Vector2(ox,   peak), Vector2(ox+12,peak+20), Vector2(ox+24,534)
				]), base)
				_ap(PackedVector2Array([  # snow tip
					Vector2(ox-7,peak+20), Vector2(ox,peak), Vector2(ox+7,peak+20)
				]), snow)
			# Connecting snow col
			_ap(PackedVector2Array([
				Vector2(x-12,422), Vector2(x+16,422), Vector2(x+12,412), Vector2(x-8,412)
			]), Color(snow.r, snow.g, snow.b, 0.62))

		2: # Stratified cliff face
			_ap(PackedVector2Array([
				Vector2(x-48,534), Vector2(x-54,480), Vector2(x-46,432),
				Vector2(x-34,392), Vector2(x-20,376), Vector2(x+4, 380),
				Vector2(x+18,402), Vector2(x+26,442), Vector2(x+24,534)
			]), base)
			for sy in [424.0, 452.0, 480.0]:
				_rp(x - 32, sy, 52, 2, Color(0, 0, 0, 0.14))
			_ap(PackedVector2Array([  # snow ledge
				Vector2(x-20,376), Vector2(x+4,380), Vector2(x+5,388), Vector2(x-18,384)
			]), snow)

		3: # Ice pillar trio
			var heights: Array[float] = [66.0, 88.0, 54.0]
			for i in range(3):
				var ox := x - 28.0 + float(i) * 26.0
				var h: float = heights[i]
				_ap(PackedVector2Array([
					Vector2(ox-9,534), Vector2(ox-11,534-h*0.5),
					Vector2(ox-4,534-h), Vector2(ox,534-h-14),
					Vector2(ox+4,534-h), Vector2(ox+11,534-h*0.5), Vector2(ox+9,534)
				]), rock)
				_rp(ox-6, 534-h-18, 12, 12, snow)

		4: # Mountain range cluster (5 peaks)
			var pk_data: Array = [[-50,62], [-26,84], [0,72], [26,90], [50,62]]
			for pk in pk_data:
				var ox := x + float(pk[0])
				var h  := float(pk[1])
				_ap(PackedVector2Array([
					Vector2(ox-18,534), Vector2(ox,534-h), Vector2(ox+18,534)
				]), base)
			# Snow on the two tallest
			for peak_x in [x + 26.0, x]:
				_ap(PackedVector2Array([
					Vector2(peak_x-5,534-90), Vector2(peak_x,534-102),
					Vector2(peak_x+5,534-90), Vector2(peak_x+7,534-84)
				]), snow)

# ── Zone 3 — Solar Ruins: collapsed towers, rovers, signal arrays ─────────────
func _landmark_solar_ruins(x: float, slot: int) -> void:
	var base  := Color(0.255, 0.125, 0.048, 0.90)
	var metal := Color(0.565, 0.445, 0.228, 0.86)
	var rust  := Color(0.510, 0.255, 0.055, 0.80)
	var glow  := Color(0.200, 0.760, 0.940, 0.74)
	match slot % 5:
		0: # Tilted collapsed tower (rotated pivot)
			var pivot := Node2D.new()
			pivot.rotation = 0.22
			pivot.position = Vector2(x, 466)
			landmark_layer.add_child(pivot)
			var mast := Polygon2D.new()
			mast.polygon = PackedVector2Array([Vector2(-6,-92),Vector2(6,-92),Vector2(8,0),Vector2(-8,0)])
			mast.color = base
			pivot.add_child(mast)
			for i in range(4):
				var bar := Polygon2D.new()
				bar.polygon = PackedVector2Array([
					Vector2(-24,-66+i*20),Vector2(24,-66+i*20),
					Vector2(24,-61+i*20),Vector2(-24,-61+i*20)
				])
				bar.color = metal
				pivot.add_child(bar)
			var rub := Polygon2D.new()
			rub.polygon = PackedVector2Array([Vector2(-18,0),Vector2(18,0),Vector2(22,14),Vector2(-22,14)])
			rub.color = rust
			pivot.add_child(rub)
			return

		1: # Signal dish on tall mast
			_rp(x, 416, 5, 102, base)
			_ap(PackedVector2Array([
				Vector2(x-32,416), Vector2(x-38,404), Vector2(x-24,386),
				Vector2(x-4, 380), Vector2(x+9, 392), Vector2(x+2, 410), Vector2(x-7,414)
			]), metal)
			_rp(x-4, 413, 7, 5, rust)
			_rp(x-3, 378, 5, 5, glow)
			_ap(PackedVector2Array([Vector2(x-20,518),Vector2(x-2,492),Vector2(x,496)]),
				Color(metal.r, metal.g, metal.b, 0.52))
			_ap(PackedVector2Array([Vector2(x+20,518),Vector2(x+2,492),Vector2(x,496)]),
				Color(metal.r, metal.g, metal.b, 0.52))

		2: # Large rover
			_rp(x-32, 488, 66, 24, base)
			_rp(x-20, 472, 30, 18, Color(base.r+0.06, base.g+0.025, base.b, 0.84))
			for i in range(4):
				_cp(x - 26.0 + float(i) * 15.0, 514, 9, metal)
			_rp(x+16, 458, 2, 20, metal)
			_rp(x+11, 456, 11, 3, metal)
			_rp(x-12, 472, 22, 2, Color(glow.r, glow.g, glow.b, 0.46))

		3: # Crashed debris field
			_ap(PackedVector2Array([
				Vector2(x-44,534), Vector2(x-48,514), Vector2(x-32,502),
				Vector2(x-10,507), Vector2(x+10,503), Vector2(x+32,510), Vector2(x+48,534)
			]), base)
			for i in range(5):
				var ox := x - 32.0 + float(i) * 14.0
				_ap(PackedVector2Array([
					Vector2(ox-5,534), Vector2(ox-6,520),
					Vector2(ox,  516), Vector2(ox+6,520), Vector2(ox+5,534)
				]), rust)
			_rp(x-3, 512, 6, 4, glow)

		4: # Transmission array — 3 dishes
			_rp(x, 434, 5, 84, base)
			var d_heights: Array[float] = [20.0, 28.0, 20.0]
			for di in range(3):
				var ox := x - 30.0 + float(di) * 28.0
				var dh: float = d_heights[di]
				_rp(ox, 476, 4, dh, base)
				_ap(PackedVector2Array([
					Vector2(ox-13,476-dh), Vector2(ox-17,476-dh-9),
					Vector2(ox-8, 476-dh-16), Vector2(ox+5, 476-dh-11), Vector2(ox+2,476-dh)
				]), metal)
			_rp(x-3, 428, 7, 7, glow)

# ── Zone 4 — Solar Core: energy pylons, plasma emitters, solar gates ──────────
func _landmark_solar_core(x: float, slot: int) -> void:
	var base   := Color(0.095, 0.038, 0.020, 0.96)
	var strut  := Color(0.175, 0.068, 0.030, 0.90)
	var energy := Color(0.12,  0.82,  1.00,  0.84)
	var heat   := Color(1.00,  0.48,  0.08,  0.80)
	match slot % 5:
		0: # Full energy pylon with lattice
			_rp(x, 398, 7, 116, base)
			_rp(x-38, 416, 78, 5, strut)
			_rp(x-30, 446, 62, 4, strut)
			_rp(x-22, 474, 46, 3, strut)
			_rp(x-14, 500, 30, 3, strut)
			_ap(PackedVector2Array([Vector2(x-38,420),Vector2(x-4,514),Vector2(x+2,514),Vector2(x-33,420)]), strut)
			_ap(PackedVector2Array([Vector2(x+38,420),Vector2(x+4,514),Vector2(x-2,514),Vector2(x+33,420)]), strut)
			_rp(x-16, 514, 34, 7, energy)
			_rp(x-9,  507, 20, 9, Color(1,1,1,0.58))
			_cp(x+3, 398, 7, energy)

		1: # Massive cliff face with glowing plasma cracks
			_ap(PackedVector2Array([
				Vector2(x-76,534), Vector2(x-84,484), Vector2(x-70,424),
				Vector2(x-52,380), Vector2(x-28,364), Vector2(x+8, 370),
				Vector2(x+36,394), Vector2(x+50,442), Vector2(x+48,534)
			]), base)
			_ap(PackedVector2Array([
				Vector2(x+8, 370), Vector2(x+36,394), Vector2(x+50,442),
				Vector2(x+48,534), Vector2(x+24,534), Vector2(x+6, 450), Vector2(x+2, 380)
			]), Color(0, 0, 0, 0.26))
			_rp(x+6,  398, 2, 56, Color(energy.r, energy.g, energy.b, 0.46))
			_rp(x-16, 426, 2, 40, Color(energy.r, energy.g, energy.b, 0.32))
			_rp(x-2,  454, 2, 26, Color(heat.r,   heat.g,   heat.b,   0.36))

		2: # Plasma emitter row
			for i in range(3):
				var ox := x - 28.0 + float(i) * 26.0
				_rp(ox, 454, 5, 66, base)
				_cp(ox+2, 452, 9, energy)
				_cp(ox+2, 452, 6, Color(1, 1, 1, 0.72))
				_ap(PackedVector2Array([
					Vector2(ox-2,452), Vector2(ox-1,424),
					Vector2(ox+1,424), Vector2(ox+3,452)
				]), Color(energy.r, energy.g, energy.b, 0.30))

		3: # Cooling tower pair
			for i in range(2):
				var ox := x - 22.0 + float(i) * 42.0
				_ap(PackedVector2Array([
					Vector2(ox-18,534), Vector2(ox-22,484), Vector2(ox-15,440),
					Vector2(ox-8, 416), Vector2(ox,   410), Vector2(ox+8, 416),
					Vector2(ox+15,440), Vector2(ox+22,484), Vector2(ox+18,534)
				]), base)
				_ap(PackedVector2Array([  # rim ring
					Vector2(ox-13,410), Vector2(ox+13,410),
					Vector2(ox+15,418), Vector2(ox-15,418)
				]), strut)
				_rp(ox-5, 406, 10, 5, Color(heat.r, heat.g, heat.b, 0.62))

		4: # Ancient Solar Gate — monumental archway
			# Pillars
			_ap(PackedVector2Array([
				Vector2(x-64,534), Vector2(x-64,440), Vector2(x-50,416),
				Vector2(x-38,430), Vector2(x-38,534)
			]), base)
			_ap(PackedVector2Array([
				Vector2(x+38,534), Vector2(x+38,430), Vector2(x+50,416),
				Vector2(x+64,440), Vector2(x+64,534)
			]), base)
			# Lintel + energy arc
			_rp(x-43, 416, 87, 11, base)
			_rp(x-35, 412, 71, 6, energy)
			_rp(x-25, 408, 51, 4, Color(1, 1, 1, 0.72))
			_cp(x+2,  412, 8,  energy)
			# Side buttresses
			_rp(x-55, 438, 4, 50, strut)
			_rp(x+51, 438, 4, 50, strut)

# ── Polygon helpers (write to landmark_layer) ─────────────────────────────────
func _ap(pts: PackedVector2Array, col: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color   = col
	landmark_layer.add_child(p)

func _rp(cx: float, y: float, w: float, h: float, col: Color) -> void:
	_ap(PackedVector2Array([
		Vector2(cx - w * 0.5, y),      Vector2(cx + w * 0.5, y),
		Vector2(cx + w * 0.5, y + h),  Vector2(cx - w * 0.5, y + h)
	]), col)

func _cp(cx: float, cy: float, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var a := (float(i) / 10.0) * TAU
		pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	_ap(pts, col)