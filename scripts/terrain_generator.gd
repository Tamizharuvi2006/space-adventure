extends Node2D
class_name SolarTerrainGenerator

# Explore Sun V4.2 — Terrain-to-Pad Integrated Geological Formations
# Landing stations are physically built into distinct geological contexts:
# - Mesa Plateau (Pads on flat elevated plateaus with stepped bedrock terraces)
# - Cliff Shelf (Pads carved into sheer rock walls over yawning canyon chasms)
# - Mountain Ridge Crest (Pads straddling razor-sharp mountain summits)
# - Crater Rim (Pads perched on the rim of deep impact crater bowls)
# - Valley Shelf (Pads nested on elevated benches within deep canyon gorges)
# Visual only — ZERO collision shapes in this generator.
# Background + midground parallax layers stream continuously as player travels.

const SunZoneData = preload("res://scripts/planet_data.gd")

# ─── Formation Types ──────────────────────────────────────────────────────────
enum FormationType { MESA, CLIFF_LEFT, CLIFF_RIGHT, MOUNTAIN_PEAK, CRATER_RIM, VALLEY_SHELF }

# ─── Active chunk tracking ────────────────────────────────────────────────────
var active_chunks: Dictionary = {}         # pad_idx → Node2D (station formations)
var bg_ridge_chunks: Array[Node2D] = []    # recycled background ridge silhouettes
var mid_canyon_chunks: Array[Node2D] = []  # recycled midground canyon wall pieces
var fg_boulder_chunks: Array[Node2D] = []  # recycled foreground boulder clusters

# ─── Streaming state ──────────────────────────────────────────────────────────
var last_bg_x: float = -600.0
var last_mid_x: float = -400.0
var last_fg_x: float = -200.0
var current_zone_idx: int = 0

const BG_CHUNK_WIDTH: float = 520.0    # Width of each background ridge chunk
const MID_CHUNK_WIDTH: float = 380.0   # Width of each midground canyon wall chunk
const FG_CHUNK_WIDTH: float = 260.0    # Width of each foreground boulder cluster

# ─── Lifecycle ────────────────────────────────────────────────────────────────
func clear_all() -> void:
	for idx in active_chunks.keys():
		var chunk = active_chunks[idx]
		if is_instance_valid(chunk):
			chunk.queue_free()
	active_chunks.clear()
	for c in bg_ridge_chunks:
		if is_instance_valid(c): c.queue_free()
	bg_ridge_chunks.clear()
	for c in mid_canyon_chunks:
		if is_instance_valid(c): c.queue_free()
	mid_canyon_chunks.clear()
	for c in fg_boulder_chunks:
		if is_instance_valid(c): c.queue_free()
	fg_boulder_chunks.clear()
	last_bg_x = -600.0
	last_mid_x = -400.0
	last_fg_x = -200.0

# ─── World Streaming (called every frame by WorldGenerator) ───────────────────
func stream_world_chunks(camera_x: float, zone_idx: int) -> void:
	current_zone_idx = zone_idx
	var zone = SunZoneData.get_zone_by_index(zone_idx)

	var half_w = 640.0
	if is_inside_tree() and get_viewport():
		half_w = maxf(640.0, get_viewport().get_visible_rect().size.x * 0.5)

	var view_right = camera_x + half_w + 500.0  # Spawn 500px ahead of visible right edge
	var view_left = camera_x - half_w - 450.0   # Recycle 450px behind visible left edge

	# Note: Mountains and midground mesas stream seamlessly via ParallaxBackground.
	# Canyon geography and talus scree are physically anchored to real bedrock.
	last_fg_x = view_right

	# Recycle chunks far behind camera
	_recycle_streaming_chunks(view_left)

