extends Node2D
## Explore Sun — chunky Planet Explorer visual
## Add as a child of the existing Player CharacterBody2D.
## Reads parent.velocity only. Does NOT change physics/collision.

enum AnimState { IDLE, RUN, JUMP, FLY, LAND }

@export var visual_scale := 1.65
@export var animation_speed := 8.0

var state := AnimState.IDLE
var t := 0.0
var land_timer := 0.0
var tilt := 0.0

const HELMET = Color("#F6B82E")
const HELMET_LIGHT = Color("#FFD95A")
const SUIT = Color("#F2F0E8")
const SUIT_SHADE = Color("#C9C7C0")
const ORANGE = Color("#F47725")
const BLUE = Color("#24506B")
const BLUE_DARK = Color("#172D3A")
const VISOR = Color("#79E8F2")
const VISOR_DARK = Color("#183743")
const GLOVE = Color("#403C3B")
const BOOT = Color("#4C4744")
const BACKPACK = Color("#72777A")
const TECH = Color("#35E4E8")
const WHITE = Color("#FFFDF6")

func _ready() -> void:
	z_index = 10
	queue_redraw()

func _process(delta: float) -> void:
	t += delta * animation_speed
	var p = get_parent()
	var v := Vector2.ZERO
	if p != null and "velocity" in p:
		v = p.velocity

	if land_timer > 0.0:
		state = AnimState.LAND
		land_timer = maxf(0.0, land_timer - delta)
	elif v.y > 55.0:
		state = AnimState.FLY
	elif v.y < -55.0:
		state = AnimState.JUMP
	elif absf(v.x) > 15.0:
		state = AnimState.RUN
	else:
		state = AnimState.IDLE

	var target_tilt := clampf(v.x / 420.0, -0.16, 0.16) if state == AnimState.FLY else clampf(v.x / 700.0, -0.10, 0.10) if state == AnimState.RUN else 0.0
	tilt = lerpf(tilt, target_tilt, 1.0 - exp(-10.0 * delta))
	queue_redraw()

func play_land() -> void:
	land_timer = 0.24
	t = 0.0

func _draw() -> void:
	var bob := sin(t * 0.75) * 1.5 if state == AnimState.IDLE else 0.0
	if state == AnimState.RUN:
		bob = absf(sin(t * 1.8)) * 2.5
	elif state == AnimState.FLY:
		bob = sin(t * 1.2) * 2.0

	draw_set_transform(Vector2(0, bob), tilt, Vector2(visual_scale, visual_scale))

	_draw_backpack()

	var phase := sin(t * 1.8)
	if state == AnimState.RUN:
		_draw_leg(Vector2(-8,17), Vector2(-11 + phase*6,38))
		_draw_leg(Vector2(8,17), Vector2(11 - phase*6,38))
	elif state == AnimState.FLY or state == AnimState.JUMP:
		_draw_leg(Vector2(-7,17), Vector2(-14,30))
		_draw_leg(Vector2(7,17), Vector2(14,30))
	else:
		_draw_leg(Vector2(-8,17), Vector2(-9,37))
		_draw_leg(Vector2(8,17), Vector2(9,37))

	_draw_torso()

	var arm_phase := sin(t * 1.8)
	if state == AnimState.RUN:
		_draw_arm(Vector2(-17,-2), Vector2(-24,10+arm_phase*7))
		_draw_arm(Vector2(17,-2), Vector2(24,10-arm_phase*7))
	elif state == AnimState.JUMP:
		_draw_arm(Vector2(-17,-2), Vector2(-25,-14))
		_draw_arm(Vector2(17,-2), Vector2(25,-14))
	elif state == AnimState.FLY:
		_draw_arm(Vector2(-17,-2), Vector2(-29,5))
		_draw_arm(Vector2(17,-2), Vector2(29,5))
	else:
		_draw_arm(Vector2(-17,-2), Vector2(-22,13))
		_draw_arm(Vector2(17,-2), Vector2(22,13))

	_draw_helmet()

	draw_rect(Rect2(-8,4,16,9), BLUE_DARK, true)
	draw_rect(Rect2(-5,6,10,4), TECH, true)
	draw_rect(Rect2(-15,12,30,5), BLUE_DARK, true)
	draw_rect(Rect2(-4,12,8,5), HELMET, true)
	draw_circle(Vector2(-17,-3),5,ORANGE)
	draw_circle(Vector2(17,-3),5,ORANGE)
	draw_circle(Vector2(-9,23),5.2,ORANGE)
	draw_circle(Vector2(9,23),5.2,ORANGE)

	if state == AnimState.FLY or state == AnimState.JUMP:
		_draw_thruster(Vector2(-9,31))
		_draw_thruster(Vector2(9,31))

	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func _draw_backpack() -> void:
	draw_rect(Rect2(-23,-4,12,29), BACKPACK, true)
	draw_rect(Rect2(-21,1,8,16), Color("#8A8F91"), true)
	draw_rect(Rect2(-20,4,6,6), TECH, true)
	draw_rect(Rect2(-22,18,10,5), BLUE_DARK, true)

