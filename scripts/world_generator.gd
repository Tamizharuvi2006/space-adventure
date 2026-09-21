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

	# ─── 20 MICRO-SCENE LANDSCAPE DESIGN — 100 Landing Stations ─────────────
	# Each group of 5 pads = 1 landscape scene with its own local vertical rhythm.
	# Scenes are stitched together so the world reads as exploration, not a plotted line.
	# Forward progression (dx > 0) guaranteed on all 100 pads.
	# Physics, controls, camera, and fuel mechanics are NOT changed here.
	#
	# ZONES:
	#   Solar Valley  (Pads  1–20) — 4 scenes: Valley Floor, Rising Ridge, Canyon Shelf, Valley Crest
	#   Solar Craters (Pads 21–40) — 4 scenes: Crater Rim, Outer Crater, Deep Basin, Far Rim
	#   Solar Mtns    (Pads 41–60) — 4 scenes: Mountain Base, Sheer Ascent, Summit/Couloir, Mtn Pass
	#   Solar Ruins   (Pads 61–80) — 4 scenes: Ruined Approach, Sunken Forum, Monument Field, Pyramid Terraces
	#   Solar Core    (Pads 81–100)— 4 scenes: Caldera Rim, Plasma Valley, Core Ascent, Solar Core Apex
	match idx:
		# ══════════════════════════════════════════════════════════════════════
		# ZONE 0: SOLAR VALLEY (Pads 1–20)
		# Macro neighbourhood: Y≈400–620 (local humps, no macro drift)
		# ══════════════════════════════════════════════════════════════════════

		# ── SCENE 01: Valley Floor (Pads 1–5) ──────────────────────────────
		# Broad flat basin. Short hop → mesa rise → long glide off mesa → settle.
		# Silhouette: flat ──●── ●──── /●\ ─────● ──●
		1:  dx = 820.0;  dy =  20.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Valley Floor Entry";       pattern = "SHORT_TECHNICAL_HOP"
		2:  dx = 980.0;  dy = -95.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Valley Mesa Rise";         pattern = "TERRACED_STEP_UP"
		3:  dx = 1420.0; dy =  60.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Mesa Glide Off";           pattern = "DEEP_LOW_RIGHT"
		4:  dx = 1060.0; dy = -25.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Valley Shelf Settle";      pattern = "LEVEL_SPRINT"
		5:  dx = 880.0;  dy =  15.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Valley Floor Rest";        pattern = "RECOVERY_PAD"

		# ── SCENE 02: Rising Ridge (Pads 6–10) ─────────────────────────────
		# Stepwise ascent to a ridge crest then a long milestone traverse.
		# Silhouette: ●─ /● /● ────● ──────────●
		6:  dx = 860.0;  dy = -55.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Ridge Foot Climb";         pattern = "SHORT_TECHNICAL_HOP"
		7:  dx = 1060.0; dy = -110.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Ridge Step Up";            pattern = "TERRACED_STEP_UP"
		8:  dx = 1480.0; dy = -35.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "High Ridge Traverse";      pattern = "RETRO_BRAKE"
		9:  dx = 920.0;  dy =  80.0;  motif = SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter = "Ridge Saddle Dip";         pattern = "RECOVERY_PAD"
		10: dx = 2200.0; dy = -15.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Valley Mid-Spire";         pattern = "ZONE_MILESTONE"; is_milestone = true

		# ── SCENE 03: Canyon Shelf (Pads 11–15) ────────────────────────────
		# Enter canyon → deep drop → shelf ledge → climb out → technical hop out.
		# Silhouette: ●─ \● \──●── /● ●
		11: dx = 860.0;  dy =  85.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Canyon Entry Drop";        pattern = "TERRACED_STEP_DOWN"
		12: dx = 950.0;  dy =  140.0; motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Canyon Deep Plunge";       pattern = "DEEP_LOW_RIGHT"
		13: dx = 1000.0; dy = -15.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Canyon Shelf Ledge";       pattern = "LEVEL_SPRINT"
		14: dx = 1100.0; dy = -120.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Shelf Climb Out";          pattern = "TERRACED_STEP_UP"
		15: dx = 880.0;  dy =  25.0;  motif = SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter = "Canyon Rim Hop";           pattern = "SHORT_TECHNICAL_HOP"

		# ── SCENE 04: Valley Crest (Pads 16–20) ────────────────────────────
		# Broad crest approach → steep ascent → crest rest → long retro-brake → zone exit.
		# Silhouette: ──● /● ─● ──────● ──────────●
		16: dx = 1400.0; dy = -50.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Crest Approach Traverse";  pattern = "RETRO_BRAKE"
		17: dx = 920.0;  dy = -130.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Crest Steep Ascent";       pattern = "STEEP_HIGH_RIGHT"
		18: dx = 970.0;  dy =  20.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Crest Shelf Rest";         pattern = "RECOVERY_PAD"
		19: dx = 1680.0; dy = -40.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Crest Long Brake Run";     pattern = "RETRO_BRAKE"
		20: dx = 2250.0; dy =  15.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Solar Valley Milestone";   pattern = "ZONE_MILESTONE"; is_milestone = true

		# ══════════════════════════════════════════════════════════════════════
		# ZONE 1: SOLAR CRATERS (Pads 21–40)
		# Macro neighbourhood: Y≈380–760 (enter rim, descend to basin, climb back)
		# ══════════════════════════════════════════════════════════════════════

		# ── SCENE 05: Crater Rim (Pads 21–25) ──────────────────────────────
		# Step onto rim, rim-hop, short drop into outer bowl.
		# Silhouette: ●─ ●\ ─● ●─ \────●
		21: dx = 860.0;  dy =  50.0;  motif = SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter = "Crater Rim Entry";         pattern = "TERRACED_STEP_DOWN"
		22: dx = 1100.0; dy =  90.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Rim Wall Descent";         pattern = "DEEP_LOW_RIGHT"
		23: dx = 960.0;  dy =  15.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Rim Ledge Rest";           pattern = "RECOVERY_PAD"
		24: dx = 840.0;  dy = -20.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Crater Rim Pillar";        pattern = "SHORT_TECHNICAL_HOP"
		25: dx = 1480.0; dy =  120.0; motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Outer Bowl Drop";          pattern = "DEEP_LOW_RIGHT"

		# ── SCENE 06: Outer Crater (Pads 26–30) ────────────────────────────
		# Broad descent into bowl → flat basin sprint → central peak ascent.
		# Silhouette: \● ────────────● ─● /● ────────/●
		26: dx = 1100.0; dy =  110.0; motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Bowl Descent";             pattern = "TERRACED_STEP_DOWN"
		27: dx = 2250.0; dy =  25.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Crater Basin Long Glide";  pattern = "LONG_GLIDE"
		28: dx = 920.0;  dy =  10.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Basin Floor Rest";         pattern = "RECOVERY_PAD"
		29: dx = 1060.0; dy = -130.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Central Peak Crest";       pattern = "STEEP_HIGH_RIGHT"
		30: dx = 2300.0; dy = -50.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Central Spire Apex";       pattern = "ZONE_MILESTONE"; is_milestone = true

		# ── SCENE 07: Deep Basin (Pads 31–35) ──────────────────────────────
		# Rest on peak → trench plunge → basin floor sprint → monolith hop → ejecta traverse.
		# Silhouette: ─● \────● ─────────● ─● ──────────●
		31: dx = 860.0;  dy =  20.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Crater Peak Rest";         pattern = "RECOVERY_PAD"
		32: dx = 1380.0; dy =  150.0; motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Trench Plunge";            pattern = "DEEP_LOW_RIGHT"
		33: dx = 1450.0; dy = -10.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Trench Basin Sprint";      pattern = "LEVEL_SPRINT"
		34: dx = 840.0;  dy = -30.0;  motif = SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter = "Basin Monolith Hop";       pattern = "SHORT_TECHNICAL_HOP"
		35: dx = 1600.0; dy = -55.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Ejecta Field Traverse";    pattern = "RETRO_BRAKE"

		# ── SCENE 08: Far Rim (Pads 36–40) ─────────────────────────────────
		# Escarpment terrace step-up → steep rimward climb → rim rest → retro-brake exit.
		# Silhouette: /● /● ─● ──────● ──────────●
		36: dx = 980.0;  dy = -110.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Far Wall Terraces";        pattern = "TERRACED_STEP_UP"
		37: dx = 940.0;  dy = -145.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Rimward Escarpment";       pattern = "STEEP_HIGH_RIGHT"
		38: dx = 960.0;  dy =  10.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Crater Rim Sanctuary";     pattern = "RECOVERY_PAD"
		39: dx = 1550.0; dy = -55.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Outer Rampart Run";        pattern = "RETRO_BRAKE"
		40: dx = 2350.0; dy = -25.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Solar Craters Milestone";  pattern = "ZONE_MILESTONE"; is_milestone = true

		# ══════════════════════════════════════════════════════════════════════
		# ZONE 2: SOLAR MOUNTAINS (Pads 41–60)
		# Macro neighbourhood: Y≈60–400 (foothills → summit → couloir → pass)
		# ══════════════════════════════════════════════════════════════════════

		# ── SCENE 09: Mountain Base (Pads 41–45) ────────────────────────────
		# Foothills approach → sheer cliff face → alpine shoulder → terrace rest → crevasse needle.
		# Silhouette: ─● /● ●\ ─● ─●
		41: dx = 1100.0; dy = -100.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Massif Base Climb";        pattern = "TERRACED_STEP_UP"
		42: dx = 920.0;  dy = -155.0; motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Sheer Cliff Face";         pattern = "STEEP_HIGH_RIGHT"
		43: dx = 1200.0; dy =  30.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Alpine Shoulder Dip";      pattern = "TERRACED_STEP_DOWN"
		44: dx = 960.0;  dy = -15.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Alpine Terrace Rest";      pattern = "RECOVERY_PAD"
		45: dx = 880.0;  dy = -40.0;  motif = SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter = "Crevasse Needle";          pattern = "SHORT_TECHNICAL_HOP"

		# ── SCENE 10: Sheer Ascent (Pads 46–50) ─────────────────────────────
		# Glacier arête → summit push → summit rest → apex col corridor → milestone bastion.
		# Silhouette: /● /● ─● ──────● ──────────────●
		46: dx = 1050.0; dy = -105.0; motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Glacier Arête";            pattern = "TERRACED_STEP_UP"
		47: dx = 950.0;  dy = -150.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Summit Horn Push";         pattern = "STEEP_HIGH_RIGHT"
		48: dx = 940.0;  dy =  45.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Summit Serac Rest";        pattern = "RECOVERY_PAD"
		49: dx = 1680.0; dy = -80.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Apex Col Corridor";        pattern = "RETRO_BRAKE"
		50: dx = 2400.0; dy = -25.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Solar Summit Bastion";     pattern = "ZONE_MILESTONE"; is_milestone = true

		# ── SCENE 11: Summit & Couloir (Pads 51–55) ─────────────────────────
		# Summit shelf → big couloir plunge → floor sprint → frost spire hop → second drop.
		# Silhouette: ─● \──────● ───────────● ─● \──────●
		51: dx = 880.0;  dy =  10.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Summit Shelf";             pattern = "RECOVERY_PAD"
		52: dx = 1380.0; dy =  180.0; motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Couloir Plunge";           pattern = "DEEP_LOW_RIGHT"
		53: dx = 1500.0; dy = -10.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Couloir Floor Sprint";     pattern = "LEVEL_SPRINT"
		54: dx = 860.0;  dy = -30.0;  motif = SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter = "Frost Spire Hop";          pattern = "SHORT_TECHNICAL_HOP"
		55: dx = 1350.0; dy =  165.0; motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Glacial Gorge Step";       pattern = "DEEP_LOW_RIGHT"

		# ── SCENE 12: Mountain Pass (Pads 56–60) ────────────────────────────
		# Recovery haven → pass step-up → mesa fall → high-pass retro-brake → milestone exit.
		# Silhouette: ─● /● \── ──────● ──────────────●
		56: dx = 940.0;  dy =  10.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Mountain Haven";           pattern = "RECOVERY_PAD"
		57: dx = 1080.0; dy = -50.0;  motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Pass Ascent Step";         pattern = "TERRACED_STEP_UP"
		58: dx = 1340.0; dy =  75.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Pass Mesa Fall";           pattern = "TERRACED_STEP_DOWN"
		59: dx = 1580.0; dy = -45.0;  motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "High Pass Brake Run";      pattern = "RETRO_BRAKE"
		60: dx = 2450.0; dy = -25.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Solar Mountains Milestone"; pattern = "ZONE_MILESTONE"; is_milestone = true

		# ══════════════════════════════════════════════════════════════════════
		# ZONE 3: SOLAR RUINS (Pads 61–80)
		# Macro neighbourhood: Y≈80–600 (colonnade → sunken forum → monuments → pyramid)
		# ══════════════════════════════════════════════════════════════════════

		# ── SCENE 13: Ruined Approach (Pads 61–65) ──────────────────────────
		# Colonnade drop → sunken vault deeper → sanctum rest → pillar hop → colosseum plunge.
		# Silhouette: ●\ \──● ─● ─● \──────────●
		61: dx = 1250.0; dy =  100.0; motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Colonnade Descent";        pattern = "TERRACED_STEP_DOWN"
		62: dx = 1380.0; dy =  175.0; motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Sunken Vault Abyss";       pattern = "DEEP_LOW_RIGHT"
		63: dx = 980.0;  dy =  15.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Sanctum Terrace";          pattern = "RECOVERY_PAD"
		64: dx = 860.0;  dy = -20.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Pillar Pedestal Hop";      pattern = "SHORT_TECHNICAL_HOP"
		65: dx = 1350.0; dy =  170.0; motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Colosseum Floor Drop";     pattern = "DEEP_LOW_RIGHT"

		# ── SCENE 14: Sunken Forum (Pads 66–70) ─────────────────────────────
		# Arena sprint → amphitheatre long glide → forum rest → pyramid spire ascent → milestone.
		# Silhouette: ──────● ──────────────────● ─● /● ──────────────●
		66: dx = 1700.0; dy =  35.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Arena Corridor Sprint";    pattern = "RETRO_BRAKE"
		67: dx = 2350.0; dy =  20.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Grand Amphitheatre Glide"; pattern = "LONG_GLIDE"
		68: dx = 940.0;  dy = -10.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Sunken Forum Rest";        pattern = "RECOVERY_PAD"
		69: dx = 950.0;  dy = -155.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Pyramid Spire Crest";      pattern = "STEEP_HIGH_RIGHT"
		70: dx = 2450.0; dy = -30.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Megalithic Pyramid Summit"; pattern = "ZONE_MILESTONE"; is_milestone = true

		# ── SCENE 15: Monument Field (Pads 71–75) ────────────────────────────
		# Upper bastion rest → catacomb chasm drop → vault esplanade sprint → monolith hop → avenue brake.
		# Silhouette: ─● \──────● ─────────── ─● ──────────●
		71: dx = 900.0;  dy =  15.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Upper Bastion Haven";      pattern = "RECOVERY_PAD"
		72: dx = 1420.0; dy =  140.0; motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Catacomb Chasm Drop";      pattern = "DEEP_LOW_RIGHT"
		73: dx = 1520.0; dy = -10.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Vault Esplanade Sprint";   pattern = "LEVEL_SPRINT"
		74: dx = 850.0;  dy = -35.0;  motif = SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter = "Monolith Shelf Hop";       pattern = "SHORT_TECHNICAL_HOP"
		75: dx = 1680.0; dy = -55.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Avenue of Sphinxes";       pattern = "RETRO_BRAKE"

		# ── SCENE 16: Pyramid Terraces (Pads 76–80) ─────────────────────────
		# Apex tier step-up → temple spire ascent → altar rest → threshold brake → milestone exit.
		# Silhouette: /● /● ─● ──────● ──────────●
		76: dx = 1080.0; dy = -100.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Apex Tier Rise";           pattern = "TERRACED_STEP_UP"
		77: dx = 940.0;  dy = -145.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Temple Spire Crest";       pattern = "STEEP_HIGH_RIGHT"
		78: dx = 960.0;  dy =  10.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Altar Sanctuary";          pattern = "RECOVERY_PAD"
		79: dx = 1620.0; dy = -50.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Threshold Approach Run";   pattern = "RETRO_BRAKE"
		80: dx = 2450.0; dy = -25.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Solar Ruins Milestone";    pattern = "ZONE_MILESTONE"; is_milestone = true

		# ══════════════════════════════════════════════════════════════════════
		# ZONE 4: SOLAR CORE (Pads 81–100)
		# Macro neighbourhood: Y≈-200–300 (caldera → plasma valley → dramatic ascent → apex)
		# ══════════════════════════════════════════════════════════════════════

		# ── SCENE 17: Caldera Rim (Pads 81–85) ──────────────────────────────
		# Rim uplift → plasma column ascent → shoulder dip recovery → basalt haven → flare pedestal.
		# Silhouette: /● /● ●\ ─● ─●
		81: dx = 1150.0; dy = -100.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Caldera Rim Uplift";       pattern = "TERRACED_STEP_UP"
		82: dx = 950.0;  dy = -155.0; motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Plasma Column Ascent";     pattern = "STEEP_HIGH_RIGHT"
		83: dx = 1250.0; dy =  65.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Plasma Shoulder Dip";      pattern = "TERRACED_STEP_DOWN"
		84: dx = 980.0;  dy = -20.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Basalt Haven Rest";        pattern = "RECOVERY_PAD"
		85: dx = 870.0;  dy = -35.0;  motif = SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter = "Solar Flare Pedestal";     pattern = "SHORT_TECHNICAL_HOP"

		# ── SCENE 18: Plasma Valley (Pads 86–90) ─────────────────────────────
		# Molten plains sprint → corona sea long glide → shoulder rest → core spire ascent → milestone.
		# Silhouette: ──────● ──────────────────● ─● /● ──────────────●
		86: dx = 1700.0; dy = -50.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Molten Plains Sprint";     pattern = "RETRO_BRAKE"
		87: dx = 2400.0; dy = -10.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Corona Sea Traverse";      pattern = "LONG_GLIDE"
		88: dx = 940.0;  dy =  35.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Plasma Shoulder Rest";     pattern = "RECOVERY_PAD"
		89: dx = 960.0;  dy = -150.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Core Spire Ascent";        pattern = "STEEP_HIGH_RIGHT"
		90: dx = 2450.0; dy = -25.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Solar Core Spire Summit";  pattern = "ZONE_MILESTONE"; is_milestone = true

		# ── SCENE 19: Core Ascent (Pads 91–95) ───────────────────────────────
		# Corona terrace recovery → corona step-up → threshold sprint → monolith hop → final ascent step.
		# Silhouette: ─● /● ──────● ─● /●
		91: dx = 920.0;  dy =  10.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Corona Terrace Haven";     pattern = "RECOVERY_PAD"
		92: dx = 1100.0; dy = -90.0;  motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Corona Steps";             pattern = "TERRACED_STEP_UP"
		93: dx = 1500.0; dy = -20.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Threshold Terrace Sprint"; pattern = "LEVEL_SPRINT"
		94: dx = 870.0;  dy = -40.0;  motif = SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter = "Threshold Monolith Hop";   pattern = "SHORT_TECHNICAL_HOP"
		95: dx = 1120.0; dy = -100.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Final Ascent Step";        pattern = "TERRACED_STEP_UP"

		# ── SCENE 20: Solar Core Apex (Pads 96–100) ──────────────────────────
		# Pinnacle spire → apex terrace settle → solar sanctum → final corridor → SOLAR CORE APEX.
		# Silhouette: /● ●\ ─● ──────● ──────────●
		96: dx = 940.0;  dy = -135.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Pinnacle Spire Ascent";    pattern = "STEEP_HIGH_RIGHT"
		97: dx = 1320.0; dy =  40.0;  motif = SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter = "Apex Terrace Settle";      pattern = "TERRACED_STEP_DOWN"
		98: dx = 980.0;  dy = -10.0;  motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Solar Sanctum";            pattern = "RECOVERY_PAD"
		99: dx = 1650.0; dy = -50.0;  motif = SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter = "Final Approach Corridor";  pattern = "RETRO_BRAKE"
		100: dx = 2450.0; dy = -25.0; motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "THE SOLAR CORE APEX";      pattern = "ZONE_MILESTONE"; is_milestone = true

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
