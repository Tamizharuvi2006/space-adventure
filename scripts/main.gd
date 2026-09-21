extends Node2D
class_name SolarMain

const SunZoneData = preload("res://scripts/planet_data.gd")
const SolarBackground = preload("res://scripts/background.gd")

const SAVE_PATH = "user://explore_sun_save.json"
const LEGACY_SAVE_PATH = "user://explore_sun_best.save"

enum GameState { MAIN_MENU, COUNTDOWN, PLAYING, PAUSED, GAME_OVER, REWINDING }

@onready var world_gen: WorldGenerator = $WorldGenerator
@onready var player: SolarPlayer = $Player
@onready var camera: SolarCamera = $Camera2D
@onready var hud: SolarHUD = $HUD
@onready var sound_manager: Node = $SoundManager
@onready var music_manager: Node = $MusicManager
@onready var background: SolarBackground = $Background

var current_state: GameState = GameState.MAIN_MENU
var current_pad: int = 1
var current_checkpoint: int = 1
var best_pad: int = 0
var consecutive_perfects: int = 0
var current_zone_idx: int = 0
var rewind_tween: Tween = null
var has_shown_journey_complete: bool = false

func _ready() -> void:
	# Immediately show splash overlay with loading animation on frame 0
	_start_splash_fade_in()
	
	load_game_progress()
	hud.bind_player(player)
	hud.bind_world_gen(world_gen)
	
	# Connect UI signals
	hud.play_game_requested.connect(_on_play_game_requested)
	hud.pause_game_requested.connect(_on_pause_game_requested)
	hud.resume_game_requested.connect(_on_resume_game_requested)
	hud.retry_game_requested.connect(_on_retry_game_requested)
	hud.restart_game_requested.connect(_on_restart_game_requested)
	hud.home_game_requested.connect(_on_home_game_requested)
	
	player.landed_safely.connect(_on_player_landed)
	player.crashed.connect(_on_player_crashed)
	
	camera.follow_target = player
	
	# World initialization
	world_gen.initialize_world(player)
	
	# Restore saved checkpoint and resume normal playable state
	restore_checkpoint_state(current_checkpoint)

	# Load saved music volume preference
	if music_manager and has_node("MusicManager"):
		var save_data = _load_raw_save_data()
		if save_data.has("music_volume_pct"):
			var vol_pct = float(save_data["music_volume_pct"])
			music_manager.set_music_volume_from_slider(vol_pct)
			hud.set_music_slider_value(vol_pct)
		else:
			hud.set_music_slider_value(70.0)
			music_manager.set_music_volume_from_slider(70.0)

func _start_splash_fade_in() -> void:
	var splash_script = preload("res://scripts/splash_overlay.gd")
	var splash_instance = splash_script.new()
	splash_instance.splash_finished.connect(func():
		if music_manager and music_manager.has_method("play_ambient"):
			music_manager.play_ambient(2.0)
	)
	add_child(splash_instance)

func restore_checkpoint_state(checkpoint_idx: int) -> void:
	get_tree().paused = false
	if rewind_tween and rewind_tween.is_valid():
		rewind_tween.kill()
	if camera:
		camera.set_process(true)
		
	# 1. Validate checkpoint range (strictly 1 to TOTAL_PADS)
	var safe_idx = clampi(checkpoint_idx, 1, SunZoneData.TOTAL_PADS)
	current_pad = safe_idx
	current_checkpoint = safe_idx
	best_pad = clampi(best_pad, 0, SunZoneData.TOTAL_PADS)
	consecutive_perfects = 0
	
	# 2. Zone environment matching checkpoint
	current_zone_idx = SunZoneData.get_zone_index(current_checkpoint)
	var current_zone = SunZoneData.get_zone_by_index(current_zone_idx)
	if background and background.has_method("apply_zone_visuals_instant"):
		background.apply_zone_visuals_instant(current_zone)
		
	# 3. Ensure checkpoint platform exists and spawn player
	var checkpoint_pad = world_gen.ensure_checkpoint_exists(current_checkpoint)
	if not checkpoint_pad:
		checkpoint_pad = world_gen.ensure_checkpoint_exists(1)
		current_checkpoint = 1
		current_pad = 1
		
	if checkpoint_pad:
		player.spawn_on_platform(checkpoint_pad)
		
		# 4. Target next platform (Pad 100 edge case: journey complete, no Pad 101)
		if current_checkpoint >= SunZoneData.TOTAL_PADS:
			hud.set_target_platform(null)
			camera.set_next_target_platform(null)
			player.set_target_platform(null)
			world_gen.set_active_targets(checkpoint_pad, null)
			if not has_shown_journey_complete:
				has_shown_journey_complete = true
				hud.show_journey_complete(current_checkpoint, SunZoneData.TOTAL_PADS)
		else:
			has_shown_journey_complete = false
			var next_target_idx = current_checkpoint + 1
			var next_pad = world_gen.ensure_checkpoint_exists(next_target_idx)
			_update_target_platform(next_target_idx)
			world_gen.set_active_targets(checkpoint_pad, next_pad)
			
		# 5. Restore camera composition for checkpoint pad
		camera.notify_landed(checkpoint_pad)
		var view_w = get_viewport().get_visible_rect().size.x
		var target_cam_x = checkpoint_pad.global_position.x - (view_w * (camera.current_screen_frac_x - 0.5))
		camera.global_position.x = target_cam_x
		camera.global_position.y = checkpoint_pad.global_position.y + camera.default_vertical_offset
		if camera.has_method("reset_physics_interpolation"):
			camera.reset_physics_interpolation()
			
		# Stream terrain chunks around checkpoint camera position
		world_gen.update_terrain_streaming(camera.global_position.x)
		
	# 6. Update HUD (strictly clamped to 1..100)
	hud.update_progress(current_checkpoint, SunZoneData.TOTAL_PADS, best_pad)
	var zone = SunZoneData.get_zone_for_pad(current_checkpoint)
	hud.update_zone_name(zone["name"])
	
	# 7. Restore normal playable state
	hud.show_gameplay_hud()
	player.set_control_enabled(true)
	current_state = GameState.PLAYING
	print("[CHECKPOINT] Restored playable state at Checkpoint PAD %d (Best: %d)" % [current_checkpoint, best_pad])

