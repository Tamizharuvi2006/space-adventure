extends Node2D
class_name WorldGenerator

const SunZoneData = preload("res://scripts/planet_data.gd")
const SolarTerrainGenerator = preload("res://scripts/terrain_generator.gd")

@export var platform_scene: PackedScene
@export var buffer_pads_ahead: int = 10

var active_platforms: Array[SolarPlatform] = []
var terrain_gen: SolarTerrainGenerator = null
var next_platform_idx: int = 0
var last_spawn_pos: Vector2 = Vector2.ZERO

var current_platform: SolarPlatform = null
var next_platform: SolarPlatform = null

const MIN_PLATFORM_CLEARANCE: float = 55.0
var is_debug_labels_enabled: bool = false

# Physics-validated max jump gap (380 px/s × comfortable airtime ≈ 880px max)
const MAX_SAFE_JUMP_GAP: float = 880.0

func get_terrain_surface_y(x: float, zone_idx: int = 0) -> float:
	var zone = SunZoneData.get_zone_by_index(zone_idx)
	var amp = zone.get("terrain_amplitude", 40.0)
	var freq = zone.get("terrain_frequency", 0.004)
	var wrapped_x = fposmod(x, 2560.0)
	return 540.0 + sin(wrapped_x * freq) * amp + cos(wrapped_x * freq * 2.0) * (amp * 0.5)

func _ready() -> void:
	terrain_gen = SolarTerrainGenerator.new()
	terrain_gen.name = "TerrainGenerator"
	add_child(terrain_gen)

func initialize_world(player_ref: Node2D = null) -> SolarPlatform:
	for p in active_platforms:
		if is_instance_valid(p):
			p.queue_free()
	active_platforms.clear()

	next_platform_idx = 0
	last_spawn_pos = Vector2(140.0, 480.0)

	# Start platform
	var start_platform = _spawn_platform(last_spawn_pos, next_platform_idx)
	start_platform.set_platform_width(190.0)
	current_platform = start_platform

	if terrain_gen:
		terrain_gen.clear_all()
		terrain_gen.build_start_pad_foundation(start_platform)

	# Pre-generate forward route
	for i in range(buffer_pads_ahead):
		spawn_next_route_pad()

	if active_platforms.size() > 1:
		next_platform = active_platforms[1]

	update_route_visuals(0)
	print("[WORLD_GEN] Route initialized with %d pads ahead" % active_platforms.size())
	return start_platform

# Called each frame by the main scene with the camera's current world X position
func update_terrain_streaming(camera_x: float) -> void:
	if terrain_gen:
		var zone_idx = SunZoneData.get_zone_index(next_platform_idx)
		terrain_gen.stream_world_chunks(camera_x, zone_idx)

const SolarFlightValidator = preload("res://scripts/flight_validator.gd")