# ─── Background Ridge Silhouettes (Layer 2 — slow parallax) ──────────────────
func _spawn_bg_ridge_chunk(start_x: float, zone: Dictionary) -> void:
	var node = Node2D.new()
	node.name = "BgRidge_%d" % int(start_x)
	node.z_index = -8  # Deep background
	add_child(node)
	bg_ridge_chunks.append(node)

	var col = zone.get("terrain_far", Color(0.12, 0.05, 0.03, 0.65))
	col.a = 0.60 + randf() * 0.15

	var archetype = randi() % 4
	var base_y = 500.0 + randf_range(-30.0, 30.0)
	var w = BG_CHUNK_WIDTH
	var pts: PackedVector2Array

	match archetype:
		0:  # Rolling twin-peak ridge
			pts = [
				Vector2(start_x - 20.0, 720.0),
				Vector2(start_x + w * 0.10, base_y + 90.0),
				Vector2(start_x + w * 0.28, base_y + 20.0),
				Vector2(start_x + w * 0.38, base_y + 55.0),
				Vector2(start_x + w * 0.52, base_y),
				Vector2(start_x + w * 0.68, base_y + 70.0),
				Vector2(start_x + w * 0.85, base_y + 35.0),
				Vector2(start_x + w + 20.0, 720.0),
			]
		1:  # Jagged volcanic massif
			pts = [
				Vector2(start_x - 20.0, 720.0),
				Vector2(start_x + w * 0.18, base_y + 80.0),
				Vector2(start_x + w * 0.35, base_y - 15.0),
				Vector2(start_x + w * 0.44, base_y + 40.0),
				Vector2(start_x + w * 0.60, base_y - 25.0),
				Vector2(start_x + w * 0.76, base_y + 60.0),
				Vector2(start_x + w + 20.0, 720.0),
			]
		2:  # Sloping highland plateau
			pts = [
				Vector2(start_x - 20.0, 720.0),
				Vector2(start_x + w * 0.12, base_y + 75.0),
				Vector2(start_x + w * 0.28, base_y + 15.0),
				Vector2(start_x + w * 0.65, base_y + 8.0),
				Vector2(start_x + w * 0.82, base_y + 55.0),
				Vector2(start_x + w + 20.0, 720.0),
			]
		3:  # Soft eroded dome
			pts = [
				Vector2(start_x - 20.0, 720.0),
				Vector2(start_x + w * 0.15, base_y + 90.0),
				Vector2(start_x + w * 0.35, base_y + 25.0),
				Vector2(start_x + w * 0.50, base_y + 10.0),
				Vector2(start_x + w * 0.70, base_y + 35.0),
				Vector2(start_x + w * 0.88, base_y + 85.0),
				Vector2(start_x + w + 20.0, 720.0),
			]

	var poly = Polygon2D.new()
	poly.polygon = pts
	poly.color = col
	node.add_child(poly)

# ─── Midground Canyon Wall Pieces (Layer 3 — medium parallax) ────────────────
func _spawn_mid_canyon_chunk(start_x: float, zone: Dictionary) -> void:
	var node = Node2D.new()
	node.name = "MidCanyon_%d" % int(start_x)
	node.z_index = -5  # Midground
	add_child(node)
	mid_canyon_chunks.append(node)

	var col = zone.get("terrain_mid", Color(0.25, 0.10, 0.06, 0.85))
	var acc = zone.get("pad_accent_color", Color(1.0, 0.62, 0.1, 1.0))
	var w = MID_CHUNK_WIDTH
	var base_y = 530.0 + randf_range(-25.0, 25.0)

	var pts: PackedVector2Array = [
		Vector2(start_x, 720.0),
		Vector2(start_x + w * 0.06, base_y + 60.0),
		Vector2(start_x + w * 0.22, base_y + 15.0),
		Vector2(start_x + w * 0.55, base_y),
		Vector2(start_x + w * 0.70, base_y + 30.0),
		Vector2(start_x + w * 0.88, base_y + 80.0),
		Vector2(start_x + w, 720.0),
	]

	var poly = Polygon2D.new()
	poly.polygon = pts
	poly.color = col
	node.add_child(poly)

# ─── Foreground Boulder Clusters (Layer 4 — crisp rock details) ──────────────
func _spawn_fg_boulder_cluster(start_x: float, zone: Dictionary) -> void:
	var node = Node2D.new()
	node.name = "FgBoulders_%d" % int(start_x)
	node.z_index = -2
	add_child(node)
	fg_boulder_chunks.append(node)

	var col = zone.get("terrain_fg", Color(0.18, 0.08, 0.05, 0.95))

	var boulder_count = randi_range(2, 3)
	for _b in range(boulder_count):
		var bx = start_x + randf_range(0.0, FG_CHUNK_WIDTH)
		var by = randf_range(580.0, 630.0)
		var bw = randf_range(20.0, 45.0)
		var bh = randf_range(14.0, 26.0)

		var bp: PackedVector2Array = [
			Vector2(bx - bw * 0.5, by),
			Vector2(bx - bw * 0.38, by - bh),
			Vector2(bx - bw * 0.05, by - bh * 1.15),
			Vector2(bx + bw * 0.35, by - bh * 0.90),
			Vector2(bx + bw * 0.5, by - bh * 0.35),
			Vector2(bx + bw * 0.42, by),
		]
		var b_poly = Polygon2D.new()
		b_poly.polygon = bp
		b_poly.color = Color(col.r + randf() * 0.05, col.g + randf() * 0.03, col.b * 0.9, 1.0)
		node.add_child(b_poly)