func _draw_torso() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-15,-8),Vector2(-11,-15),Vector2(11,-15),Vector2(15,-8),
		Vector2(13,15),Vector2(7,20),Vector2(-7,20),Vector2(-13,15)
	]), SUIT)
	draw_colored_polygon(PackedVector2Array([
		Vector2(3,-13),Vector2(11,-10),Vector2(13,15),Vector2(7,20),Vector2(3,18)
	]), SUIT_SHADE)
	draw_line(Vector2(-12,-10),Vector2(7,7),ORANGE,4)
	draw_line(Vector2(12,-10),Vector2(-7,7),ORANGE,4)

func _draw_helmet() -> void:
	draw_rect(Rect2(-9,-18,18,6), BLUE_DARK, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18,-23),Vector2(-13,-34),Vector2(-6,-39),Vector2(8,-39),
		Vector2(15,-34),Vector2(19,-23),Vector2(15,-15),Vector2(-15,-15)
	]), HELMET)
	draw_colored_polygon(PackedVector2Array([
		Vector2(6,-39),Vector2(15,-34),Vector2(19,-23),Vector2(15,-15),Vector2(7,-17)
	]), Color("#D78A1D"))
	draw_rect(Rect2(-13,-31,26,14), VISOR_DARK, true)
	draw_rect(Rect2(-10,-28,20,9), Color("#0A1720"), true)
	draw_rect(Rect2(-7,-27,9,3), VISOR, true)
	draw_rect(Rect2(-2,-37,5,5), TECH, true)

func _draw_arm(a: Vector2, b: Vector2) -> void:
	draw_line(a,b,SUIT_SHADE,8)
	draw_line(a+Vector2(0,1),b,SUIT,5)
	draw_circle(b,5.5,GLOVE)

func _draw_leg(hip: Vector2, foot: Vector2) -> void:
	var knee := hip.lerp(foot,0.48)
	draw_line(hip,knee,SUIT_SHADE,9)
	draw_line(hip,knee,SUIT,6)
	draw_circle(knee,5,ORANGE)
	draw_line(knee,foot,SUIT,7)
	draw_line(knee,foot,SUIT_SHADE,3)
	draw_rect(Rect2(foot.x-8,foot.y-3,18,8),BOOT,true)
	draw_rect(Rect2(foot.x-6,foot.y-5,12,3),Color("#68615B"),true)

func _draw_thruster(pos: Vector2) -> void:
	var pulse := 1.0 + 0.25*sin(t*2.8)
	var h := 12.0*pulse
	draw_colored_polygon(PackedVector2Array([
		pos+Vector2(-4,0),pos+Vector2(4,0),pos+Vector2(2,h),
		pos+Vector2(0,h+8),pos+Vector2(-2,h)
	]),ORANGE)
	draw_circle(pos+Vector2(0,h*0.65),3,HELMET_LIGHT)
