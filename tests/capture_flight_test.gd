extends SceneTree

const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")
const SolarHUD = preload("res://scripts/hud.gd")
const ARTIFACT_DIR = "C:/Users/aruvi/.gemini/antigravity-ide/brain/f75eeb4b-bf34-4366-b518-afc1bd64e4d0"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed = load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate() as SolarMain
	root.add_child(main)
	
	var hud = main.get_node("HUD") as SolarHUD
	var player = main.get_node("Player") as SolarPlayer
	var camera = main.get_node("Camera2D") as Camera2D
	
	await create_timer(0.2).timeout
	
	# Skip countdown directly to playing
	main.current_state = SolarMain.GameState.PLAYING
	player.set_control_enabled(true)
	hud.show_gameplay_hud()
	
	await _capture("flight_00_at_pad.png")
	print("Pos 00: Player=%s, Cam=%s" % [player.global_position, camera.global_position])
	
	# Boost UPWARD
	player.set_mobile_inputs(true, true)
	for i in range(30):
		await create_timer(0.02).timeout
	await _capture("flight_01_boost_up.png")
	print("Pos 01 (Boost Up): Player=%s, Cam=%s" % [player.global_position, camera.global_position])
	
	# Boost RIGHT
	player.set_mobile_inputs(false, true)
	for i in range(40):
		await create_timer(0.02).timeout
	await _capture("flight_02_fly_right.png")
	print("Pos 02 (Fly Right): Player=%s, Cam=%s" % [player.global_position, camera.global_position])
	
	# Coast / Fall
	player.set_mobile_inputs(false, false)
	for i in range(40):
		await create_timer(0.02).timeout
	await _capture("flight_03_fall.png")
	print("Pos 03 (Fall): Player=%s, Cam=%s" % [player.global_position, camera.global_position])
	
	print("=== FLIGHT CAPTURE COMPLETE ===")
	quit(0)

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img = root.get_viewport().get_texture().get_image()
	img.save_png(ARTIFACT_DIR + "/" + filename)