# ─── Station Formation Builder (V5.1 Stylized Multi-Faceted Geology) ─────────
func build_station_formation(pad: SolarPlatform, formation_type: FormationType = FormationType.MESA) -> void:
	if not is_instance_valid(pad):
		return

	var idx = pad.platform_index
	if active_chunks.has(idx):
		var old = active_chunks[idx]
		if is_instance_valid(old):
			old.queue_free()
		active_chunks.erase(idx)

	var chunk_node = Node2D.new()
	chunk_node.name = "Formation_%d" % idx
	chunk_node.z_index = -1
	add_child(chunk_node)
	active_chunks[idx] = chunk_node

	var pos = pad.global_position
	var w = pad.current_width
	var half_w = w * 0.5

	# Pad foundation footings land at pos.y + 74.0
	var footing_y = pos.y + 74.0
	var abyss_depth_y = 3600.0

	var zone = SunZoneData.get_zone_for_pad(idx)
	var base_rock = zone.get("terrain_fg", Color(0.22, 0.09, 0.05, 1.0))
	base_rock.a = 1.0
	var strata_col = zone.get("pad_accent_color", Color(1.0, 0.65, 0.15, 1.0))
	var dark_rock = Color(base_rock.r * 0.60, base_rock.g * 0.55, base_rock.b * 0.50, 1.0)

	var surface_points: PackedVector2Array
	var far_left: float
	var far_right: float

	match formation_type:
		FormationType.MESA:
			# ── 1. MESA TOP — Expansive horizontal plateau with stepped bedrock terraces ─
			far_left = pos.x - half_w - 240.0
			far_right = pos.x + half_w + 240.0
			var shelf_l = pos.x - half_w - 20.0
			var shelf_r = pos.x + half_w + 20.0

			surface_points = [
				Vector2(far_left, footing_y + 480.0),
				Vector2(far_left + 60.0, footing_y + 340.0),
				Vector2(far_left + 110.0, footing_y + 240.0),
				Vector2(shelf_l - 90.0, footing_y + 160.0),
				Vector2(shelf_l - 45.0, footing_y + 70.0),
				Vector2(shelf_l - 15.0, footing_y + 18.0),
				Vector2(shelf_l, footing_y),                  # Landing shelf start
				Vector2(pos.x - half_w * 0.4, footing_y + 2.0),
				Vector2(pos.x, footing_y),
				Vector2(pos.x + half_w * 0.4, footing_y + 2.0),
				Vector2(shelf_r, footing_y),                  # Landing shelf end
				Vector2(shelf_r + 15.0, footing_y + 18.0),
				Vector2(shelf_r + 45.0, footing_y + 70.0),
				Vector2(shelf_r + 90.0, footing_y + 160.0),
				Vector2(far_right - 110.0, footing_y + 240.0),
				Vector2(far_right - 60.0, footing_y + 340.0),
				Vector2(far_right, footing_y + 480.0),
			]
			_build_faceted_rock_layers(chunk_node, surface_points, far_left, far_right, abyss_depth_y, base_rock, strata_col)
			_add_bedrock_anchor_system(chunk_node, pos.x, footing_y, half_w, base_rock)
			_add_talus_scree(chunk_node, shelf_l - 25.0, shelf_r + 25.0, footing_y, base_rock)

		FormationType.CLIFF_LEFT:
			# ── 2. CLIFF SHELF — Pad carved into sheer rock wall, jutting over canyon chasm ─
			far_left = pos.x - half_w - 90.0
			far_right = pos.x + half_w + 380.0
			var shelf_l = pos.x - half_w - 18.0
			var shelf_r = pos.x + half_w + 14.0

			surface_points = [
				Vector2(far_left - 40.0, footing_y - 160.0),  # High cliff crest towering above pad
				Vector2(far_left - 15.0, footing_y - 110.0),
				Vector2(far_left + 15.0, footing_y - 60.0),
				Vector2(shelf_l - 22.0, footing_y - 18.0),
				Vector2(shelf_l, footing_y),                  # Pad shelf niche
				Vector2(pos.x, footing_y + 1.0),
				Vector2(shelf_r, footing_y),                  # Sheer cantilever shelf edge!
				Vector2(shelf_r + 12.0, footing_y + 55.0),
				Vector2(shelf_r + 25.0, footing_y + 190.0),   # Sheer vertical canyon drop
				Vector2(shelf_r + 45.0, footing_y + 340.0),
				Vector2(shelf_r + 95.0, footing_y + 460.0),   # Canyon talus bench
				Vector2(shelf_r + 170.0, footing_y + 520.0),
				Vector2(shelf_r + 260.0, footing_y + 560.0),  # Deep canyon gorge floor
				Vector2(far_right, footing_y + 600.0),
			]
			_build_faceted_rock_layers(chunk_node, surface_points, far_left - 40.0, far_right, abyss_depth_y, base_rock, strata_col)
			_add_bedrock_anchor_system(chunk_node, pos.x, footing_y, half_w, base_rock)
			_add_thermal_vent(chunk_node, shelf_r + 30.0, footing_y + 195.0)
			_add_talus_scree(chunk_node, shelf_r + 60.0, shelf_r + 220.0, footing_y + 450.0, base_rock)
			_add_chasm_monolith(chunk_node, pos.x + 380.0, footing_y - 45.0, base_rock, strata_col)

		FormationType.MOUNTAIN_PEAK:
			# ── 3. RIDGE CREST — Razor-sharp mountain ridge peak ────────────────────
			far_left = pos.x - half_w - 220.0
			far_right = pos.x + half_w + 220.0
			var shelf_l = pos.x - half_w - 12.0
			var shelf_r = pos.x + half_w + 12.0

			surface_points = [
				Vector2(far_left, footing_y + 520.0),
				Vector2(far_left + 50.0, footing_y + 350.0),
				Vector2(shelf_l - 95.0, footing_y + 200.0),
				Vector2(shelf_l - 40.0, footing_y + 80.0),
				Vector2(shelf_l, footing_y),                  # Ridge crest landing seat
				Vector2(pos.x, footing_y - 5.0),              # Ridge apex under center pylon
				Vector2(shelf_r, footing_y),
				Vector2(shelf_r + 40.0, footing_y + 80.0),
				Vector2(shelf_r + 95.0, footing_y + 200.0),
				Vector2(far_right - 50.0, footing_y + 350.0),
				Vector2(far_right, footing_y + 520.0),
			]
			_build_faceted_rock_layers(chunk_node, surface_points, far_left, far_right, abyss_depth_y, base_rock, strata_col)
			_add_bedrock_anchor_system(chunk_node, pos.x, footing_y, half_w, base_rock)
			_add_talus_scree(chunk_node, shelf_l - 80.0, shelf_r + 80.0, footing_y + 160.0, base_rock)

		FormationType.CRATER_RIM:
			# ── 4. CRATER RIM — High rim overlooking deep inner crater bowl ─────────
			far_left = pos.x - half_w - 180.0
			far_right = pos.x + half_w + 260.0
			var shelf_l = pos.x - half_w - 15.0
			var shelf_r = pos.x + half_w + 15.0

			surface_points = [
				Vector2(far_left, footing_y + 400.0),
				Vector2(far_left + 55.0, footing_y + 220.0),
				Vector2(shelf_l - 60.0, footing_y + 90.0),
				Vector2(shelf_l, footing_y),                  # Crater rim crest
				Vector2(pos.x, footing_y),
				Vector2(shelf_r, footing_y),
				Vector2(shelf_r + 40.0, footing_y + 95.0),    # Steep inner bowl slope
				Vector2(shelf_r + 90.0, footing_y + 210.0),
				Vector2(shelf_r + 150.0, footing_y + 320.0),
				Vector2(far_right, footing_y + 420.0),
			]
			_build_faceted_rock_layers(chunk_node, surface_points, far_left, far_right, abyss_depth_y, base_rock, strata_col)
			_add_crater_bowl_arcs(chunk_node, shelf_r, far_right, footing_y, strata_col)
			_add_bedrock_anchor_system(chunk_node, pos.x, footing_y, half_w, base_rock)
			_add_talus_scree(chunk_node, shelf_r + 30.0, shelf_r + 140.0, footing_y + 180.0, base_rock)

		FormationType.VALLEY_SHELF, _:
			# ── 5. VALLEY SHELF — Elevated rock bench inside a deep canyon basin ───
			far_left = pos.x - half_w - 160.0
			far_right = pos.x + half_w + 200.0
			var shelf_l = pos.x - half_w - 18.0
			var shelf_r = pos.x + half_w + 18.0

			surface_points = [
				Vector2(far_left, footing_y + 420.0),
				Vector2(far_left + 45.0, footing_y + 240.0),
				Vector2(shelf_l - 65.0, footing_y + 95.0),
				Vector2(shelf_l, footing_y),                  # Valley shelf ledge
				Vector2(pos.x, footing_y + 2.0),
				Vector2(shelf_r, footing_y),
				Vector2(shelf_r + 30.0, footing_y + 45.0),
				Vector2(shelf_r + 75.0, footing_y - 25.0),    # Flanking rock pinnacle
				Vector2(shelf_r + 120.0, footing_y + 140.0),
				Vector2(far_right, footing_y + 420.0),
			]
			_build_faceted_rock_layers(chunk_node, surface_points, far_left, far_right, abyss_depth_y, base_rock, strata_col)
			_add_bedrock_anchor_system(chunk_node, pos.x, footing_y, half_w, base_rock)
			_add_talus_scree(chunk_node, shelf_l - 45.0, shelf_r + 45.0, footing_y, base_rock)

