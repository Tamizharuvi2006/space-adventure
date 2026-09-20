extends SceneTree

const SunZoneData = preload("res://scripts/planet_data.gd")
const SolarBackground = preload("res://scripts/background.gd")
const SolarMain = preload("res://scripts/main.gd")
const SolarPlayer = preload("res://scripts/player.gd")
const SolarHUD = preload("res://scripts/hud.gd")
const SolarCamera = preload("res://scripts/camera_follow.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")

const ARTIFACT_DIR = "C:/Users/aruvi/.gemini/antigravity-ide/brain/f75eeb4b-bf34-4366-b518-afc1bd64e4d0"

func _init() -> void:
	print("=== RUNNING V6.2 SMOOTH LANDING TRANSITION TEST SUITE ===")
	call_deferred("_run_suite")

func _ensure_flying(main: SolarMain, hud: SolarHUD, player: SolarPlayer) -> void:
	main.current_state = SolarMain.GameState.PLAYING
	player.set_control_enabled(true)
	player.current_state = SolarPlayer.State.FLYING
	player.last_docked_platform = null
	player.set_physics_process(false)
	hud.game_over_menu.visible = false
	hud.gameplay_hud.visible = true

func _run_suite() -> void:
	var packed = load("res://scenes/main.tscn") as PackedScene
	var main = packed.instantiate() as SolarMain
	root.add_child(main)
	
	var hud = main.get_node("HUD") as SolarHUD
	var player = main.get_node("Player") as SolarPlayer
	var world_gen = main.get_node("WorldGenerator") as WorldGenerator
	var camera = main.get_node("Camera2D") as SolarCamera
	
	await create_timer(0.3).timeout
	
	hud.emit_signal("play_game_requested")
	while main.current_state != SolarMain.GameState.PLAYING:
		await create_timer(0.05).timeout
	await create_timer(0.2).timeout
	
	while world_gen.next_platform_idx <= 35:
		world_gen.spawn_next_route_pad()
	
	var pad_28 = world_gen.get_platform_by_index(28)
	var pad_29 = world_gen.get_platform_by_index(29)
	var pad_30 = world_gen.get_platform_by_index(30)
	assert(pad_28 != null and pad_29 != null and pad_30 != null, "Platforms 28, 29, 30 must exist!")
	var view_size = root.get_viewport().get_visible_rect().size
	
	var step_frames = func(count: int, move_vel: Vector2 = Vector2.ZERO):
		for _i in range(count):
			if move_vel != Vector2.ZERO:
				player.global_position += move_vel * 0.02
			await create_timer(0.02).timeout

	# ─── 1. RESTING ON PAD 28 ────────────────────────────────────────────────
	print("\n--- 1. Resting on Pad 28 ---")
	main.current_pad = 28
	camera.set_next_target_platform(pad_29)
	player.set_target_platform(pad_29)
	player.spawn_on_platform(pad_28)
	camera.snap_to_target()
	await step_frames.call(25)
	
	var baseline_cam_y = camera.global_position.y
	var cam_x_resting_28 = camera.global_position.x
	var p_screen = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	var pad28_screen = (pad_28.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Pad 28: Cam X=%.2f, Cam Y=%.2f, Player Screen X=%.2f (%.2f frac)" % [cam_x_resting_28, baseline_cam_y, p_screen.x, p_screen.x / view_size.x])
	await _capture("v6_2_01_resting_pad28.png")

	# ─── 2. APPROACHING PAD 29 (100px before touchdown) ───────────────────────
	print("\n--- 2. Approaching Pad 29 (Touchdown Approach) ---")
	_ensure_flying(main, hud, player)
	var p29_pos = pad_29.global_position
	player.global_position = Vector2(p29_pos.x - 60.0, p29_pos.y - 70.0)
	player.velocity = Vector2(50.0, 90.0)
	await step_frames.call(20, player.velocity)
	
	var cam_pos_pre_land = camera.global_position
	print("  Pre-Landing: Cam X=%.2f, Cam Y=%.2f" % [cam_pos_pre_land.x, cam_pos_pre_land.y])
	assert(is_equal_approx(cam_pos_pre_land.y, baseline_cam_y), "Camera Y stays 100% fixed on approach!")
	await _capture("v6_2_02_pre_landing_pad29.png")

	# ─── 3. TOUCHDOWN ON PAD 29 (FIRST FRAME - NO INSTANT TELEPORT) ───────────
	print("\n--- 3. Touchdown on Pad 29 (Initial Landing Frame) ---")
	main.current_pad = 29
	camera.set_next_target_platform(pad_30)
	player.set_target_platform(pad_30)
	player.spawn_on_platform(pad_29)
	player.velocity = Vector2.ZERO
	camera.notify_landed(pad_29)
	
	# Step only 1 frame: camera MUST NOT snap instantly!
	await step_frames.call(1)
	var cam_pos_touchdown = camera.global_position
	var delta_x_1_frame = absf(cam_pos_touchdown.x - cam_pos_pre_land.x)
	print("  Touchdown 1-frame Delta X: %.2f px (MUST NOT BE A TELEPORT JUMP)" % delta_x_1_frame)
	assert(delta_x_1_frame < 25.0, "Camera did NOT instantly jump or teleport on touchdown!")
	assert(is_equal_approx(cam_pos_touchdown.y, baseline_cam_y), "Camera Y is strictly fixed on touchdown!")
	await _capture("v6_2_03_touchdown_pad29.png")

	# ─── 4. MID-TRANSITION GLIDE (0.3s after landing) ─────────────────────────
	print("\n--- 4. Mid-Transition Glide (0.3s) ---")
	await step_frames.call(15) # 15 * 0.02 = 0.3s
	var cam_pos_mid = camera.global_position
	print("  Mid-Transition: Cam X=%.2f, Cam Y=%.2f" % [cam_pos_mid.x, cam_pos_mid.y])
	assert(cam_pos_mid.x > cam_pos_pre_land.x, "Camera is smoothly gliding rightward toward target framing!")
	assert(is_equal_approx(cam_pos_mid.y, baseline_cam_y), "Camera Y remains strictly fixed during transition!")
	await _capture("v6_2_04_mid_glide_pad29.png")

	# ─── 5. SETTLED DOCKED FRAMING (0.7s after landing) ───────────────────────
	print("\n--- 5. Settled Docked Framing on Pad 29 (0.7s) ---")
	await step_frames.call(20) # total ~0.7s
	var cam_pos_settled = camera.global_position
	var p_screen_settled = (player.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	var pad29_screen = (pad_29.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	var pad30_screen = (pad_30.global_position - camera.global_position) * camera.zoom + view_size * 0.5
	print("  Settled: Cam X=%.2f, Cam Y=%.2f" % [cam_pos_settled.x, cam_pos_settled.y])
	print("  Player Screen X: %.2f (%.2f frac), Pad 29: %.2f, Pad 30: %.2f" % [p_screen_settled.x, p_screen_settled.x / view_size.x, pad29_screen.x, pad30_screen.x])
	# Settled player at ~38-42% from left
	assert(p_screen_settled.x / view_size.x >= 0.36 and p_screen_settled.x / view_size.x <= 0.45, "Settled player sits comfortably at ~40% from left!")
	# Pad 29 is solidly in view
	assert(pad29_screen.x > 100.0 and pad29_screen.x < view_size.x * 0.6, "Pad 29 remains in view throughout transition!")
	# Pad 30 is ahead on the right
	assert(pad30_screen.x > view_size.x * 0.5, "Pad 30 is visible ahead in forward corridor!")
	assert(is_equal_approx(cam_pos_settled.y, baseline_cam_y), "Camera Y remains 100% fixed!")
	await _capture("v6_2_05_settled_pad29.png")

	# ─── 6. INTERRUPT TRANSITION WITH RELAUNCH (Continuous live follow) ──────
	print("\n--- 6. Interrupt Transition With Live Relaunch ---")
	_ensure_flying(main, hud, player)
	player.velocity = Vector2(250.0, -150.0)
	await step_frames.call(25, player.velocity)
	var cam_pos_relaunch = camera.global_position
	print("  Relaunch: Cam X=%.2f, Cam Y=%.2f" % [cam_pos_relaunch.x, cam_pos_relaunch.y])
	assert(cam_pos_relaunch.x > cam_pos_settled.x, "Camera smoothly tracked live player flight without tween lock!")
	assert(is_equal_approx(cam_pos_relaunch.y, baseline_cam_y), "Camera Y stays fixed during relaunch!")
	await _capture("v6_2_06_relaunch_live_follow.png")

	print("\n=======================================================")
	print("🎉 ALL V6.2 SMOOTH LANDING TRANSITION TESTS PASSED 100%!")
	print("=======================================================")
	quit()

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img = root.get_viewport().get_texture().get_image()
	var dest = ARTIFACT_DIR + "/" + filename
	img.save_png(dest)