func get_pad_blueprint(idx: int, curr_y: float) -> Dictionary:
	var motif = SolarTerrainGenerator.FormationType.MESA
	var dx: float = 1200.0
	var dy: float = 0.0
	var chapter: String = "Expedition"
	var is_milestone: bool = (idx % 10 == 0)

	# ─── 2D Macro Chapters across all 100 Landing Stations ────────────────────
	# Pacing: short -> medium -> long -> recovery -> long rhythms
	# Total route designed for ~18–20 minute journey
	match idx:
		# ── Zone 0: SOLAR VALLEY (Pads 1–20) — ~3.0–3.5 min ──────────────────
		1:  dx = 950.0;  dy = -50.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Valley Ascent"
		2:  dx = 1200.0; dy = -70.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Valley Ascent"
		3:  dx = 1550.0; dy = -90.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Valley Climb"
		4:  dx = 920.0;  dy = -40.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Valley Shelf"
		5:  dx = 1480.0; dy = -70.0;  motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Valley Ridge"
		6:  dx = 1100.0; dy =  80.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Gorge Entrance"
		7:  dx = 1650.0; dy = 140.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Gorge Descent"
		8:  dx = 950.0;  dy =  70.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Gorge Terrace"
		9:  dx = 1400.0; dy = 110.0;  motif = SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter = "Gorge Floor"
		10: dx = 1750.0; dy = -110.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Valley Crest"; is_milestone = true
		11: dx = 1000.0; dy = -50.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Ridge Trail"
		12: dx = 1450.0; dy = -90.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Ridge Steps"
		13: dx = 1700.0; dy = -120.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "High Arête"
		14: dx = 980.0;  dy = -40.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Arête Shelf"
		15: dx = 1850.0; dy =  20.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "High Traverse"
		16: dx = 1250.0; dy =  40.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Canyon Step"
		17: dx = 1900.0; dy = -30.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Canyon Overlook"
		18: dx = 1050.0; dy =  50.0;  motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Lookout Shelf"
		19: dx = 1450.0; dy =  60.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Milestone Bluff"
		20: dx = 2050.0; dy = -50.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Solar Valley Milestone"; is_milestone = true

		# ── Zone 1: SOLAR CRATERS (Pads 21–40) — ~3.5 min ─────────────────────
		21: dx = 1180.0; dy = -90.0;  motif = SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter = "Crater Rim Climb"
		22: dx = 1600.0; dy = -130.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Outer Wall Ascent"
		23: dx = 2000.0; dy = -150.0; motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Crater Lip"
		24: dx = 1080.0; dy = -60.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Lip Terrace"
		25: dx = 1650.0; dy = -110.0; motif = SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter = "Rim Summit"
		26: dx = 1350.0; dy = 160.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Bowl Plunge"
		27: dx = 2150.0; dy = 210.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Deep Basin Traverse"
		28: dx = 1120.0; dy = 110.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Inner Terraces"
		29: dx = 1800.0; dy = 170.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Crater Basin"
		30: dx = 1300.0; dy =  90.0;  motif = SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter = "Basin Floor"; is_milestone = true
		31: dx = 1250.0; dy = -120.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Central Peak Uplift"
		32: dx = 1750.0; dy = -160.0; motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Central Peak Wall"
		33: dx = 2100.0; dy = -170.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Peak Arête"
		34: dx = 1150.0; dy = -70.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Peak Shoulder"
		35: dx = 1850.0; dy = -130.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Central Summit"
		36: dx = 1380.0; dy =  40.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Outer Wall Exit"
		37: dx = 2200.0; dy = -50.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Wall Expanse"
		38: dx = 1180.0; dy = -60.0;  motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Exit Col"
		39: dx = 1700.0; dy = -70.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Outer Rim"
		40: dx = 2250.0; dy = -50.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Solar Craters Milestone"; is_milestone = true

		# ── Zone 2: SOLAR MOUNTAINS (Pads 41–60) — ~3.8 min ───────────────────
		41: dx = 1280.0; dy = -90.0;  motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Massif Ascent"
		42: dx = 1750.0; dy = -120.0; motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Massif Face"
		43: dx = 2300.0; dy = -150.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Glacier Shoulder"
		44: dx = 1200.0; dy = -60.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "High Plateau"
		45: dx = 1900.0; dy = -130.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Peak Ascent"
		46: dx = 2400.0; dy = -100.0; motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Summit Horn"
		47: dx = 1250.0; dy = -50.0;  motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Solar Summit"
		48: dx = 1950.0; dy =  40.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Summit Plateau"
		49: dx = 1450.0; dy = 160.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Glacial Cirque Plunge"
		50: dx = 2350.0; dy = 210.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Glacial Gorge Expanse"; is_milestone = true
		51: dx = 1220.0; dy = 120.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Ice Canyon Shelf"
		52: dx = 1850.0; dy = 170.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Chasm Shelf"
		53: dx = 2250.0; dy = 120.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Gorge Floor"
		54: dx = 1280.0; dy =  70.0;  motif = SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter = "Valley Basin"
		55: dx = 1500.0; dy = -100.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Razor Ridge"
		56: dx = 2000.0; dy = -140.0; motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Razor Wall"
		57: dx = 2450.0; dy = -130.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Arête Crest"
		58: dx = 1220.0; dy = -60.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Mountain Col"
		59: dx = 1800.0; dy = -90.0;  motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "High Spire"
		60: dx = 2500.0; dy = -50.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Solar Mountains Milestone"; is_milestone = true

		# ── Zone 3: SOLAR RUINS (Pads 61–80) — ~4.0 min ───────────────────────
		61: dx = 1500.0; dy = 140.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Ruins Descent"
		62: dx = 2050.0; dy = 190.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Sunken Terraces"
		63: dx = 2450.0; dy = 220.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Colosseum Abyss"
		64: dx = 1350.0; dy = 120.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Pillar Shelf"
		65: dx = 2150.0; dy = 170.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Sunken Arena"
		66: dx = 2400.0; dy = 140.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Amphitheater"
		67: dx = 1400.0; dy =  80.0;  motif = SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter = "Lower Forum"
		68: dx = 2000.0; dy =  60.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Colosseum Floor"
		69: dx = 1550.0; dy = -100.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Temple Steps"
		70: dx = 2500.0; dy = -130.0; motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Megalithic Pyramid Ascent"; is_milestone = true
		71: dx = 1450.0; dy = -60.0;  motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Pyramid Bastion"
		72: dx = 2100.0; dy = -120.0; motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Pyramid Wall"
		73: dx = 2550.0; dy = -140.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Outer Bastion Climb"
		74: dx = 1400.0; dy = -70.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Bastion Crest"
		75: dx = 2250.0; dy = -110.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Upper Sanctum"
		76: dx = 2500.0; dy = -90.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Sanctum Colonnade"
		77: dx = 1450.0; dy = -50.0;  motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Sun Altar"
		78: dx = 2200.0; dy = -70.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Apex Tier"
		79: dx = 1850.0; dy = -50.0;  motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "High Monolith"
		80: dx = 2600.0; dy = -40.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Solar Ruins Milestone"; is_milestone = true

		# ── Zone 4: SOLAR CORE (Pads 81–100) — ~4.5 min ───────────────────────
		81: dx = 1600.0; dy = 150.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Caldera Plunge"
		82: dx = 2250.0; dy = 200.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Magma Cascades"
		83: dx = 2650.0; dy = 210.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Great Caldera Traversal"
		84: dx = 1450.0; dy = 120.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Basalt Shelf"
		85: dx = 2350.0; dy = 170.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Magma Chasm"
		86: dx = 2600.0; dy = 130.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Lava Floor Flight"
		87: dx = 1500.0; dy =  80.0;  motif = SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter = "Core Basin"
		88: dx = 2150.0; dy =  50.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Molten Plains"
		89: dx = 1650.0; dy = -100.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Core Spire Climb"
		90: dx = 2600.0; dy = -130.0; motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Plasma Spire Summit"; is_milestone = true
		91: dx = 1500.0; dy = -70.0;  motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Plasma Shoulder"
		92: dx = 2250.0; dy = -120.0; motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Solar Column"
		93: dx = 2650.0; dy = -130.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Grand Threshold Traversal"
		94: dx = 1550.0; dy = -70.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Promenade Terrace"
		95: dx = 2400.0; dy = -110.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Corona Obelisk"
		96: dx = 2550.0; dy = -90.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "High Pillar Colonnade"
		97: dx = 1600.0; dy = -60.0;  motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Threshold Spire"
		98: dx = 2500.0; dy = -70.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Apex Gate"
		99: dx = 2000.0; dy = -40.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "The Final Threshold"
		100: dx = 2700.0; dy = -30.0; motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "THE SOLAR CORE APEX"; is_milestone = true

		_:
			# Endless play beyond Pad 100
			var cycle = idx % 10
			if cycle < 4:
				dx = 1600.0; dy = -120.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Deep Space Crest"
			elif cycle < 7:
				dx = 2200.0; dy = 160.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT; chapter = "Cosmic Chasm"
			else:
				dx = 1800.0; dy = -40.0;  motif = SolarTerrainGenerator.FormationType.MESA; chapter = "Stellar Mesa"

	return {
		"dx": dx,
		"dy": dy,
		"motif": motif,
		"chapter": chapter,
		"is_milestone": is_milestone
	}