# ─── Multi-Faceted Geological Layer Builder ──────────────────────────────────
func _build_faceted_rock_layers(chunk: Node2D, surface_pts: PackedVector2Array, far_left: float, far_right: float, abyss_y: float, rock_col: Color, strata_col: Color) -> void:
	if surface_pts.size() < 2:
		return

	# 1. Base Bedrock Monolith (Continuous solid canyon foundation)
	var body_pts: PackedVector2Array = []
	for p in surface_pts:
		body_pts.append(p)
	body_pts.append(Vector2(far_right, abyss_y))
	body_pts.append(Vector2(far_left, abyss_y))

	var rock = Polygon2D.new()
	rock.name = "RockBody"
	rock.polygon = body_pts
	rock.color = rock_col
	chunk.add_child(rock)

	# 2. Subtle Sunlit Crest (Traces the top surface edge with warm solar illumination)
	var sun_col = Color(
		minf(rock_col.r * 1.25, 1.0),
		minf(rock_col.g * 1.15, 1.0),
		minf(rock_col.b * 1.05, 1.0),
		0.45
	)
	var crest_pts: PackedVector2Array = []
	for p in surface_pts:
		crest_pts.append(p)
	for i in range(surface_pts.size() - 1, -1, -1):
		crest_pts.append(Vector2(surface_pts[i].x, surface_pts[i].y + 14.0))

	var crest = Polygon2D.new()
	crest.name = "CrestHighlight"
	crest.polygon = crest_pts
	crest.color = sun_col
	chunk.add_child(crest)

	# 3. Chiseled Face Shadows on Steeper Flanks
	for i in range(surface_pts.size() - 1):
		var p1 = surface_pts[i]
		var p2 = surface_pts[i + 1]
		# If slope drops downward to the right (cliff flank)
		if p2.y > p1.y + 15.0:
			var flank_pts: PackedVector2Array = [
				p1,
				p2,
				Vector2(p2.x, p2.y + 70.0),
				Vector2(p1.x, p1.y + 70.0)
			]
			var flank = Polygon2D.new()
			flank.name = "FlankShadow_%d" % i
			flank.polygon = flank_pts
			flank.color = Color(0.0, 0.0, 0.0, 0.18)
			chunk.add_child(flank)