func _process(_delta: float) -> void:
	if background and camera:
		background.update_camera_offset(camera.global_position)
	# Drive terrain streaming each frame — gives the "travelling world" feel.
	# Pass the camera's current world-space X so chunks spawn ahead and recycle behind.
	if current_state == GameState.PLAYING or current_state == GameState.COUNTDOWN or current_state == GameState.REWINDING:
		world_gen.update_terrain_streaming(camera.global_position.x)

func go_to_main_menu() -> void:
	current_state = GameState.MAIN_MENU
	get_tree().paused = false
	player.set_control_enabled(false)
	if rewind_tween and rewind_tween.is_valid():
		rewind_tween.kill()
	if camera:
		camera.set_process(true)
	
	restore_checkpoint_state(current_checkpoint)
	hud.show_main_menu(best_pad, current_checkpoint)
	current_state = GameState.MAIN_MENU
	player.set_control_enabled(false)
	print("[GAME_STATE] Transitioned to MAIN_MENU")

func _on_play_game_requested() -> void:
	restore_checkpoint_state(current_checkpoint)
	if music_manager:
		music_manager.play_ambient(2.0)
	_start_countdown_and_play()

func _start_countdown_and_play() -> void:
	current_state = GameState.COUNTDOWN
	get_tree().paused = false
	player.set_control_enabled(false)
	hud.update_progress(current_pad, SunZoneData.TOTAL_PADS, best_pad)
	
	hud.start_countdown(func():
		current_state = GameState.PLAYING
		player.set_control_enabled(true)
		print("[GAME_STATE] Transitioned to PLAYING")
	)

func _on_pause_game_requested() -> void:
	if current_state != GameState.PLAYING:
		return
	current_state = GameState.PAUSED
	get_tree().paused = true
	player.set_control_enabled(false)
	hud.show_pause_menu()
	if music_manager:
		music_manager.on_pause()
	print("[GAME_STATE] Transitioned to PAUSED")

func _on_resume_game_requested() -> void:
	if current_state != GameState.PAUSED:
		return
	current_state = GameState.PLAYING
	get_tree().paused = false
	hud.hide_pause_menu()
	player.set_control_enabled(true)
	if music_manager:
		music_manager.on_resume()
	print("[GAME_STATE] Resumed to PLAYING")

func _on_retry_game_requested() -> void:
	get_tree().paused = false
	hud.hide_pause_menu()
	hud.hide_game_over()
	restore_checkpoint_state(current_checkpoint)
	if music_manager:
		music_manager.on_resume()
	_start_countdown_and_play()
	print("[GAME_STATE] Retried from checkpoint PAD %d -> targeting PAD %d" % [current_checkpoint, current_checkpoint + 1])