func spawn_next_route_pad() -> SolarPlatform:
	if next_platform_idx >= SunZoneData.TOTAL_PADS:
		return null
	next_platform_idx += 1
	var prev_pos = last_spawn_pos
	var zone = SunZoneData.get_zone_for_pad(next_platform_idx)

	# Query 2D Route Chapter Planner
	var bp = get_pad_blueprint(next_platform_idx, prev_pos.y)
	var req_dx: float = bp.dx
	var req_dy: float = bp.dy
	var is_milestone: bool = bp.is_milestone or SunZoneData.is_zone_boundary(next_platform_idx)

	var best_width: float = randf_range(zone.get("width_min", 140.0), zone.get("width_max", 180.0))
	if is_milestone or next_platform_idx == SunZoneData.TOTAL_PADS:
		best_width = 210.0  # Celebratory wide milestone platform

	# ─── Numerical Trajectory Simulator Reachability Verification ─────────────
	# Replaces naive formula with numerical Euler flight simulation.
	# Crucial: Unclamped world coordinates! X is progression, Y is macro geography.
	var verified_delta: Vector2 = SolarFlightValidator.solve_safe_jump(req_dx, req_dy, best_width)
	var best_pos = Vector2(prev_pos.x + verified_delta.x, prev_pos.y + verified_delta.y)
	last_spawn_pos = best_pos
	var prev_pad: SolarPlatform = null
	if active_platforms.size() > 0:
		prev_pad = active_platforms[active_platforms.size() - 1]

	var pad = _spawn_platform(best_pos, next_platform_idx)
	pad.set_platform_width(best_width)

	if terrain_gen:
		if prev_pad:
			terrain_gen.build_canyon_segment(prev_pad, pad, bp.motif)
		else:
			terrain_gen.build_station_formation(pad, bp.motif)

	return pad