# ─── Bedrock Anchor Socket System (physically anchors pad into stone) ─────────
func _add_bedrock_anchor_system(chunk: Node2D, center_x: float, footing_y: float, half_w: float, rock_col: Color) -> void:
	# Left Bedrock Socket
	var l_x = center_x - half_w * 0.65
	var l_pedestal: PackedVector2Array = [
		Vector2(l_x - 30.0, footing_y + 18.0),
		Vector2(l_x - 20.0, footing_y - 14.0),
		Vector2(l_x + 6.0,  footing_y - 14.0),
		Vector2(l_x + 22.0, footing_y + 18.0),
	]
	var l_ped = Polygon2D.new()
	l_ped.name = "AnchorBedrockL"
	l_ped.polygon = l_pedestal
	l_ped.color = Color(rock_col.r * 0.88, rock_col.g * 0.82, rock_col.b * 0.78, 1.0)
	chunk.add_child(l_ped)

	# Left Steel Clamping Collar
	var l_clamp = Polygon2D.new()
	l_clamp.name = "SteelClampL"
	l_clamp.polygon = PackedVector2Array([
		Vector2(l_x - 16.0, footing_y - 14.0),
		Vector2(l_x + 2.0,  footing_y - 14.0),
		Vector2(l_x + 5.0,  footing_y - 4.0),
		Vector2(l_x - 19.0, footing_y - 4.0),
	])
	l_clamp.color = Color(0.26, 0.28, 0.32, 1.0)
	chunk.add_child(l_clamp)

	# Right Bedrock Socket
	var r_x = center_x + half_w * 0.65
	var r_pedestal: PackedVector2Array = [
		Vector2(r_x - 22.0, footing_y + 18.0),
		Vector2(r_x - 6.0,  footing_y - 14.0),
		Vector2(r_x + 20.0, footing_y - 14.0),
		Vector2(r_x + 30.0, footing_y + 18.0),
	]
	var r_ped = Polygon2D.new()
	r_ped.name = "AnchorBedrockR"
	r_ped.polygon = r_pedestal
	r_ped.color = Color(rock_col.r * 0.88, rock_col.g * 0.82, rock_col.b * 0.78, 1.0)
	chunk.add_child(r_ped)

	# Right Steel Clamping Collar
	var r_clamp = Polygon2D.new()
	r_clamp.name = "SteelClampR"
	r_clamp.polygon = PackedVector2Array([
		Vector2(r_x - 2.0,  footing_y - 14.0),
		Vector2(r_x + 16.0, footing_y - 14.0),
		Vector2(r_x + 19.0, footing_y - 4.0),
		Vector2(r_x - 5.0,  footing_y - 4.0),
	])
	r_clamp.color = Color(0.26, 0.28, 0.32, 1.0)
	chunk.add_child(r_clamp)

	# Contact Shadow beneath the platform
	var shadow = Polygon2D.new()
	shadow.name = "StationContactShadow"
	shadow.polygon = PackedVector2Array([
		Vector2(center_x - half_w * 0.85, footing_y + 4.0),
		Vector2(center_x + half_w * 0.85, footing_y + 4.0),
		Vector2(center_x + half_w * 0.75, footing_y + 14.0),
		Vector2(center_x - half_w * 0.75, footing_y + 14.0),
	])
	shadow.color = Color(0.0, 0.0, 0.0, 0.40)
	chunk.add_child(shadow)

