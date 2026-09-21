extends StaticBody2D
class_name SolarPlatform

const SunZoneData = preload("res://scripts/planet_data.gd")

@export var platform_index: int = 0
var has_been_visited: bool = false
var is_active_target: bool = false

@onready var landing_area: Area2D = $LandingArea
@onready var label: Label = $Label
@onready var pad_visual: Node2D = $Visuals
@onready var beacon_light: ColorRect = $Visuals/BeaconLight
@onready var beacon_beam: Polygon2D = $Visuals/BeaconBeam
@onready var landing_surface: Polygon2D = $Visuals/LandingSurface
@onready var landing_sparks: CPUParticles2D = $Visuals/LandingSparks
@onready var platform_hull: Polygon2D = $Visuals/PlatformHull
@onready var solar_accent: Polygon2D = $Visuals/SolarAccent
@onready var single_pylon: Polygon2D = $Visuals/SinglePylon
@onready var beacon_orb_l: Polygon2D = $Visuals/BeaconOrbL
@onready var beacon_orb_r: Polygon2D = $Visuals/BeaconOrbR

# Moving platform parameters (kept for future use)
var sway_amplitude: float = 0.0
var sway_speed: float = 1.2
var initial_x: float = 0.0

enum Role { BEHIND, CURRENT, NEXT, NEXT_PLUS_1, FUTURE }

var current_role: Role = Role.FUTURE
var show_debug_label: bool = false
var current_width: float = 204.0

# Beacon beam pulse animation
var beam_phase: float = 0.0

func _ready() -> void:
	add_to_group("platform")
	initial_x = position.x
	beam_phase = randf() * TAU
	if label:
		# Show just the number (not "PAD 00" — matches the reference style)
		label.text = "%02d" % platform_index
		label.visible = true  # Always visible for readability
	landing_area.body_entered.connect(_on_landing_area_body_entered)
	_apply_width()
	set_active_target(is_active_target)
	
	# Apply zone styling based on pad index
	_apply_zone_style()

func _apply_zone_style() -> void:
	var zone = SunZoneData.get_zone_for_pad(platform_index)
	if platform_hull:
		platform_hull.color = zone.get("pad_hull_color", Color(0.92, 0.90, 0.85, 1.0))
	if solar_accent:
		solar_accent.color = zone.get("pad_accent_color", Color(0.85, 0.22, 0.15, 1.0))
	if single_pylon:
		single_pylon.color = zone.get("pad_pylon_color", Color(0.75, 0.72, 0.68, 1.0))
	
	# Foundation struts & footings styling
	var strut_l = get_node_or_null("Visuals/DiagonalStrutL")
	var strut_r = get_node_or_null("Visuals/DiagonalStrutR")
	var pc = zone.get("pad_pylon_color", Color(0.75, 0.72, 0.68, 1.0))
	if strut_l: strut_l.color = Color(pc.r * 0.88, pc.g * 0.88, pc.b * 0.85, 1.0)
	if strut_r: strut_r.color = Color(pc.r * 0.88, pc.g * 0.88, pc.b * 0.85, 1.0)
	
	var foot_l = get_node_or_null("Visuals/FoundationFootingL")
	var foot_r = get_node_or_null("Visuals/FoundationFootingR")
	if foot_l: foot_l.color = Color(pc.r * 0.55, pc.g * 0.52, pc.b * 0.48, 1.0)
	if foot_r: foot_r.color = Color(pc.r * 0.55, pc.g * 0.52, pc.b * 0.48, 1.0)

func set_moving_platform(amplitude: float, speed: float = 1.2) -> void:
	sway_amplitude = amplitude
	sway_speed = speed
	initial_x = position.x

func set_platform_width(target_width: float) -> void:
	current_width = clampf(target_width, 100.0, 220.0)
	if is_inside_tree():
		_apply_width()

func _apply_width() -> void:
	var scale_factor = current_width / 204.0
	if pad_visual:
		pad_visual.scale.x = scale_factor
		
	var col_node = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col_node and col_node.shape:
		var rect = col_node.shape as RectangleShape2D
		if rect:
			rect.size.x = current_width
			
	var land_node = get_node_or_null("LandingArea/LandingShape") as CollisionShape2D
	if land_node and land_node.shape:
		var land_rect = land_node.shape as RectangleShape2D
		if land_rect:
			land_rect.size.x = maxf(current_width - 8.0, 70.0)

