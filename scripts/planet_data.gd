extends RefCounted
class_name SunZoneData

# Explore Sun V2 — 5 Visual Zones across 100 Landing Pads
# Each zone provides visual identity only — physics remain constant (g=640, no wind/updraft)

const TOTAL_PADS: int = 100
const PADS_PER_ZONE: int = 20

const ZONES: Dictionary = {
	0: {
		"name": "SOLAR VALLEY",
		"subtitle": "Warm Descent",
		"icon": "🌄",
		"pad_start": 1,
		"pad_end": 20,
		# Sky gradient — warm Mars-like atmosphere: teal top → amber mid → deep red bottom
		"sky_top": Color(0.37, 0.81, 0.72, 1.0),    # Bright teal
		"sky_mid": Color(0.83, 0.66, 0.23, 1.0),    # Golden amber
		"sky_bottom": Color(0.48, 0.13, 0.06, 1.0), # Deep warm red
		# Sun appearance — bright, large like Mars: Mars
		"sun_color": Color(1.0, 0.97, 0.82, 1.0),
		"sun_radius": 0.12,
		# Terrain palette — authentic atmospheric perspective:
		# Far = soft muted haze, Mid = warm terracotta, FG = rich deep umber with golden sun facets
		"terrain_far": Color(0.48, 0.26, 0.20, 0.55),   # Soft muted atmospheric mountain haze
		"terrain_mid": Color(0.38, 0.16, 0.08, 0.85),   # Medium warm terracotta canyon buttes
		"terrain_fg": Color(0.24, 0.10, 0.05, 1.0),     # Rich deep umber foreground bedrock
		# Particles
		"particle_color": Color(1.0, 0.75, 0.35, 0.5),
		"particle_speed": Vector2(30.0, 10.0),
		"particle_count": 25,
		# Route generation
		"gap_min": 480.0,
		"gap_max": 680.0,
		"dy_min": 50.0,
		"dy_max": 130.0,
		"width_min": 140.0,
		"width_max": 180.0,
		"terrain_amplitude": 40.0,
		"terrain_frequency": 0.004,
		# Platform zone tint — warm/industrial
		"pad_hull_color": Color(0.92, 0.90, 0.85, 1.0), # Off-white like reference
		"pad_accent_color": Color(0.85, 0.22, 0.15, 1.0), # Red stripe accent
		"pad_pylon_color": Color(0.75, 0.72, 0.68, 1.0),  # Light grey pylon
	},
	1: {
		"name": "SOLAR CRATERS",
		"subtitle": "Deep Formations",
		"icon": "🕳️",
		"pad_start": 21,
		"pad_end": 40,
		# Slightly deeper atmosphere — more red-orange
		"sky_top": Color(0.30, 0.72, 0.65, 1.0),
		"sky_mid": Color(0.80, 0.58, 0.18, 1.0),
		"sky_bottom": Color(0.42, 0.10, 0.04, 1.0),
		"sun_color": Color(1.0, 0.95, 0.75, 1.0),
		"sun_radius": 0.13,
		"terrain_far": Color(0.32, 0.10, 0.04, 0.78),
		"terrain_mid": Color(0.52, 0.18, 0.06, 0.90),
		"terrain_fg": Color(0.68, 0.30, 0.07, 1.0),
		"particle_color": Color(0.95, 0.70, 0.30, 0.50),
		"particle_speed": Vector2(25.0, 8.0),
		"particle_count": 30,
		"gap_min": 520.0,
		"gap_max": 740.0,
		"dy_min": 65.0,
		"dy_max": 140.0,
		"width_min": 135.0,
		"width_max": 175.0,
		"terrain_amplitude": 55.0,
		"terrain_frequency": 0.005,
		"pad_hull_color": Color(0.90, 0.88, 0.83, 1.0),
		"pad_accent_color": Color(0.80, 0.20, 0.12, 1.0),
		"pad_pylon_color": Color(0.72, 0.70, 0.65, 1.0),
	},
	2: {
		"name": "SOLAR MOUNTAINS",
		"subtitle": "Peak Ascent",
		"icon": "⛰️",
		"pad_start": 41,
		"pad_end": 60,
		# Blue-purple night sky contrast with bright orange terrain
		"sky_top": Color(0.18, 0.22, 0.62, 1.0),
		"sky_mid": Color(0.45, 0.30, 0.55, 1.0),
		"sky_bottom": Color(0.60, 0.28, 0.10, 1.0),
		"sun_color": Color(0.95, 0.92, 0.85, 1.0),
		"sun_radius": 0.14,
		"terrain_far": Color(0.22, 0.12, 0.08, 0.80),
		"terrain_mid": Color(0.50, 0.28, 0.08, 0.90),
		"terrain_fg": Color(0.75, 0.42, 0.08, 1.0),
		"particle_color": Color(0.85, 0.65, 0.80, 0.45),
		"particle_speed": Vector2(35.0, 12.0),
		"particle_count": 35,
		"gap_min": 540.0,
		"gap_max": 780.0,
		"dy_min": 75.0,
		"dy_max": 155.0,
		"width_min": 130.0,
		"width_max": 170.0,
		"terrain_amplitude": 75.0,
		"terrain_frequency": 0.006,
		"pad_hull_color": Color(0.92, 0.90, 0.85, 1.0),
		"pad_accent_color": Color(0.20, 0.70, 0.25, 1.0),
		"pad_pylon_color": Color(0.78, 0.75, 0.70, 1.0),
	},
	3: {
		"name": "SOLAR RUINS",
		"subtitle": "Ancient Structures",
		"icon": "🏛️",
		"pad_start": 61,
		"pad_end": 80,
		# Dusky amber/gold ruin palette
		"sky_top": Color(0.25, 0.30, 0.55, 1.0),
		"sky_mid": Color(0.62, 0.45, 0.18, 1.0),
		"sky_bottom": Color(0.42, 0.16, 0.06, 1.0),
		"sun_color": Color(1.0, 0.90, 0.70, 0.90),
		"sun_radius": 0.11,
		"terrain_far": Color(0.32, 0.18, 0.08, 0.80),
		"terrain_mid": Color(0.55, 0.32, 0.10, 0.90),
		"terrain_fg": Color(0.68, 0.42, 0.12, 1.0),
		"particle_color": Color(0.90, 0.75, 0.40, 0.45),
		"particle_speed": Vector2(20.0, 6.0),
		"particle_count": 30,
		"gap_min": 520.0,
		"gap_max": 760.0,
		"dy_min": 65.0,
		"dy_max": 140.0,
		"width_min": 135.0,
		"width_max": 175.0,
		"terrain_amplitude": 60.0,
		"terrain_frequency": 0.007,
		"pad_hull_color": Color(0.88, 0.82, 0.72, 1.0),
		"pad_accent_color": Color(0.78, 0.55, 0.15, 1.0),
		"pad_pylon_color": Color(0.72, 0.65, 0.52, 1.0),
	},
	4: {
		"name": "SOLAR CORE",
		"subtitle": "Heart of the Sun",
		"icon": "🌞",
		"pad_start": 81,
		"pad_end": 100,
		# Intense golden-orange, sun dominates
		"sky_top": Color(0.50, 0.78, 0.68, 1.0),
		"sky_mid": Color(0.90, 0.70, 0.25, 1.0),
		"sky_bottom": Color(0.55, 0.15, 0.04, 1.0),
		"sun_color": Color(1.0, 0.98, 0.90, 1.0),
		"sun_radius": 0.22,
		"terrain_far": Color(0.42, 0.14, 0.04, 0.82),
		"terrain_mid": Color(0.62, 0.26, 0.06, 0.92),
		"terrain_fg": Color(0.82, 0.42, 0.08, 1.0),
		"particle_color": Color(1.0, 0.88, 0.40, 0.55),
		"particle_speed": Vector2(40.0, 15.0),
		"particle_count": 40,
		"gap_min": 560.0,
		"gap_max": 840.0,
		"dy_min": 80.0,
		"dy_max": 160.0,
		"width_min": 125.0,
		"width_max": 165.0,
		"terrain_amplitude": 80.0,
		"terrain_frequency": 0.005,
		"pad_hull_color": Color(0.92, 0.90, 0.85, 1.0),
		"pad_accent_color": Color(0.85, 0.22, 0.12, 1.0),
		"pad_pylon_color": Color(0.78, 0.76, 0.72, 1.0),
	}
}

static func get_zone_index(pad_index: int) -> int:
	if pad_index <= 0:
		return 0
	return clampi(int((pad_index - 1) / PADS_PER_ZONE), 0, ZONES.size() - 1)

static func get_zone_for_pad(pad_index: int) -> Dictionary:
	return ZONES[get_zone_index(pad_index)]

static func get_zone_by_index(idx: int) -> Dictionary:
	return ZONES[clampi(idx, 0, ZONES.size() - 1)]

static func is_zone_boundary(pad_index: int) -> bool:
	# Zone transitions happen at pads 21, 41, 61, 81
	if pad_index <= 1:
		return false
	return (pad_index - 1) % PADS_PER_ZONE == 0

static func is_journey_complete(pad_index: int) -> bool:
	return pad_index >= TOTAL_PADS