# ─── Thermal Dust Fissure Vent ────────────────────────────────────────────────
func _add_thermal_vent(chunk: Node2D, vent_x: float, vent_y: float) -> void:
	var vent = CPUParticles2D.new()
	vent.name = "ThermalVent"
	vent.position = Vector2(vent_x, vent_y)
	vent.amount = 14
	vent.lifetime = 2.4
	vent.speed_scale = 0.9
	vent.explosiveness = 0.05
	vent.direction = Vector2(0.3, -1.0)
	vent.spread = 22.0
	vent.gravity = Vector2(0, -10.0)
	vent.initial_velocity_min = 18.0
	vent.initial_velocity_max = 38.0
	vent.scale_amount_min = 2.0
	vent.scale_amount_max = 4.5
	var grad = Gradient.new()
	grad.add_point(0.0, Color(0.98, 0.75, 0.35, 0.35))
	grad.add_point(0.5, Color(0.92, 0.55, 0.20, 0.20))
	grad.add_point(1.0, Color(0.85, 0.40, 0.15, 0.0))
	vent.color_ramp = grad
	chunk.add_child(vent)

# ─── Loose Talus Scree & Boulders ─────────────────────────────────────────────
func _add_talus_scree(chunk: Node2D, start_x: float, end_x: float, base_y: float, rock_col: Color) -> void:
	var b_col = Color(rock_col.r * 1.12, rock_col.g * 1.06, rock_col.b * 0.95, 1.0)
	var count = 4
	for i in range(count):
		var bx = lerp(start_x, end_x, (i + 0.5) / float(count)) + randf_range(-6.0, 6.0)
		var by = base_y + 4.0 + randf_range(0.0, 10.0)
		var bw = randf_range(10.0, 22.0)
		var bh = randf_range(7.0, 15.0)

		var bp: PackedVector2Array = [
			Vector2(bx - bw * 0.5, by),
			Vector2(bx - bw * 0.3, by - bh),
			Vector2(bx + bw * 0.2, by - bh * 1.1),
			Vector2(bx + bw * 0.5, by - bh * 0.4),
			Vector2(bx + bw * 0.4, by),
		]
		var b_poly = Polygon2D.new()
		b_poly.polygon = bp
		b_poly.color = b_col
		chunk.add_child(b_poly)

func _add_cliff_face_cracks(_chunk: Node2D, _cliff_left: float, _shelf_l: float, _top_y: float, _shelf_y: float, _rock_col: Color) -> void:
	pass

func _add_crater_bowl_arcs(_chunk: Node2D, _rim_x: float, _far_x: float, _deck_y: float, _strata_col: Color) -> void:
	pass

# ─── Canyon Chasm Monolith (rises from deep canyon floor below flight path) ──
func _add_chasm_monolith(chunk: Node2D, center_x: float, peak_y: float, rock_col: Color, _strata_col: Color) -> void:
	var monolith = Node2D.new()
	monolith.name = "ChasmCanyonMonolith"
	monolith.z_index = -2  # Rises from canyon floor below flight path
	chunk.add_child(monolith)

	var abyss_y = peak_y + 700.0
	var w = 220.0
	var pts: PackedVector2Array = [
		Vector2(center_x - w * 0.50, peak_y + 200.0),
		Vector2(center_x - w * 0.35, peak_y + 110.0),
		Vector2(center_x - w * 0.18, peak_y + 25.0),
		Vector2(center_x - w * 0.08, peak_y),         # Pinnacle tip left
		Vector2(center_x + w * 0.08, peak_y),         # Pinnacle tip right
		Vector2(center_x + w * 0.22, peak_y + 40.0),
		Vector2(center_x + w * 0.40, peak_y + 125.0),
		Vector2(center_x + w * 0.55, peak_y + 220.0),
	]

	# Body
	var body_pts: PackedVector2Array = pts.duplicate()
	body_pts.append(Vector2(center_x + w * 0.65, abyss_y))
	body_pts.append(Vector2(center_x - w * 0.65, abyss_y))
	var body = Polygon2D.new()
	body.polygon = body_pts
	body.color = Color(rock_col.r * 1.05, rock_col.g * 1.0, rock_col.b * 0.95, 1.0)
	monolith.add_child(body)

	# Sunlit facet
	var sun_facet = Polygon2D.new()
	sun_facet.polygon = PackedVector2Array([
		pts[0], pts[1], pts[2], pts[3],
		Vector2(center_x, peak_y + 120.0),
		Vector2(center_x - w * 0.35, peak_y + 180.0)
	])
	sun_facet.color = Color(minf(rock_col.r * 1.35, 1.0), minf(rock_col.g * 1.25, 1.0), minf(rock_col.b * 1.10, 1.0), 1.0)
	monolith.add_child(sun_facet)

	# Shadow facet
	var shadow_facet = Polygon2D.new()
	shadow_facet.polygon = PackedVector2Array([
		pts[4], pts[5], pts[6], pts[7],
		Vector2(center_x + w * 0.65, abyss_y),
		Vector2(center_x, abyss_y),
		Vector2(center_x, peak_y + 120.0)
	])
	shadow_facet.color = Color(rock_col.r * 0.55, rock_col.g * 0.50, rock_col.b * 0.48, 1.0)
	monolith.add_child(shadow_facet)

