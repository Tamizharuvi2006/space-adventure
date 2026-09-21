extends RefCounted
class_name SunZoneData

# Explore Sun V8 — 5 Visual Zones across 100 Landing Pads
# All sky_color / horizon_color / bottom_color keys now match
# the shader uniform names and background.gd set_shader_parameter calls exactly.

const TOTAL_PADS: int = 100
const PADS_PER_ZONE: int = 20

const ZONES: Dictionary = {
	0: {
		"name": "SOLAR VALLEY",
		"subtitle": "First Ascent",
		"icon": "",
		"pad_start": 1,
		"pad_end": 20,
		# Sky gradient — dark Mars / warm amber sunset
		"sky_color":     Color(0.04, 0.03, 0.08, 1.0),  # Near-black upper sky
		"horizon_color": Color(0.28, 0.10, 0.05, 1.0),  # Dark warm red horizon
		"bottom_color":  Color(0.55, 0.22, 0.08, 1.0),  # Warm orange ground glow
		"sun_color":     Color(1.00, 0.78, 0.35, 1.0),  # Warm golden sun
		"sun_radius":    0.13,
		"haze_intensity": 0.28,
		# Mountain layers (far→mid, deepest→closest)
		"far_color":    Color(0.10, 0.04, 0.03, 0.55),  # Deepest faintest ridge
		"terrain_far":  Color(0.15, 0.06, 0.04, 0.75),  # Distant ridge
		"terrain_mid":  Color(0.12, 0.05, 0.04, 0.90),  # Mid canyon buttes
		"terrain_fg":   Color(0.24, 0.10, 0.05, 1.00),
		# Landmarks
		"landmark_type": 0,  # Spires / antenna towers
		# Particles
		"particle_color": Color(1.0, 0.75, 0.35, 0.5),
		"particle_speed": Vector2(30.0, 10.0),
		"particle_count": 25,
		# Route generation
		"gap_min": 480.0, "gap_max": 680.0,
		"dy_min": 50.0,   "dy_max": 130.0,
		"width_min": 140.0, "width_max": 180.0,
		"terrain_amplitude": 40.0, "terrain_frequency": 0.004,
		"pad_hull_color":   Color(0.92, 0.90, 0.85, 1.0),
		"pad_accent_color": Color(0.85, 0.22, 0.15, 1.0),
		"pad_pylon_color":  Color(0.75, 0.72, 0.68, 1.0),
	},
	1: {
		"name": "SOLAR CRATERS",
		"subtitle": "Deep Formations",
		"icon": "",
		"pad_start": 21,
		"pad_end": 40,
		# Volcanic dark burgundy atmosphere
		"sky_color":     Color(0.03, 0.02, 0.06, 1.0),  # Darker near-black
		"horizon_color": Color(0.22, 0.07, 0.04, 1.0),  # Deep burgundy
		"bottom_color":  Color(0.42, 0.16, 0.06, 1.0),  # Volcanic glow
		"sun_color":     Color(1.00, 0.68, 0.25, 1.0),  # More orange sun
		"sun_radius":    0.14,
		"haze_intensity": 0.38,
		"far_color":    Color(0.08, 0.03, 0.02, 0.62),
		"terrain_far":  Color(0.12, 0.04, 0.03, 0.80),
		"terrain_mid":  Color(0.10, 0.04, 0.03, 0.92),
		"terrain_fg":   Color(0.68, 0.30, 0.07, 1.00),
		"landmark_type": 1,  # Crater rims / mineral clusters
		"particle_color": Color(0.95, 0.70, 0.30, 0.50),
		"particle_speed": Vector2(25.0, 8.0),
		"particle_count": 30,
		"gap_min": 520.0, "gap_max": 740.0,
		"dy_min": 65.0,   "dy_max": 140.0,
		"width_min": 135.0, "width_max": 175.0,
		"terrain_amplitude": 55.0, "terrain_frequency": 0.005,
		"pad_hull_color":   Color(0.90, 0.88, 0.83, 1.0),
		"pad_accent_color": Color(0.80, 0.20, 0.12, 1.0),
		"pad_pylon_color":  Color(0.72, 0.70, 0.65, 1.0),
	},
	2: {
		"name": "SOLAR MOUNTAINS",
		"subtitle": "Peak Ascent",
		"icon": "",
		"pad_start": 41,
		"pad_end": 60,
		# Blue-purple twilight with warm orange ground
		"sky_color":     Color(0.06, 0.04, 0.16, 1.0),  # Dark violet upper sky
		"horizon_color": Color(0.28, 0.12, 0.34, 1.0),  # Purple horizon
		"bottom_color":  Color(0.48, 0.24, 0.08, 1.0),  # Warm orange ground
		"sun_color":     Color(0.92, 0.88, 0.78, 1.0),  # Cooler, dimmer sun
		"sun_radius":    0.12,
		"haze_intensity": 0.32,
		"far_color":    Color(0.10, 0.04, 0.14, 0.58),  # Faintest purple
		"terrain_far":  Color(0.15, 0.07, 0.18, 0.80),  # Purple-dark distant
		"terrain_mid":  Color(0.18, 0.06, 0.20, 0.90),  # Deeper purple mid
		"terrain_fg":   Color(0.75, 0.42, 0.08, 1.00),
		"landmark_type": 2,  # Massive rock pillars / ice peaks
		"particle_color": Color(0.85, 0.65, 0.80, 0.45),
		"particle_speed": Vector2(35.0, 12.0),
		"particle_count": 35,
		"gap_min": 540.0, "gap_max": 780.0,
		"dy_min": 75.0,   "dy_max": 155.0,
		"width_min": 130.0, "width_max": 170.0,
		"terrain_amplitude": 75.0, "terrain_frequency": 0.006,
		"pad_hull_color":   Color(0.92, 0.90, 0.85, 1.0),
		"pad_accent_color": Color(0.20, 0.70, 0.25, 1.0),
		"pad_pylon_color":  Color(0.78, 0.75, 0.70, 1.0),
	},
	3: {
		"name": "SOLAR RUINS",
		"subtitle": "Forgotten Traces",
		"icon": "",
		"pad_start": 61,
		"pad_end": 80,
		# Dusty amber / gold ruined palette
		"sky_color":     Color(0.06, 0.05, 0.04, 1.0),  # Dark dusty
		"horizon_color": Color(0.45, 0.28, 0.08, 1.0),  # Amber horizon
		"bottom_color":  Color(0.62, 0.40, 0.12, 1.0),  # Dusty gold glow
		"sun_color":     Color(1.00, 0.88, 0.62, 0.85), # Hazy warm sun
		"sun_radius":    0.11,
		"haze_intensity": 0.48,
		"far_color":    Color(0.16, 0.08, 0.03, 0.58),
		"terrain_far":  Color(0.22, 0.12, 0.05, 0.80),
		"terrain_mid":  Color(0.35, 0.18, 0.06, 0.90),
		"terrain_fg":   Color(0.68, 0.42, 0.12, 1.00),
		"landmark_type": 3,  # Collapsed towers / rovers / signal dishes
		"particle_color": Color(0.90, 0.75, 0.40, 0.45),
		"particle_speed": Vector2(20.0, 6.0),
		"particle_count": 30,
		"gap_min": 520.0, "gap_max": 760.0,
		"dy_min": 65.0,   "dy_max": 140.0,
		"width_min": 135.0, "width_max": 175.0,
		"terrain_amplitude": 60.0, "terrain_frequency": 0.007,
		"pad_hull_color":   Color(0.88, 0.82, 0.72, 1.0),
		"pad_accent_color": Color(0.78, 0.55, 0.15, 1.0),
		"pad_pylon_color":  Color(0.72, 0.65, 0.52, 1.0),
	},
	4: {
		"name": "SOLAR CORE",
		"subtitle": "Heart of the Sun",
		"icon": "",
		"pad_start": 81,
		"pad_end": 100,
		# Near-black sky, massive sun, intense glowing horizon
		"sky_color":     Color(0.02, 0.01, 0.02, 1.0),  # Near pitch black
		"horizon_color": Color(0.35, 0.12, 0.04, 1.0),  # Intense red
		"bottom_color":  Color(0.70, 0.28, 0.06, 1.0),  # Hot orange glow
		"sun_color":     Color(1.00, 0.95, 0.75, 1.0),  # Intense near-white
		"sun_radius":    0.20,                           # Massive sun disc
		"haze_intensity": 0.52,
		"far_color":    Color(0.06, 0.02, 0.01, 0.68),  # Darkest stark silhouette
		"terrain_far":  Color(0.10, 0.04, 0.02, 0.85),
		"terrain_mid":  Color(0.08, 0.03, 0.02, 0.95),
		"terrain_fg":   Color(0.82, 0.42, 0.08, 1.00),
		"landmark_type": 4,  # Energy pylons / massive cliffs
		"particle_color": Color(1.0, 0.88, 0.40, 0.55),
		"particle_speed": Vector2(40.0, 15.0),
		"particle_count": 40,
		"gap_min": 560.0, "gap_max": 840.0,
		"dy_min": 80.0,   "dy_max": 160.0,
		"width_min": 125.0, "width_max": 165.0,
		"terrain_amplitude": 80.0, "terrain_frequency": 0.005,
		"pad_hull_color":   Color(0.92, 0.90, 0.85, 1.0),
		"pad_accent_color": Color(0.85, 0.22, 0.12, 1.0),
		"pad_pylon_color":  Color(0.78, 0.76, 0.72, 1.0),
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
	if pad_index <= 1:
		return false
	return (pad_index - 1) % PADS_PER_ZONE == 0

static func is_journey_complete(pad_index: int) -> bool:
	return pad_index >= TOTAL_PADS