func _spawn_platform(pos: Vector2, idx: int) -> SolarPlatform:
	var platform: SolarPlatform
	if platform_scene:
		platform = platform_scene.instantiate() as SolarPlatform
	else:
		platform = load("res://scenes/platform.tscn").instantiate() as SolarPlatform

	platform.global_position = pos
	platform.set_index(idx)
	platform.set_debug_labels(is_debug_labels_enabled)
	add_child(platform)
	active_platforms.append(platform)
	return platform

func update_route_visuals(curr_idx: int) -> void:
	for p in active_platforms:
		if not is_instance_valid(p):
			continue
		var diff = p.platform_index - curr_idx
		if diff < 0:
			p.set_visual_role(SolarPlatform.Role.BEHIND)
		elif diff == 0:
			p.set_visual_role(SolarPlatform.Role.CURRENT)
		elif diff == 1:
			p.set_visual_role(SolarPlatform.Role.NEXT)
		else:
			p.set_visual_role(SolarPlatform.Role.FUTURE)

func on_platform_reached(landed_pad: SolarPlatform) -> void:
	current_platform = landed_pad
	var landed_idx = landed_pad.platform_index

	# Determine next route pad (null if landed on or beyond Pad 100)
	if landed_idx >= SunZoneData.TOTAL_PADS:
		next_platform = null
	else:
		next_platform = get_platform_by_index(landed_idx + 1)

	# Update visuals
	update_route_visuals(landed_idx)

	# Stream new route pads ahead deferred to avoid modifying physics tree during query flush
	if is_inside_tree():
		call_deferred("_stream_ahead", landed_idx)
	else:
		_stream_ahead(landed_idx)

func _stream_ahead(curr_idx: int) -> void:
	var target_idx = mini(curr_idx + buffer_pads_ahead, SunZoneData.TOTAL_PADS)
	while next_platform_idx < target_idx:
		var p = spawn_next_route_pad()
		if not p:
			break

	update_route_visuals(curr_idx)
	_recycle_old_pads(curr_idx)

func _recycle_old_pads(curr_idx: int) -> void:
	var to_remove = []
	for p in active_platforms:
		if is_instance_valid(p) and p != current_platform and p != next_platform:
			if p.platform_index < curr_idx - 3:
				to_remove.append(p)

	for p in to_remove:
		active_platforms.erase(p)
		p.queue_free()

	if terrain_gen:
		terrain_gen.recycle_chunks_behind(curr_idx - 2)

func set_active_targets(curr: SolarPlatform, nxt: SolarPlatform) -> void:
	current_platform = curr
	next_platform = nxt
	if is_instance_valid(curr):
		update_route_visuals(curr.platform_index)

func set_debug_labels(enabled: bool) -> void:
	is_debug_labels_enabled = enabled
	for p in active_platforms:
		if is_instance_valid(p):
			p.set_debug_labels(enabled)

func get_platform_by_index(idx: int) -> SolarPlatform:
	if idx > SunZoneData.TOTAL_PADS:
		return null
	for p in active_platforms:
		if is_instance_valid(p) and p.platform_index == idx:
			return p
	return null

func get_highest_platform_index() -> int:
	return next_platform_idx

func ensure_checkpoint_exists(idx: int) -> SolarPlatform:
	if idx > SunZoneData.TOTAL_PADS:
		return null
	var existing = get_platform_by_index(idx)
	if existing:
		return existing
	var target_idx = mini(idx + buffer_pads_ahead, SunZoneData.TOTAL_PADS)
	while next_platform_idx < target_idx:
		var p = spawn_next_route_pad()
		if not p:
			break
	return get_platform_by_index(idx)