# ─── Start Pad ────────────────────────────────────────────────────────────────
func build_start_pad_foundation(start_pad: SolarPlatform) -> void:
	if not is_instance_valid(start_pad):
		return

	var idx = start_pad.platform_index
	if active_chunks.has(idx):
		var old = active_chunks[idx]
		if is_instance_valid(old):
			old.queue_free()
		active_chunks.erase(idx)

	var chunk_node = Node2D.new()
	chunk_node.name = "StartPlateau_%d" % idx
	chunk_node.z_index = -1
	add_child(chunk_node)
	active_chunks[idx] = chunk_node

	var pos = start_pad.global_position
	var half_w = start_pad.current_width * 0.5
	var footing_y = pos.y + 74.0
	var abyss_depth_y = 3600.0

	var zone = SunZoneData.get_zone_for_pad(idx)
	var base_rock = zone.get("terrain_fg", Color(0.22, 0.09, 0.05, 1.0))
	base_rock.a = 1.0
	var strata_col = zone.get("pad_accent_color", Color(1.0, 0.65, 0.15, 1.0))

	var far_left = -1400.0
	var shelf_l = pos.x - half_w - 20.0
	var shelf_r = pos.x + half_w + 20.0
	var far_right = shelf_r + 45.0

	# Continuous expansive Martian plateau from far off-screen on the left
	var surface_points: PackedVector2Array = [
		Vector2(far_left, footing_y + 80.0),
		Vector2(-900.0,   footing_y + 55.0),
		Vector2(-500.0,   footing_y + 35.0),
		Vector2(-200.0,   footing_y + 15.0),
		Vector2(shelf_l,  footing_y),
		Vector2(pos.x,    footing_y + 1.0),
		Vector2(shelf_r,  footing_y),
		Vector2(far_right, footing_y + 18.0)
	]

	_build_faceted_rock_layers(chunk_node, surface_points, far_left, far_right, abyss_depth_y, base_rock, strata_col)
	_add_bedrock_anchor_system(chunk_node, pos.x, footing_y, half_w, base_rock)