func _on_restart_game_requested() -> void:
	get_tree().paused = false
	hud.hide_pause_menu()
	hud.hide_game_over()
	current_checkpoint = 1
	current_pad = 1
	consecutive_perfects = 0
	has_shown_journey_complete = false
	save_game_progress()
	
	world_gen.initialize_world(player)
	restore_checkpoint_state(1)
	
	if music_manager:
		music_manager.on_resume()
		music_manager.on_zone_changed(0)
		
	_start_countdown_and_play()
	print("[GAME_STATE] Restarted journey from PAD 1!")

func _on_home_game_requested() -> void:
	if music_manager:
		music_manager.stop_ambient(1.2)
	go_to_main_menu()

func _update_target_platform(next_idx: int) -> void:
	if next_idx <= 0 or next_idx > SunZoneData.TOTAL_PADS:
		# Journey complete or cleared - no Pad 101
		camera.set_next_target_platform(null)
		player.set_target_platform(null)
		hud.set_target_platform(null)
		var curr_pad_node = world_gen.get_platform_by_index(current_pad)
		world_gen.set_active_targets(curr_pad_node, null)
		return
		
	var next_pad = world_gen.ensure_checkpoint_exists(next_idx)
	if next_pad:
		camera.set_next_target_platform(next_pad)
		player.set_target_platform(next_pad)
		hud.set_target_platform(next_pad)
		var curr_pad_node = world_gen.get_platform_by_index(current_pad)
		world_gen.set_active_targets(curr_pad_node, next_pad)
		
		# Update zone name in HUD
		var zone = SunZoneData.get_zone_for_pad(current_pad)
		hud.update_zone_name(zone["name"])

func _on_player_landed(platform: Node2D, is_perfect: bool) -> void:
	if current_state != GameState.PLAYING:
		return
		
	var solar_platform = platform as SolarPlatform
	if solar_platform and not solar_platform.has_been_visited:
		current_pad = clampi(solar_platform.platform_index, 1, SunZoneData.TOTAL_PADS)
		current_checkpoint = current_pad
		
		if is_perfect:
			consecutive_perfects += 1
		else:
			consecutive_perfects = 0
		
		best_pad = clampi(maxi(best_pad, current_pad), 1, SunZoneData.TOTAL_PADS)
			
		# SAVE IMMEDIATELY AFTER EVERY CONFIRMED LANDING (Disk flush)
		save_game_progress()
			
		hud.update_progress(current_pad, SunZoneData.TOTAL_PADS, best_pad)
		
		# Zone transition check (triggered AFTER landing confirmation)
		var new_zone_idx = SunZoneData.get_zone_index(current_pad)
		if new_zone_idx != current_zone_idx:
			current_zone_idx = new_zone_idx
			var zone = SunZoneData.get_zone_by_index(new_zone_idx)
			
			# Zone arrival banner
			hud.show_zone_arrival_banner(zone)
			sound_manager.play_record()
			if music_manager:
				music_manager.on_zone_changed(new_zone_idx)
			
			# Smooth 2.0s environment transition
			if background and background.has_method("transition_to_zone"):
				background.transition_to_zone(zone, 2.0)
				
			print("[JOURNEY] Entered %s! (Zone %d)" % [zone["name"], new_zone_idx])
		elif current_pad % 10 == 0 and current_pad < SunZoneData.TOTAL_PADS:
			# 10-Pad Milestone transition (Pads 10, 30, 50, 70, 90)
			var bp = world_gen.get_pad_blueprint(current_pad, 0)
			var chapter_title = bp.get("chapter", "MILESTONE")
			hud.show_milestone_banner(chapter_title, "%d / %d MILESTONE" % [current_pad, SunZoneData.TOTAL_PADS])
			sound_manager.play_record()
			print("[JOURNEY] Reached Milestone Pad %d: %s" % [current_pad, chapter_title])
		
		# Journey completion check (ONLY when reaching Pad 100)
		if current_pad >= SunZoneData.TOTAL_PADS:
			if not has_shown_journey_complete:
				has_shown_journey_complete = true
				hud.show_journey_complete(current_pad, SunZoneData.TOTAL_PADS)
				sound_manager.play_record()
				print("[JOURNEY] ☀️ SUN JOURNEY COMPLETE! 100 / 100")
			# Stop normal progression - no Pad 101 target
			_update_target_platform(0)
		else:
			has_shown_journey_complete = false
			# Target next pad along the continuous route
			_update_target_platform(current_pad + 1)
			
		var alert_text = "PERFECT! PAD %d" % current_pad if is_perfect else "LANDED! PAD %d" % current_pad
		hud.show_landing_alert(alert_text, is_perfect)
		hud.animate_fuel_refill()
		solar_platform.on_player_landed(is_perfect)
		world_gen.on_platform_reached(solar_platform)
		
		camera.notify_landed(solar_platform)
		camera.add_trauma(0.18)
		sound_manager.play_land(is_perfect)
		if music_manager:
			music_manager.on_land()