func _process(delta: float) -> void:
	if not visible:
		return
	
	beam_phase += delta * 2.5
		
	# Horizontal sway for moving platforms
	if sway_amplitude > 0.0:
		position.x = initial_x + sin(beam_phase * sway_speed * 0.8) * sway_amplitude
	
	# Pulse guiding beam if active target
	if is_active_target and beacon_beam:
		beacon_beam.color.a = 0.06 + sin(beam_phase) * 0.04

func get_landing_position() -> Vector2:
	# Top deck is at y = -10.0 in platform local space.
	# Player capsule feet/nozzles are at y = +15.0.
	# -25.0 + 15.0 = -10.0 (pixel-perfect contact, zero sinking, zero floating)
	return global_position + Vector2(0.0, -25.0)

func is_landing_pad() -> bool:
	return true

func set_visual_role(role: Role) -> void:
	current_role = role
	visible = true
	modulate.a = 1.0
	match role:
		Role.CURRENT:
			set_active_target(false)
			if label: label.visible = true
			if landing_surface:
				landing_surface.color = Color(0.35, 0.78, 0.65, 0.95)
		Role.NEXT:
			set_active_target(true)
			if label: label.visible = true
			if landing_surface:
				landing_surface.color = Color(0.45, 0.95, 0.75, 1.0)
		Role.NEXT_PLUS_1, Role.FUTURE:
			set_active_target(false)
			if label: label.visible = true
			if landing_surface:
				landing_surface.color = Color(0.32, 0.70, 0.58, 0.85)
		Role.BEHIND:
			set_active_target(false)
			if label: label.visible = true
			if landing_surface:
				landing_surface.color = Color(0.28, 0.60, 0.50, 0.75)

func set_debug_labels(enabled: bool) -> void:
	show_debug_label = enabled
	if label:
		label.visible = true  # always show number

func set_active_target(active: bool) -> void:
	is_active_target = active
	if beacon_beam:
		beacon_beam.visible = false
	if beacon_light:
		beacon_light.color = Color(0.25, 0.90, 0.75, 1.0) if active else Color(0.22, 0.72, 0.60, 0.7)

func _on_landing_area_body_entered(body: Node2D) -> void:
	if body is SolarPlayer and body.current_state == SolarPlayer.State.FLYING:
		if body.last_docked_platform != self:
			if body.velocity.y >= -40.0:
				body.test_touchdown(self, body.global_position)

func on_player_landed(is_perfect: bool) -> void:
	has_been_visited = true
	set_active_target(false)
	
	# Enhanced landing particle burst
	if landing_sparks:
		landing_sparks.restart()
		landing_sparks.emitting = true
		
	# Pad glow pulse on touchdown
	if beacon_light:
		beacon_light.color = Color(1.0, 1.0, 0.9, 1.0) if is_perfect else Color(0.8, 1.0, 0.7, 1.0)
		var glow_tween = create_tween()
		var settled_color = Color(0.35, 0.82, 0.65, 1.0) if is_perfect else Color(0.30, 0.75, 0.60, 0.9)
		glow_tween.tween_property(beacon_light, "color", settled_color, 0.4)
		
	if landing_surface:
		# Flash white briefly then settle
		landing_surface.color = Color(1.0, 1.0, 1.0, 1.0)
		var surf_tween = create_tween()
		var settled_surf = Color(0.5, 0.9, 0.7, 1.0) if is_perfect else Color(0.4, 0.85, 0.75, 1.0)
		surf_tween.tween_property(landing_surface, "color", settled_surf, 0.35)
		
	# Satisfying squash & bounce animation
	var tween = create_tween()
	tween.tween_property(pad_visual, "scale", Vector2(1.10, 0.90), 0.06)
	tween.tween_property(pad_visual, "scale", Vector2(0.96, 1.04), 0.1)
	tween.tween_property(pad_visual, "scale", Vector2.ONE, 0.12)

func set_index(idx: int) -> void:
	platform_index = idx
	if label:
		label.text = "%02d" % platform_index
	_apply_zone_style()
