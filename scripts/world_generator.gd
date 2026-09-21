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
	var pattern: String = "STRAIGHT_GLIDE"
	var is_milestone: bool = (idx % 10 == 0)

	# ─── 2D Macro Chapters across all 100 Landing Stations ────────────────────
	# 12 Flight Maneuver Archetypes to prevent repetitive one-button drift:
	# STRAIGHT_GLIDE, ASCEND_BRAKE, DESCEND_STABILIZE, LEFT_RIGHT_ZIGZAG,
	# RIGHT_LEFT_ZIGZAG, HIGH_TO_LOW, LOW_TO_HIGH, OFFSET_APPROACH,
	# LONG_GLIDE_LATE_CORRECTION, BRAKING_APPROACH, RECOVERY_PAD, COMBINATION
	match idx:
		# ── Zone 0: SOLAR VALLEY (Pads 1–20) — Broad upward arc climb from Y=480 to Y=55 (Net -425px) ──
		1:  dx = 880.0;  dy = -25.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Valley Awakening";         pattern = "LEVEL_SPRINT"
		2:  dx = 1020.0; dy = -90.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Sunlit Rise";              pattern = "TERRACED_STEP_UP"
		3:  dx = 880.0;  dy = -140.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Verdant Pinnacle";         pattern = "STEEP_HIGH_RIGHT"
		4:  dx = 1250.0; dy = 140.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Valley Gorge Plunge";      pattern = "DEEP_LOW_RIGHT"
		5:  dx = 920.0;  dy = 10.0;   motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Gorge Haven";              pattern = "RECOVERY_PAD"
		6:  dx = 790.0;  dy = -65.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Stepping Stone";           pattern = "SHORT_TECHNICAL_HOP"
		7:  dx = 1450.0; dy = -40.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Breezeway Sprint";         pattern = "RETRO_BRAKE"
		8:  dx = 1120.0; dy = -95.0;  motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Terraced Ridge";          pattern = "TERRACED_STEP_UP"
		9:  dx = 950.0;  dy = 15.0;   motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Quiet Shelf";              pattern = "RECOVERY_PAD"
		10: dx = 2200.0; dy = -20.0;  motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Valley Mid-Spire";         pattern = "ZONE_MILESTONE"; is_milestone = true
		11: dx = 850.0;  dy = -20.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Ridge Overlook";           pattern = "RECOVERY_PAD"
		12: dx = 920.0;  dy = -145.0; motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Cliff Niche Ascent";       pattern = "STEEP_HIGH_RIGHT"
		13: dx = 1320.0; dy = 150.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Ravine Descent";           pattern = "DEEP_LOW_RIGHT"
		14: dx = 1380.0; dy = -10.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Ravine Floor";             pattern = "LEVEL_SPRINT"
		15: dx = 840.0;  dy = 20.0;   motif = SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter = "Pedestal Hop";             pattern = "SHORT_TECHNICAL_HOP"
		16: dx = 1520.0; dy = -50.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Windward Traverse";        pattern = "RETRO_BRAKE"
		17: dx = 950.0;  dy = -15.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Sunlit Rest";              pattern = "RECOVERY_PAD"
		18: dx = 1100.0; dy = -100.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Valley Threshold";        pattern = "TERRACED_STEP_UP"
		19: dx = 1300.0; dy = 85.0;   motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Crest Approach";           pattern = "TERRACED_STEP_DOWN"
		20: dx = 2300.0; dy = -30.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Solar Valley Milestone";   pattern = "ZONE_MILESTONE"; is_milestone = true

		# ── Zone 1: SOLAR CRATERS (Pads 21–40) — Giant Crater Bowl: plunges into basin (Y=540), rises to rim (Y=60) ──
		21: dx = 1180.0; dy =  95.0;  motif = SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter = "Outer Rim Descent";        pattern = "TERRACED_STEP_DOWN"
		22: dx = 1360.0; dy = 165.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Crater Wall Drop";         pattern = "DEEP_LOW_RIGHT"
		23: dx = 980.0;  dy =  20.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Inner Rim Shelf";          pattern = "RECOVERY_PAD"
		24: dx = 860.0;  dy = -15.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Crater Pillar";            pattern = "SHORT_TECHNICAL_HOP"
		25: dx = 1380.0; dy = 170.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Bowl Chasm Plunge";        pattern = "DEEP_LOW_RIGHT"
		26: dx = 1650.0; dy =  30.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Caldera Sprint";           pattern = "RETRO_BRAKE"
		27: dx = 2250.0; dy =  20.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Great Crater Expanse";     pattern = "LONG_GLIDE"
		28: dx = 920.0;  dy = -10.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Deep Basin Haven";         pattern = "RECOVERY_PAD"
		29: dx = 1050.0; dy = -150.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Central Peak Crest";      pattern = "STEEP_HIGH_RIGHT"
		30: dx = 2350.0; dy = -40.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Central Spire Apex";       pattern = "ZONE_MILESTONE"; is_milestone = true
		31: dx = 880.0;  dy =  15.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Crater Plateau";           pattern = "RECOVERY_PAD"
		32: dx = 1400.0; dy = 160.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Crater Trench Plunge";     pattern = "DEEP_LOW_RIGHT"
		33: dx = 1450.0; dy = -15.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Trench Basin Floor";       pattern = "LEVEL_SPRINT"
		34: dx = 850.0;  dy = -35.0;  motif = SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter = "Basin Monolith";           pattern = "SHORT_TECHNICAL_HOP"
		35: dx = 1680.0; dy = -60.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Ejecta Field Traverse";    pattern = "RETRO_BRAKE"
		36: dx = 1020.0; dy = -110.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Wall Terraces";            pattern = "TERRACED_STEP_UP"
		37: dx = 960.0;  dy = -155.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Rimward Escarpment";     pattern = "STEEP_HIGH_RIGHT"
		38: dx = 960.0;  dy =  10.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Lip Sanctuary";            pattern = "RECOVERY_PAD"
		39: dx = 1580.0; dy = -60.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Outer Rampart Run";        pattern = "RETRO_BRAKE"
		40: dx = 2400.0; dy = -30.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Solar Craters Milestone";  pattern = "ZONE_MILESTONE"; is_milestone = true

		# ── Zone 2: SOLAR MOUNTAINS (Pads 41–60) — Alpine Massif: summit horn (Y=-610), couloir descent to pass (Y=-320) ──
		41: dx = 1150.0; dy = -110.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Massif Base Climb";       pattern = "TERRACED_STEP_UP"
		42: dx = 920.0;  dy = -165.0; motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Massif Sheer Face";        pattern = "STEEP_HIGH_RIGHT"
		43: dx = 1220.0; dy =  30.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Alpine Shoulder";          pattern = "TERRACED_STEP_DOWN"
		44: dx = 980.0;  dy = -20.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Alpine Terrace";           pattern = "RECOVERY_PAD"
		45: dx = 890.0;  dy = -40.0;  motif = SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter = "Crevasse Needle";          pattern = "SHORT_TECHNICAL_HOP"
		46: dx = 1080.0; dy = -110.0; motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Glacier Arête";            pattern = "TERRACED_STEP_UP"
		47: dx = 950.0;  dy = -160.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Summit Horn Pinnacle";     pattern = "STEEP_HIGH_RIGHT"
		48: dx = 940.0;  dy = -10.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Serac Rest";               pattern = "RECOVERY_PAD"
		49: dx = 1720.0; dy = -55.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Apex Col Corridor";        pattern = "RETRO_BRAKE"
		50: dx = 2450.0; dy = -30.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Solar Summit Bastion";     pattern = "ZONE_MILESTONE"; is_milestone = true
		51: dx = 900.0;  dy =  10.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Summit Shelf";             pattern = "RECOVERY_PAD"
		52: dx = 1420.0; dy = 190.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Abyss Couloir Plunge";     pattern = "DEEP_LOW_RIGHT"
		53: dx = 1520.0; dy = -10.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Couloir Floor";            pattern = "LEVEL_SPRINT"
		54: dx = 870.0;  dy = -35.0;  motif = SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter = "Frost Spire";              pattern = "SHORT_TECHNICAL_HOP"
		55: dx = 1380.0; dy = 180.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Glacial Gorge Step";       pattern = "DEEP_LOW_RIGHT"
		56: dx = 950.0;  dy =  10.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Mountain Haven";           pattern = "RECOVERY_PAD"
		57: dx = 1100.0; dy = -55.0;  motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Pass Ascent";             pattern = "TERRACED_STEP_UP"
		58: dx = 1360.0; dy =  80.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Mesa Fall";                pattern = "TERRACED_STEP_DOWN"
		59: dx = 1620.0; dy = -50.0;  motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "High Pass Run";            pattern = "RETRO_BRAKE"
		60: dx = 2480.0; dy = -30.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Solar Mountains Milestone"; pattern = "ZONE_MILESTONE"; is_milestone = true

		# ── Zone 3: SOLAR RUINS (Pads 61–80) — Sunken Forum floor (Y=+230), ancient pyramid terraces (Y=-260) ──
		61: dx = 1280.0; dy = 110.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Ruins Colonnade Descent";  pattern = "TERRACED_STEP_DOWN"
		62: dx = 1420.0; dy = 190.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Sunken Vault Abyss";        pattern = "DEEP_LOW_RIGHT"
		63: dx = 990.0;  dy =  20.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Sanctum Terrace";           pattern = "RECOVERY_PAD"
		64: dx = 880.0;  dy = -15.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Pillar Pedestal";           pattern = "SHORT_TECHNICAL_HOP"
		65: dx = 1380.0; dy = 185.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Colosseum Floor Drop";     pattern = "DEEP_LOW_RIGHT"
		66: dx = 1750.0; dy =  40.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Arena Corridor Sprint";     pattern = "RETRO_BRAKE"
		67: dx = 2420.0; dy =  20.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Grand Amphitheater Glide";  pattern = "LONG_GLIDE"
		68: dx = 950.0;  dy = -10.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Sunken Forum Rest";         pattern = "RECOVERY_PAD"
		69: dx = 960.0;  dy = -165.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Pyramid Spire Crest";        pattern = "STEEP_HIGH_RIGHT"
		70: dx = 2480.0; dy = -30.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Megalithic Pyramid Summit"; pattern = "ZONE_MILESTONE"; is_milestone = true
		71: dx = 920.0;  dy =  15.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Upper Bastion Haven";       pattern = "RECOVERY_PAD"
		72: dx = 1450.0; dy = 150.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Catacomb Canyon Chasm";    pattern = "DEEP_LOW_RIGHT"
		73: dx = 1550.0; dy = -15.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Vault Esplanade";           pattern = "LEVEL_SPRINT"
		74: dx = 860.0;  dy = -40.0;  motif = SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter = "Monolith Shelf";            pattern = "SHORT_TECHNICAL_HOP"
		75: dx = 1720.0; dy = -60.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Avenue of Sphinxes";        pattern = "RETRO_BRAKE"
		76: dx = 1120.0; dy = -110.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Apex Tier Rise";            pattern = "TERRACED_STEP_UP"
		77: dx = 940.0;  dy = -155.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Temple Spire Crest";        pattern = "STEEP_HIGH_RIGHT"
		78: dx = 980.0;  dy =  10.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Altar Sanctuary";           pattern = "RECOVERY_PAD"
		79: dx = 1680.0; dy = -55.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Threshold Approach";        pattern = "RETRO_BRAKE"
		80: dx = 2500.0; dy = -25.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Solar Ruins Milestone";     pattern = "ZONE_MILESTONE"; is_milestone = true

		# ── Zone 4: SOLAR CORE (Pads 81–100) — Celestial climb to Apex: Y=-260 to Y=-1260 THE SOLAR CORE APEX ──
		81: dx = 1200.0; dy = -110.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Caldera Rim Uplift";       pattern = "TERRACED_STEP_UP"
		82: dx = 960.0;  dy = -165.0; motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Plasma Column Ascent";      pattern = "STEEP_HIGH_RIGHT"
		83: dx = 1280.0; dy =  30.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Plasma Shoulder Dip";       pattern = "TERRACED_STEP_DOWN"
		84: dx = 1000.0; dy = -15.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Basalt Haven";              pattern = "RECOVERY_PAD"
		85: dx = 890.0;  dy = -40.0;  motif = SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter = "Solar Flare Pedestal";      pattern = "SHORT_TECHNICAL_HOP"
		86: dx = 1750.0; dy = -55.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Molten Plains Sprint";      pattern = "RETRO_BRAKE"
		87: dx = 2450.0; dy = -15.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Corona Sea Traverse";       pattern = "LONG_GLIDE"
		88: dx = 960.0;  dy = -10.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Plasma Shoulder";           pattern = "RECOVERY_PAD"
		89: dx = 980.0;  dy = -160.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Core Spire Apex";          pattern = "STEEP_HIGH_RIGHT"
		90: dx = 2500.0; dy = -30.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Solar Core Spire Summit";   pattern = "ZONE_MILESTONE"; is_milestone = true
		91: dx = 940.0;  dy =  10.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Corona Terrace Haven";      pattern = "RECOVERY_PAD"
		92: dx = 1120.0; dy = -95.0;  motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Corona Steps";              pattern = "TERRACED_STEP_UP"
		93: dx = 1520.0; dy = -20.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Threshold Terrace";        pattern = "LEVEL_SPRINT"
		94: dx = 880.0;  dy = -40.0;  motif = SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter = "Threshold Monolith";        pattern = "SHORT_TECHNICAL_HOP"
		95: dx = 1140.0; dy = -105.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Final Ascent Step";        pattern = "TERRACED_STEP_UP"
		96: dx = 950.0;  dy = -140.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Pinnacle Spire";           pattern = "STEEP_HIGH_RIGHT"
		97: dx = 1350.0; dy =  45.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Apex Terrace Settle";       pattern = "TERRACED_STEP_DOWN"
		98: dx = 990.0;  dy = -10.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Solar Sanctum Sanctuary";   pattern = "RECOVERY_PAD"
		99: dx = 1680.0; dy = -50.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Final Approach Corridor";   pattern = "RETRO_BRAKE"
		100: dx = 2500.0; dy = -25.0; motif = SolarTerrainGenerator.FormationType.MESA;         chapter = "THE SOLAR CORE APEX";       pattern = "ZONE_MILESTONE"; is_milestone = true

		_:
			# Endless play beyond Pad 100
			var cycle = idx % 10
			if cycle < 3:
				dx = 1100.0; dy = -150.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Deep Space Crest"; pattern = "STEEP_HIGH_RIGHT"
			elif cycle < 6:
				dx = 1400.0; dy = 180.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT; chapter = "Cosmic Chasm";       pattern = "DEEP_LOW_RIGHT"
			elif cycle < 8:
				dx = 920.0;  dy = 0.0;    motif = SolarTerrainGenerator.FormationType.MESA; chapter = "Cosmic Haven";              pattern = "RECOVERY_PAD"
			else:
				dx = 2400.0; dy = -20.0;  motif = SolarTerrainGenerator.FormationType.MESA; chapter = "Stellar Expanse";          pattern = "LONG_GLIDE"

	return {
		"dx": dx,
		"dy": dy,
		"motif": motif,
		"chapter": chapter,
		"pattern": pattern,
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

	var best_width: float = randf_range(zone.get("width_min", 140.0), zone.get("width_max", 175.0))
	if bp.pattern == "RECOVERY_PAD":
		best_width = 200.0  # Generous relief pad width (190-210)
	elif is_milestone or next_platform_idx == SunZoneData.TOTAL_PADS:
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