func _on_player_crashed(reason: String) -> void:
	if current_state != GameState.PLAYING:
		return
		
	current_state = GameState.REWINDING
	player.set_control_enabled(false)
	camera.add_trauma(0.55)
	if music_manager:
		music_manager.on_crash()
	print("[DEATH] Player crashed (%s). Emphasizing death impact in slow-motion..." % reason)
	
	# 1. Very short slow-motion effect (25% speed for ~0.25s real time)
	Engine.time_scale = 0.25
	await get_tree().create_timer(0.25, true, false, true).timeout
	Engine.time_scale = 1.0
	
	if current_state != GameState.REWINDING:
		return
		
	_perform_checkpoint_rewind()

func _perform_checkpoint_rewind() -> void:
	if rewind_tween and rewind_tween.is_valid():
		rewind_tween.kill()

	if current_state != GameState.REWINDING:
		return

	# Ensure checkpoint pad exists in active world
	var checkpoint_pad = world_gen.ensure_checkpoint_exists(current_checkpoint)
	if not checkpoint_pad:
		checkpoint_pad = world_gen.ensure_checkpoint_exists(1)
		current_checkpoint = 1

	# 2. Capture death coordinates and calculate destination checkpoint coordinates
	var death_cam_pos = camera.global_position
	var death_player_pos = player.global_position
	var target_player_pos = checkpoint_pad.get_landing_position()

	var view_w = get_viewport().get_visible_rect().size.x
	var target_cam_x = checkpoint_pad.global_position.x - (view_w * (camera.current_screen_frac_x - 0.5))
	var target_cam_y = checkpoint_pad.global_position.y + camera.default_vertical_offset
	var target_cam_pos = Vector2(target_cam_x, target_cam_y)

	# 3. Disable autonomous camera follow during rewind
	camera.set_process(false)

	# 4. Calculate distance-scaled rewind duration (0.8s to 1.4s max)
	var dist = absf(death_cam_pos.x - target_cam_x)
	var rewind_duration = clampf(0.80 + (dist / 1800.0) * 0.45, 0.80, 1.40)

	# 5. Restore player sprite with glowing rewind tint so player visually travels backward
	player.sprite_node.visible = true
	player.crash_particles.emitting = false
	player.modulate = Color(0.65, 0.95, 1.0, 0.92)
	player.velocity = Vector2.ZERO

	# 6. Continuous reverse travel: smoothly interpolate both camera and player back to checkpoint
	rewind_tween = create_tween().set_parallel(true)
	rewind_tween.tween_property(camera, "global_position", target_cam_pos, rewind_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	rewind_tween.tween_property(player, "global_position", target_player_pos, rewind_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	rewind_tween.tween_property(player, "rotation", 0.0, rewind_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	# 7. When rewind reaches checkpoint, settle cleanly onto pad and resume continuous play
	rewind_tween.chain().tween_callback(func():
		player.modulate = Color.WHITE
		player.spawn_on_platform(checkpoint_pad)
		camera.set_process(true)
		camera.notify_landed(checkpoint_pad)
		
		# Set target to next platform (Pad 100 edge case: journey complete, no Pad 101)
		if SunZoneData.is_journey_complete(current_checkpoint):
			hud.set_target_platform(null)
			camera.set_next_target_platform(null)
			player.set_target_platform(null)
			world_gen.set_active_targets(checkpoint_pad, null)
		else:
			var next_target_idx = current_checkpoint + 1
			var next_pad = world_gen.ensure_checkpoint_exists(next_target_idx)
			_update_target_platform(next_target_idx)
			world_gen.set_active_targets(checkpoint_pad, next_pad)

		# Ensure zone visuals match current checkpoint
		current_zone_idx = SunZoneData.get_zone_index(current_checkpoint)
		var current_zone = SunZoneData.get_zone_by_index(current_zone_idx)
		if background and background.has_method("apply_zone_visuals_instant"):
			background.apply_zone_visuals_instant(current_zone)

		# Update HUD progress & zone
		hud.update_progress(current_checkpoint, SunZoneData.TOTAL_PADS, best_pad)
		var zone = SunZoneData.get_zone_for_pad(current_checkpoint)
		hud.update_zone_name(zone["name"])

		# Re-enable controls immediately - continue gameplay!
		player.set_control_enabled(true)
		current_state = GameState.PLAYING
		if music_manager:
			music_manager.on_rewind_complete()
		print("[REWIND] Settled on PAD %d. Continuous play resumed -> target PAD %d" % [current_checkpoint, current_checkpoint + 1])
	)

func save_game_progress() -> void:
	current_checkpoint = clampi(current_checkpoint, 1, SunZoneData.TOTAL_PADS)
	current_pad = clampi(current_pad, 1, SunZoneData.TOTAL_PADS)
	best_pad = clampi(best_pad, 0, SunZoneData.TOTAL_PADS)
	
	var is_complete: bool = (current_checkpoint >= SunZoneData.TOTAL_PADS)
	var next_target: int = 0 if is_complete else (current_checkpoint + 1)
	var music_vol_pct: float = 70.0
	if music_manager and "music_volume_pct" in music_manager:
		music_vol_pct = music_manager.music_volume_pct
	var save_data = {
		"version": 1,
		"checkpoint_pad": current_checkpoint,
		"best_pad": best_pad,
		"next_target_pad": next_target,
		"journey_complete": is_complete,
		"music_volume_pct": music_vol_pct,
		"timestamp": Time.get_unix_time_from_system()
	}
	var json_str = JSON.stringify(save_data, "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.flush()
		file.close()
		print("[SAVE] Progress saved immediately: Checkpoint PAD %d | Best PAD %d | Target PAD %d" % [current_checkpoint, best_pad, next_target])
	else:
		push_error("[SAVE] Failed to open save file for writing: %s (Error %d)" % [SAVE_PATH, FileAccess.get_open_error()])

func load_game_progress() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		# Check legacy binary save if available
		if FileAccess.file_exists(LEGACY_SAVE_PATH):
			var leg = FileAccess.open(LEGACY_SAVE_PATH, FileAccess.READ)
			if leg:
				best_pad = clampi(leg.get_32(), 0, SunZoneData.TOTAL_PADS)
				leg.close()
				print("[SAVE] Migrated legacy best_pad: %d" % best_pad)
		current_checkpoint = 1
		current_pad = 1
		print("[SAVE] No save data found. Initialized new journey at Checkpoint PAD 1.")
		return {"checkpoint_pad": 1, "best_pad": best_pad, "next_target_pad": 2, "journey_complete": false}
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_warning("[SAVE] Failed to open save file for reading. Falling back to PAD 1.")
		current_checkpoint = 1
		current_pad = 1
		return {"checkpoint_pad": 1, "best_pad": 0, "next_target_pad": 2, "journey_complete": false}
		
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var err = json.parse(content)
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_warning("[SAVE] Corrupted save data. Safely falling back to PAD 1.")
		current_checkpoint = 1
		current_pad = 1
		return {"checkpoint_pad": 1, "best_pad": 0, "next_target_pad": 2, "journey_complete": false}
		
	var data = json.data as Dictionary
	var cp: int = 1
	if data.has("checkpoint_pad"):
		cp = int(data["checkpoint_pad"])
	elif data.has("current_checkpoint"):
		cp = int(data["current_checkpoint"])
	elif data.has("last_successful_checkpoint"):
		cp = int(data["last_successful_checkpoint"])
		
	var bp: int = 0
	if data.has("best_pad"):
		bp = int(data["best_pad"])
		
	# Validate pad range (strictly 1 to TOTAL_PADS; out-of-range falls back to PAD 1)
	if cp < 1 or cp > SunZoneData.TOTAL_PADS:
		push_warning("[SAVE] Saved checkpoint %d outside valid range (1-%d). Safely falling back to PAD 1." % [cp, SunZoneData.TOTAL_PADS])
		cp = 1
		
	bp = clampi(bp, 0, SunZoneData.TOTAL_PADS)
		
	current_checkpoint = cp
	current_pad = cp
	best_pad = bp
	var is_complete: bool = (current_checkpoint >= SunZoneData.TOTAL_PADS)
	var target: int = 0 if is_complete else (current_checkpoint + 1)
	print("[SAVE] Loaded progress: Checkpoint PAD %d | Best PAD %d | Complete: %s" % [current_checkpoint, best_pad, str(is_complete)])
	return {"checkpoint_pad": cp, "best_pad": bp, "next_target_pad": target, "journey_complete": is_complete}

func load_best_score() -> void:
	load_game_progress()

func save_best_score() -> void:
	save_game_progress()

## Returns raw parsed JSON dict from save file (or empty dict if none).
## Used to read prefs like music_volume_pct before MusicManager is wired.
func _load_raw_save_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	var content = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(content) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data as Dictionary

## Called by HUD music volume slider in real-time.
func on_music_volume_changed(pct: float) -> void:
	if music_manager:
		music_manager.set_music_volume_from_slider(pct)
	save_game_progress()  # Persist slider position immediately
