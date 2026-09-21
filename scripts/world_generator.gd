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
	var width: float = 160.0
	var chapter: String = "Expedition"
	var pattern: String = "STRAIGHT_GLIDE"
	var is_milestone: bool = (idx % 10 == 0)

	# ─── 99-TRANSITION INDIVIDUAL AUTHORING — 100 Landing Stations ───────────
	# Every single transition (N→N+1) is individually designed.
	# Difficulty rhythm: E1→M1→H1→E2→M2→H1→R→M1→E1→L→... (never same tier 3× in a row)
	# Width is authored per pad: E1/R=200–210, M=155–180, H1=132–148, H2=118–135, L=168–185
	# Tier key: E1=very easy, E2=easy, M1=moderate, M2=moderate+,
	#           H1=hard, H2=hard+, L=long glide, R=recovery
	#
	# ZONES (macro geography preserved, variety authored individually):
	#   Solar Valley  (Pads  1–20) — E/M dominant, 2×H1, 1×H2, recovery at 7 & 18
	#   Solar Craters (Pads 21–40) — M/H mix, 4 hard transitions, recovery at 28 & 36
	#   Solar Mtns    (Pads 41–60) — H dominant, 6 hard, recovery at 48 & 56
	#   Solar Ruins   (Pads 61–80) — complex combos, recovery at 63, 69, 78
	#   Solar Core    (Pads 81–100)— max variety, recovery at 88 & 98, grand finale
	match idx:
		# ══════════════════════════════════════════════════════════════════════
		# ZONE 0 — SOLAR VALLEY (Pads 1–20)
		# Tier sequence: E1·M1·H1·E2·M2·H1·R·M1·E1·L · E2·H1·M2·E1·M1·H2·M2·R·H1·L
		# Recovery pads: 7 (R), 18 (R)
		# ══════════════════════════════════════════════════════════════════════
		1:   dx=840.0;  dy= +18.0; width=206.0; motif=SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter="Valley Entry";          pattern="SHORT_TECHNICAL_HOP"   # E1
		2:   dx=1140.0; dy= -80.0; width=170.0; motif=SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter="Mesa Rise";             pattern="TERRACED_STEP_UP"      # M1
		3:   dx=1020.0; dy=-148.0; width=143.0; motif=SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter="First Spire";           pattern="STEEP_HIGH_RIGHT"      # H1
		4:   dx=940.0;  dy= +52.0; width=194.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Gorge Settle";          pattern="RECOVERY_PAD"         # E2
		5:   dx=1310.0; dy=+100.0; width=158.0; motif=SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter="Canyon Descent";        pattern="DEEP_LOW_RIGHT"       # M2
		6:   dx=1060.0; dy=-152.0; width=140.0; motif=SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter="Wall Assault";          pattern="STEEP_HIGH_RIGHT"     # H1
		7:   dx=870.0;  dy= +28.0; width=207.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Mesa Rest";             pattern="RECOVERY_PAD"         # R
		8:   dx=1180.0; dy= -72.0; width=172.0; motif=SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter="Ridge Traverse";        pattern="RETRO_BRAKE"          # M1
		9:   dx=820.0;  dy= +22.0; width=204.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Gentle Step";           pattern="SHORT_TECHNICAL_HOP"  # E1
		10:  dx=2200.0; dy= -18.0; width=177.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Valley Milestone Glide"; pattern="ZONE_MILESTONE"; is_milestone=true  # L
		11:  dx=960.0;  dy= +58.0; width=192.0; motif=SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter="Canyon Lip Drop";       pattern="TERRACED_STEP_DOWN"   # E2
		12:  dx=1040.0; dy=-142.0; width=141.0; motif=SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter="Cliff Face Ascent";     pattern="STEEP_HIGH_RIGHT"     # H1
		13:  dx=1270.0; dy= +98.0; width=156.0; motif=SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter="Shelf Recovery";        pattern="TERRACED_STEP_DOWN"   # M2
		14:  dx=855.0;  dy= +18.0; width=205.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Pedestal Rest";         pattern="SHORT_TECHNICAL_HOP"  # E1
		15:  dx=1100.0; dy= -78.0; width=171.0; motif=SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter="Ridge Step Up";         pattern="TERRACED_STEP_UP"     # M1
		16:  dx=1480.0; dy=-158.0; width=132.0; motif=SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter="High Wall Run";         pattern="STEEP_HIGH_RIGHT"     # H2
		17:  dx=1320.0; dy=+112.0; width=153.0; motif=SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter="Deep Settle";           pattern="DEEP_LOW_RIGHT"       # M2
		18:  dx=895.0;  dy= +22.0; width=208.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Valley Rest";           pattern="RECOVERY_PAD"         # R
		19:  dx=1130.0; dy=-128.0; width=143.0; motif=SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter="Crest Climb";           pattern="STEEP_HIGH_RIGHT"     # H1
		20:  dx=2250.0; dy= +18.0; width=175.0; motif=SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter="Solar Valley Milestone"; pattern="ZONE_MILESTONE"; is_milestone=true  # L

		# ══════════════════════════════════════════════════════════════════════
		# ZONE 1 — SOLAR CRATERS (Pads 21–40)
		# Tier sequence: E2·M1·H1·E2·M2·H2·L·R·H1·L · E2·H2·M1·H1·M2·R·M2·H2·M1·L
		# Recovery pads: 28 (R), 36 (R)
		# ══════════════════════════════════════════════════════════════════════
		21:  dx=950.0;  dy= +48.0; width=193.0; motif=SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter="Rim Approach";          pattern="TERRACED_STEP_DOWN"   # E2
		22:  dx=1150.0; dy= +88.0; width=168.0; motif=SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter="Outer Wall Slope";      pattern="TERRACED_STEP_DOWN"   # M1
		23:  dx=1070.0; dy=+155.0; width=139.0; motif=SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter="Interior Drop";         pattern="DEEP_LOW_RIGHT"       # H1
		24:  dx=920.0;  dy= -42.0; width=195.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Ledge Hop Back";        pattern="SHORT_TECHNICAL_HOP"  # E2
		25:  dx=1420.0; dy=+128.0; width=154.0; motif=SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter="Deep Bowl Entry";       pattern="DEEP_LOW_RIGHT"       # M2
		26:  dx=1620.0; dy=+168.0; width=128.0; motif=SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter="Basin Plunge";          pattern="DEEP_LOW_RIGHT"       # H2
		27:  dx=2250.0; dy= +22.0; width=178.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Basin Long Glide";      pattern="LONG_GLIDE"           # L
		28:  dx=900.0;  dy= +12.0; width=208.0; motif=SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter="Basin Rest";            pattern="RECOVERY_PAD"         # R
		29:  dx=1080.0; dy=-145.0; width=140.0; motif=SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter="Peak Assault";          pattern="STEEP_HIGH_RIGHT"     # H1
		30:  dx=2300.0; dy= -48.0; width=174.0; motif=SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter="Spire Milestone";       pattern="ZONE_MILESTONE"; is_milestone=true  # L
		31:  dx=930.0;  dy= +20.0; width=196.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Peak Plateau";          pattern="RECOVERY_PAD"         # E2
		32:  dx=1400.0; dy=+162.0; width=126.0; motif=SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter="Trench Plunge";         pattern="DEEP_LOW_RIGHT"       # H2
		33:  dx=1460.0; dy= -12.0; width=168.0; motif=SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter="Trench Sprint";         pattern="LEVEL_SPRINT"         # M1
		34:  dx=960.0;  dy=-135.0; width=141.0; motif=SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter="Trench Climb";          pattern="STEEP_HIGH_RIGHT"     # H1
		35:  dx=1580.0; dy= -58.0; width=155.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Ejecta Traverse";       pattern="RETRO_BRAKE"          # M2
		36:  dx=880.0;  dy= +18.0; width=207.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Rim Rest";              pattern="RECOVERY_PAD"         # R
		37:  dx=1200.0; dy=-108.0; width=157.0; motif=SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter="Wall Terraces";         pattern="TERRACED_STEP_UP"     # M2
		38:  dx=1380.0; dy=-148.0; width=129.0; motif=SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter="Escarpment Climb";      pattern="STEEP_HIGH_RIGHT"     # H2
		39:  dx=1540.0; dy= -52.0; width=169.0; motif=SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter="Rampart Run";           pattern="RETRO_BRAKE"          # M1
		40:  dx=2350.0; dy= -28.0; width=174.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Craters Milestone";     pattern="ZONE_MILESTONE"; is_milestone=true  # L

		# ══════════════════════════════════════════════════════════════════════
		# ZONE 2 — SOLAR MOUNTAINS (Pads 41–60)
		# Tier sequence: M1·H2·E2·M2·H1·M1·H2·R·H1·L · E2·H2·M1·H1·H2·R·M2·M1·H1·L
		# Recovery pads: 48 (R), 56 (R)
		# ══════════════════════════════════════════════════════════════════════
		41:  dx=1120.0; dy= -98.0; width=172.0; motif=SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter="Base Approach";          pattern="TERRACED_STEP_UP"     # M1
		42:  dx=1350.0; dy=-160.0; width=123.0; motif=SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter="Cliff Face Assault";    pattern="STEEP_HIGH_RIGHT"     # H2
		43:  dx=1010.0; dy= +32.0; width=196.0; motif=SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter="Alpine Dip";            pattern="TERRACED_STEP_DOWN"   # E2
		44:  dx=1160.0; dy=-118.0; width=156.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Terrace Precision";     pattern="TERRACED_STEP_UP"     # M2
		45:  dx=920.0;  dy=-138.0; width=138.0; motif=SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter="Crevasse Needle";       pattern="SHORT_TECHNICAL_HOP" # H1
		46:  dx=1080.0; dy=-102.0; width=169.0; motif=SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter="Glacier Shelf";         pattern="TERRACED_STEP_UP"     # M1
		47:  dx=1480.0; dy=-162.0; width=120.0; motif=SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter="Summit Push";           pattern="STEEP_HIGH_RIGHT"     # H2
		48:  dx=930.0;  dy= +42.0; width=206.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Summit Rest";           pattern="RECOVERY_PAD"         # R
		49:  dx=1680.0; dy= -78.0; width=140.0; motif=SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter="Apex Col";              pattern="RETRO_BRAKE"          # H1 (long+hard)
		50:  dx=2400.0; dy= -28.0; width=172.0; motif=SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter="Summit Milestone";      pattern="ZONE_MILESTONE"; is_milestone=true  # L
		51:  dx=890.0;  dy= +12.0; width=197.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Summit Shelf";          pattern="RECOVERY_PAD"         # E2
		52:  dx=1380.0; dy=+182.0; width=121.0; motif=SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter="Couloir Plunge";        pattern="DEEP_LOW_RIGHT"       # H2
		53:  dx=1500.0; dy= -12.0; width=168.0; motif=SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter="Couloir Sprint";        pattern="LEVEL_SPRINT"         # M1
		54:  dx=870.0;  dy=-128.0; width=136.0; motif=SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter="Frost Spire";           pattern="SHORT_TECHNICAL_HOP" # H1
		55:  dx=1450.0; dy=+170.0; width=122.0; motif=SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter="Gorge Step Drop";       pattern="DEEP_LOW_RIGHT"       # H2
		56:  dx=940.0;  dy= +12.0; width=207.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Mountain Haven";        pattern="RECOVERY_PAD"         # R
		57:  dx=1200.0; dy= -98.0; width=158.0; motif=SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter="Pass Ascent";           pattern="TERRACED_STEP_UP"     # M2
		58:  dx=1360.0; dy= +78.0; width=170.0; motif=SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter="Pass Mesa Fall";        pattern="TERRACED_STEP_DOWN"   # M1
		59:  dx=1560.0; dy= -48.0; width=139.0; motif=SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter="Pass Brake Run";        pattern="RETRO_BRAKE"          # H1
		60:  dx=2450.0; dy= -28.0; width=173.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Mountains Milestone";   pattern="ZONE_MILESTONE"; is_milestone=true  # L

		# ══════════════════════════════════════════════════════════════════════
		# ZONE 3 — SOLAR RUINS (Pads 61–80)
		# Tier sequence: M1·H2·R·M2·H2·L·M1·H1·R·L · E2·H2·M1·H1·M2·M1·H2·R·H1·L
		# Recovery pads: 63 (R), 69 (R), 78 (R)
		# ══════════════════════════════════════════════════════════════════════
		61:  dx=1180.0; dy= +92.0; width=170.0; motif=SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter="Colonnade Entry";       pattern="TERRACED_STEP_DOWN"   # M1
		62:  dx=1540.0; dy=+178.0; width=122.0; motif=SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter="Sunken Vault Drop";     pattern="DEEP_LOW_RIGHT"       # H2
		63:  dx=960.0;  dy= +18.0; width=208.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Sanctum Rest";          pattern="RECOVERY_PAD"         # R
		64:  dx=1080.0; dy=-108.0; width=157.0; motif=SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter="Pillar Ascent";         pattern="TERRACED_STEP_UP"     # M2
		65:  dx=1460.0; dy=+168.0; width=124.0; motif=SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter="Colosseum Drop";        pattern="DEEP_LOW_RIGHT"       # H2
		66:  dx=1920.0; dy= +32.0; width=178.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Arena Long Sprint";     pattern="LONG_GLIDE"           # L
		67:  dx=1080.0; dy= -22.0; width=170.0; motif=SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter="Amphitheatre Shelf";    pattern="LEVEL_SPRINT"         # M1
		68:  dx=1020.0; dy=-148.0; width=136.0; motif=SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter="Pyramid Ascent";        pattern="STEEP_HIGH_RIGHT"     # H1
		69:  dx=910.0;  dy= -12.0; width=208.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Forum Rest";            pattern="RECOVERY_PAD"         # R
		70:  dx=2450.0; dy= -28.0; width=173.0; motif=SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter="Pyramid Milestone";     pattern="ZONE_MILESTONE"; is_milestone=true  # L
		71:  dx=950.0;  dy= +18.0; width=196.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Bastion Drop";          pattern="SHORT_TECHNICAL_HOP" # E2
		72:  dx=1400.0; dy=+145.0; width=122.0; motif=SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter="Catacomb Plunge";       pattern="DEEP_LOW_RIGHT"       # H2
		73:  dx=1520.0; dy= -12.0; width=170.0; motif=SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter="Vault Sprint";          pattern="LEVEL_SPRINT"         # M1
		74:  dx=980.0;  dy=-138.0; width=136.0; motif=SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter="Monolith Climb";        pattern="STEEP_HIGH_RIGHT"     # H1
		75:  dx=1620.0; dy= -58.0; width=156.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Avenue Traverse";       pattern="RETRO_BRAKE"          # M2
		76:  dx=1120.0; dy= -98.0; width=172.0; motif=SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter="Terrace Step";          pattern="TERRACED_STEP_UP"     # M1
		77:  dx=1360.0; dy=-155.0; width=124.0; motif=SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter="Temple Spire";          pattern="STEEP_HIGH_RIGHT"     # H2
		78:  dx=950.0;  dy= +12.0; width=208.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Altar Rest";            pattern="RECOVERY_PAD"         # R
		79:  dx=1580.0; dy= -52.0; width=138.0; motif=SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter="Threshold Run";         pattern="RETRO_BRAKE"          # H1
		80:  dx=2450.0; dy= -28.0; width=173.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Ruins Milestone";       pattern="ZONE_MILESTONE"; is_milestone=true  # L

		# ══════════════════════════════════════════════════════════════════════
		# ZONE 4 — SOLAR CORE (Pads 81–100)
		# Tier sequence: M2·H2·E2·H1·M2·H2·L·R·H2·L · E2·H1·M2·H2·M1·H2·M2·R·H1·L
		# Recovery pads: 88 (R), 98 (R)
		# ══════════════════════════════════════════════════════════════════════
		81:  dx=1200.0; dy=-102.0; width=157.0; motif=SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter="Caldera Rise";           pattern="TERRACED_STEP_UP"     # M2
		82:  dx=1280.0; dy=-158.0; width=122.0; motif=SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter="Plasma Column";         pattern="STEEP_HIGH_RIGHT"     # H2
		83:  dx=980.0;  dy= +62.0; width=194.0; motif=SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter="Shoulder Dip";          pattern="TERRACED_STEP_DOWN"   # E2
		84:  dx=1060.0; dy=-132.0; width=138.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Return Climb";          pattern="STEEP_HIGH_RIGHT"     # H1
		85:  dx=1340.0; dy=-108.0; width=155.0; motif=SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter="Flare Pedestal";        pattern="TERRACED_STEP_UP"     # M2
		86:  dx=1660.0; dy= -52.0; width=124.0; motif=SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter="Molten Sprint";         pattern="RETRO_BRAKE"          # H2
		87:  dx=2400.0; dy= -12.0; width=177.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Corona Glide";          pattern="LONG_GLIDE"           # L
		88:  dx=940.0;  dy= +38.0; width=207.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Plasma Rest";           pattern="RECOVERY_PAD"         # R
		89:  dx=1480.0; dy=-162.0; width=120.0; motif=SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter="Core Spire";            pattern="STEEP_HIGH_RIGHT"     # H2
		90:  dx=2450.0; dy= -28.0; width=173.0; motif=SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter="Core Milestone";        pattern="ZONE_MILESTONE"; is_milestone=true  # L
		91:  dx=920.0;  dy= +12.0; width=196.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Corona Terrace";        pattern="SHORT_TECHNICAL_HOP" # E2
		92:  dx=1120.0; dy=-142.0; width=136.0; motif=SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter="Corona Steps";          pattern="STEEP_HIGH_RIGHT"     # H1
		93:  dx=1480.0; dy= -22.0; width=156.0; motif=SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter="Threshold Sprint";      pattern="LEVEL_SPRINT"         # M2
		94:  dx=1380.0; dy=-138.0; width=121.0; motif=SolarTerrainGenerator.FormationType.CRATER_RIM;    chapter="Monolith Hard";         pattern="SHORT_TECHNICAL_HOP" # H2
		95:  dx=1060.0; dy= -98.0; width=170.0; motif=SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter="Ascent Step";           pattern="TERRACED_STEP_UP"     # M1
		96:  dx=1520.0; dy=-145.0; width=120.0; motif=SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter="Pinnacle Assault";      pattern="STEEP_HIGH_RIGHT"     # H2
		97:  dx=1300.0; dy= +42.0; width=157.0; motif=SolarTerrainGenerator.FormationType.VALLEY_SHELF;  chapter="Apex Settle";           pattern="TERRACED_STEP_DOWN"   # M2
		98:  dx=960.0;  dy= -12.0; width=208.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="Final Sanctum";         pattern="RECOVERY_PAD"         # R
		99:  dx=1420.0; dy= -52.0; width=140.0; motif=SolarTerrainGenerator.FormationType.CLIFF_RIGHT;   chapter="Final Corridor";        pattern="RETRO_BRAKE"          # H1
		100: dx=2450.0; dy= -28.0; width=175.0; motif=SolarTerrainGenerator.FormationType.MESA;          chapter="THE SOLAR CORE APEX";   pattern="ZONE_MILESTONE"; is_milestone=true  # L

		_:
			# Endless play beyond Pad 100
			var cycle = idx % 10
			if cycle < 3:
				dx = 1100.0; dy = -150.0; width = 145.0; motif = SolarTerrainGenerator.FormationType.MOUNTAIN_PEAK; chapter = "Deep Space Crest"; pattern = "STEEP_HIGH_RIGHT"
			elif cycle < 6:
				dx = 1400.0; dy = 180.0;  width = 128.0; motif = SolarTerrainGenerator.FormationType.CLIFF_LEFT;    chapter = "Cosmic Chasm";      pattern = "DEEP_LOW_RIGHT"
			elif cycle < 8:
				dx = 920.0;  dy = 0.0;    width = 205.0; motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Cosmic Haven";      pattern = "RECOVERY_PAD"
			else:
				dx = 2400.0; dy = -20.0;  width = 175.0; motif = SolarTerrainGenerator.FormationType.MESA;          chapter = "Stellar Expanse";   pattern = "LONG_GLIDE"

	return {
		"dx": dx,
		"dy": dy,
		"width": width,
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

	# Use per-pad authored width from blueprint. Recovery/milestone overrides preserved for safety.
	var best_width: float = bp.get("width", randf_range(zone.get("width_min", 140.0), zone.get("width_max", 175.0)))
	if bp.pattern == "RECOVERY_PAD":
		best_width = maxf(best_width, 200.0)  # Recovery pads always at least 200px
	elif is_milestone or next_platform_idx == SunZoneData.TOTAL_PADS:
		best_width = maxf(best_width, 175.0)  # Milestone pads never narrower than 175px

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
