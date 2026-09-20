extends ParallaxBackground
class_name SolarBackground

# ── Explore Sun V5 — Pure Procedural Vector Parallax Background ───────────────
# Clean, crisp, high-framerate mobile procedural environment.
# Zero giant background images. Built from Godot-native Polygon2D, Line2D,
# procedural shaders, and particle systems for maximum visual control and scale.

const SunZoneData = preload("res://scripts/planet_data.gd")

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var sky_rect: ColorRect        = $SkyLayer/SkyRect
@onready var distant_ridge: Polygon2D   = $DistantRidgeLayer/RidgePolygon
@onready var mid_mountain: Polygon2D    = $MidMountainLayer/MidPolygon
@onready var fg_terrain: Polygon2D      = $ForegroundLayer/FgPolygon
@onready var solar_dust: CPUParticles2D = $SolarWindLayer/SolarDust

var sky_material: ShaderMaterial = null
var current_tween: Tween = null

func _ready() -> void:
	if sky_rect and sky_rect.material:
		sky_material = sky_rect.material.duplicate() as ShaderMaterial
		sky_rect.material = sky_material

	# Rebuild procedural parallax silhouettes
	_rebuild_parallax_shapes()

	# Foreground is handled cleanly by SolarTerrainGenerator
	if fg_terrain:
		fg_terrain.visible = false

	# Adapt to viewport aspect ratio and resolution
	_update_viewport_layout()
	get_viewport().size_changed.connect(_update_viewport_layout)

	# Apply Solar Valley baseline
	var zone0 = SunZoneData.get_zone_by_index(0)
	apply_zone_visuals_instant(zone0)

func _update_viewport_layout() -> void:
	if not is_inside_tree():
		return
	var vp_size = get_viewport().get_visible_rect().size
	if sky_rect:
		sky_rect.position = Vector2.ZERO
		sky_rect.size = Vector2(maxf(vp_size.x, 1280.0), maxf(vp_size.y, 720.0))
	if sky_material:
		var aspect = vp_size.x / maxf(vp_size.y, 1.0)
		sky_material.set_shader_parameter("aspect_ratio", aspect)
	if solar_dust:
		solar_dust.position = vp_size * 0.5
		solar_dust.emission_rect_extents = Vector2(vp_size.x * 0.6, vp_size.y * 0.6)

func _rebuild_parallax_shapes() -> void:
	# ─── 1. Far Mountain Silhouettes (Layer 1 — slow parallax 0.08x) ──────────
	# Multi-tiered stylized mountain silhouettes with atmospheric depth
	if distant_ridge:
		# Tier 1A: Deep background rolling summits
		var pts: PackedVector2Array = [
			Vector2(-120.0, 3600.0),
			Vector2(-120.0, 420.0),
			Vector2(120.0,  370.0),
			Vector2(350.0,  330.0),
			Vector2(600.0,  365.0),
			Vector2(850.0,  310.0),
			Vector2(1100.0, 340.0),
			Vector2(1380.0, 290.0),  # Broad distant summit
			Vector2(1650.0, 335.0),
			Vector2(1920.0, 305.0),
			Vector2(2180.0, 345.0),
			Vector2(2450.0, 320.0),
			Vector2(2680.0, 380.0),
			Vector2(2680.0, 3600.0),
		]
		distant_ridge.polygon = pts
		distant_ridge.visible = true

		var ridge_layer = get_node_or_null("DistantRidgeLayer")
		if ridge_layer:
			# Remove old dynamic children if any
			for child in ridge_layer.get_children():
				if child != distant_ridge:
					child.queue_free()

	# ─── 2. Midground Canyon Formations (Layer 2 — moderate parallax 0.28x) ──
	# Majestic Martian canyon mesas and broad stratified buttes
	if mid_mountain:
		var mid_layer = get_node_or_null("MidMountainLayer")
		if mid_layer:
			for child in mid_layer.get_children():
				if child != mid_mountain:
					child.queue_free()

		var pts_mid: PackedVector2Array = [
			Vector2(-100.0, 3600.0),
			Vector2(-100.0, 490.0),
			Vector2(80.0,   470.0),
			# Mesa 1 (Broad flat-topped plateau)
			Vector2(240.0,  440.0),
			Vector2(320.0,  415.0),
			Vector2(580.0,  415.0),   # Plateau top
			Vector2(660.0,  455.0),
			# Canyon terrace
			Vector2(820.0,  495.0),
			Vector2(980.0,  465.0),
			# Mesa 2 (High canyon bluff)
			Vector2(1120.0, 430.0),
			Vector2(1380.0, 430.0),   # Plateau top
			Vector2(1480.0, 475.0),
			# Valley basin
			Vector2(1680.0, 510.0),
			# Mesa 3 (Stepped plateau)
			Vector2(1880.0, 445.0),
			Vector2(2140.0, 445.0),   # Plateau top
			Vector2(2240.0, 485.0),
			Vector2(2480.0, 465.0),
			Vector2(2680.0, 490.0),
			Vector2(2680.0, 3600.0),
		]
		mid_mountain.polygon = pts_mid
		mid_mountain.visible = true

		if mid_layer:
			# Faceted Shadows on the right-facing flanks of the plateaus
			var facet1 = Polygon2D.new()
			facet1.name = "MidShadow1"
			facet1.polygon = [Vector2(580.0, 415.0), Vector2(660.0, 455.0), Vector2(740.0, 475.0), Vector2(580.0, 455.0)]
			facet1.color = Color(0.0, 0.0, 0.0, 0.18)
			facet1.z_index = 2
			mid_layer.add_child(facet1)

			var facet2 = Polygon2D.new()
			facet2.name = "MidShadow2"
			facet2.polygon = [Vector2(1380.0, 430.0), Vector2(1480.0, 475.0), Vector2(1560.0, 495.0), Vector2(1380.0, 470.0)]
			facet2.color = Color(0.0, 0.0, 0.0, 0.18)
			facet2.z_index = 2
			mid_layer.add_child(facet2)

			var facet3 = Polygon2D.new()
			facet3.name = "MidShadow3"
			facet3.polygon = [Vector2(2140.0, 445.0), Vector2(2240.0, 485.0), Vector2(2320.0, 500.0), Vector2(2140.0, 480.0)]
			facet3.color = Color(0.0, 0.0, 0.0, 0.18)
			facet3.z_index = 2
			mid_layer.add_child(facet3)