# ─── Continuous Canyon Segment (Bridges Pad A to Pad B seamlessly) ────────────
func build_canyon_segment(pad_a: SolarPlatform, pad_b: SolarPlatform, motif: FormationType = FormationType.MESA) -> void:
	if not is_instance_valid(pad_a) or not is_instance_valid(pad_b):
		return

	var idx_b = pad_b.platform_index
	if active_chunks.has(idx_b):
		var old = active_chunks[idx_b]
		if is_instance_valid(old):
			old.queue_free()
		active_chunks.erase(idx_b)

	var chunk_node = Node2D.new()
	chunk_node.name = "CanyonSegment_%d" % idx_b
	chunk_node.z_index = -1
	add_child(chunk_node)
	active_chunks[idx_b] = chunk_node

	var zone = SunZoneData.get_zone_for_pad(idx_b)
	var base_rock = zone.get("terrain_fg", Color(0.22, 0.09, 0.05, 1.0))
	base_rock.a = 1.0
	var strata_col = zone.get("pad_accent_color", Color(1.0, 0.65, 0.15, 1.0))
	var abyss_depth_y = 3600.0

	var pos_a = pad_a.global_position
	var half_wa = pad_a.current_width * 0.5
	var footing_ya = pos_a.y + 74.0

	var pos_b = pad_b.global_position
	var half_wb = pad_b.current_width * 0.5
	var footing_yb = pos_b.y + 74.0

	var start_x = pos_a.x + half_wa + 15.0
	var shelf_bl = pos_b.x - half_wb - 20.0
	var shelf_br = pos_b.x + half_wb + 20.0
	var end_x = shelf_br + 80.0

	var dx = shelf_bl - start_x
	var max_y = maxf(footing_ya, footing_yb)
	var dip = clampf(dx * 0.12, 35.0, 95.0)

	var surface_points: PackedVector2Array = []
	surface_points.append(Vector2(start_x, footing_ya))
	surface_points.append(Vector2(start_x + 35.0, footing_ya + 20.0))

	match motif:
		FormationType.CLIFF_LEFT:
			surface_points.append(Vector2(start_x + dx * 0.18, footing_ya + dip * 0.40))
			surface_points.append(Vector2(start_x + dx * 0.35, max_y + dip * 0.85))
			surface_points.append(Vector2(start_x + dx * 0.52, max_y + dip))
			surface_points.append(Vector2(start_x + dx * 0.70, max_y + dip * 0.65))
			surface_points.append(Vector2(shelf_bl - 65.0, footing_yb + 65.0))
			surface_points.append(Vector2(shelf_bl - 25.0, footing_yb + 25.0))

		FormationType.MOUNTAIN_PEAK:
			surface_points.append(Vector2(start_x + dx * 0.20, footing_ya + dip * 0.35))
			surface_points.append(Vector2(start_x + dx * 0.45, max_y + dip * 0.75))
			surface_points.append(Vector2(start_x + dx * 0.65, max_y + dip * 0.50))
			surface_points.append(Vector2(shelf_bl - 65.0, footing_yb + 55.0))
			surface_points.append(Vector2(shelf_bl - 25.0, footing_yb + 20.0))

		FormationType.CRATER_RIM:
			surface_points.append(Vector2(start_x + dx * 0.22, footing_ya + dip * 0.30))
			surface_points.append(Vector2(start_x + dx * 0.50, max_y + dip * 0.80))
			surface_points.append(Vector2(start_x + dx * 0.70, max_y + dip * 0.60))
			surface_points.append(Vector2(shelf_bl - 50.0, footing_yb + 40.0))
			surface_points.append(Vector2(shelf_bl - 20.0, footing_yb + 15.0))

		_: # MESA, VALLEY_SHELF
			surface_points.append(Vector2(start_x + dx * 0.18, footing_ya + dip * 0.30))
			surface_points.append(Vector2(start_x + dx * 0.35, max_y + dip * 0.65))
			surface_points.append(Vector2(start_x + dx * 0.52, max_y + dip * 0.85))
			surface_points.append(Vector2(start_x + dx * 0.72, max_y + dip * 0.55))
			surface_points.append(Vector2(shelf_bl - 55.0, footing_yb + 45.0))
			surface_points.append(Vector2(shelf_bl - 20.0, footing_yb + 18.0))

	surface_points.append(Vector2(shelf_bl, footing_yb))
	surface_points.append(Vector2(pos_b.x, footing_yb + 1.0))
	surface_points.append(Vector2(shelf_br, footing_yb))
	surface_points.append(Vector2(shelf_br + 25.0, footing_yb + 20.0))
	surface_points.append(Vector2(end_x, footing_yb + 45.0))

	_build_faceted_rock_layers(chunk_node, surface_points, start_x, end_x, abyss_depth_y, base_rock, strata_col)
	_add_bedrock_anchor_system(chunk_node, pos_b.x, footing_yb, half_wb, base_rock)

	var gorge_floor_x = start_x + dx * 0.50
	var gorge_floor_y = max_y + dip
	_add_talus_scree(chunk_node, gorge_floor_x - 70.0, gorge_floor_x + 70.0, gorge_floor_y, base_rock)

# ─── Backward-compatibility alias ─────────────────────────────────────────────
func build_segment(pad_a: SolarPlatform, pad_b: SolarPlatform) -> void:
	var motif = FormationType.MESA
	match pad_b.platform_index % 5:
		0: motif = FormationType.CLIFF_LEFT
		1: motif = FormationType.MOUNTAIN_PEAK
		2: motif = FormationType.CRATER_RIM
		3: motif = FormationType.VALLEY_SHELF
		4: motif = FormationType.MESA
	build_canyon_segment(pad_a, pad_b, motif)

# ─── Recycling ────────────────────────────────────────────────────────────────
func recycle_chunks_behind(min_pad_idx: int) -> void:
	var to_remove = []
	for idx in active_chunks.keys():
		if idx < min_pad_idx:
			to_remove.append(idx)
	for idx in to_remove:
		var chunk = active_chunks[idx]
		if is_instance_valid(chunk):
			chunk.queue_free()
		active_chunks.erase(idx)

func _recycle_streaming_chunks(view_left: float) -> void:
	var bg_keep: Array[Node2D] = []
	for c in bg_ridge_chunks:
		if is_instance_valid(c):
			if c.position.x + BG_CHUNK_WIDTH < view_left:
				c.queue_free()
			else:
				bg_keep.append(c)
	bg_ridge_chunks = bg_keep

	var mid_keep: Array[Node2D] = []
	for c in mid_canyon_chunks:
		if is_instance_valid(c):
			if c.position.x + MID_CHUNK_WIDTH < view_left:
				c.queue_free()
			else:
				mid_keep.append(c)
	mid_canyon_chunks = mid_keep

	var fg_keep: Array[Node2D] = []
	for c in fg_boulder_chunks:
		if is_instance_valid(c):
			if c.position.x + FG_CHUNK_WIDTH < view_left:
				c.queue_free()
			else:
				fg_keep.append(c)
	fg_boulder_chunks = fg_keep