# ─── Celestial Parallax Tracking ──────────────────────────────────────────────
func update_camera_offset(cam_pos: Vector2) -> void:
	if sky_material:
		# Subtle celestial parallax: as camera climbs/descends, sun shifts naturally
		var offset = Vector2(
			cam_pos.x * 0.00004,
			clampf((cam_pos.y - 420.0) * 0.00028, -0.22, 0.22)
		)
		sky_material.set_shader_parameter("cam_offset", offset)

# ─── Dynamic Zone Coloring ───────────────────────────────────────────────────
func apply_zone_visuals_instant(zone: Dictionary) -> void:
	if current_tween and current_tween.is_valid():
		current_tween.kill()

	var sky_c = zone.get("sky_color", Color(0.98, 0.52, 0.12, 1.0))
	var hor_c = zone.get("horizon_color", Color(0.85, 0.32, 0.08, 1.0))
	var far_c = zone.get("terrain_far", Color(0.12, 0.05, 0.03, 0.65))
	var mid_c = zone.get("terrain_mid", Color(0.24, 0.10, 0.06, 0.85))
	var sun_c = zone.get("sun_color", Color(1.0, 0.95, 0.82, 1.0))
	var haze_i = zone.get("haze_intensity", 0.35)

	if sky_material:
		sky_material.set_shader_parameter("sky_color", sky_c)
		sky_material.set_shader_parameter("horizon_color", hor_c)
		sky_material.set_shader_parameter("sun_color", sun_c)
		sky_material.set_shader_parameter("haze_intensity", haze_i)

	if distant_ridge: distant_ridge.color = far_c
	if mid_mountain:  mid_mountain.color = mid_c

func transition_to_zone(zone: Dictionary, duration: float = 2.0) -> void:
	if current_tween and current_tween.is_valid():
		current_tween.kill()

	current_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var sky_c = zone.get("sky_color", Color(0.98, 0.52, 0.12, 1.0))
	var hor_c = zone.get("horizon_color", Color(0.85, 0.32, 0.08, 1.0))
	var far_c = zone.get("terrain_far", Color(0.12, 0.05, 0.03, 0.65))
	var mid_c = zone.get("terrain_mid", Color(0.24, 0.10, 0.06, 0.85))
	var sun_c = zone.get("sun_color", Color(1.0, 0.95, 0.82, 1.0))

	if sky_material:
		current_tween.tween_method(
			func(c: Color): sky_material.set_shader_parameter("sky_color", c),
			sky_material.get_shader_parameter("sky_color"), sky_c, duration
		)
		current_tween.tween_method(
			func(c: Color): sky_material.set_shader_parameter("horizon_color", c),
			sky_material.get_shader_parameter("horizon_color"), hor_c, duration
		)
		current_tween.tween_method(
			func(c: Color): sky_material.set_shader_parameter("sun_color", c),
			sky_material.get_shader_parameter("sun_color"), sun_c, duration
		)

	if distant_ridge:
		current_tween.tween_property(distant_ridge, "color", far_c, duration)
	if mid_mountain:
		current_tween.tween_property(mid_mountain, "color", mid_c, duration)
