extends Node2D
class_name SolarMain

const SunZoneData = preload("res://scripts/planet_data.gd")
const SolarBackground = preload("res://scripts/background.gd")

const SAVE_PATH = "user://explore_sun_best.save"

enum GameState { MAIN_MENU, COUNTDOWN, PLAYING, PAUSED, GAME_OVER }

@onready var world_gen: WorldGenerator = $WorldGenerator
@onready var player: SolarPlayer = $Player
@onready var camera: SolarCamera = $Camera2D
@onready var hud: SolarHUD = $HUD
@onready var sound_manager: Node = $SoundManager
@onready var background: SolarBackground = $Background

var current_state: GameState = GameState.MAIN_MENU
var current_pad: int = 0
var best_pad: int = 0
var consecutive_perfects: int = 0
var current_zone_idx: int = 0

func _ready() -> void:
	load_best_score()
	hud.bind_player(player)
	hud.bind_world_gen(world_gen)
	
	# Connect UI signals
	hud.play_game_requested.connect(_on_play_game_requested)
	hud.pause_game_requested.connect(_on_pause_game_requested)
	hud.resume_game_requested.connect(_on_resume_game_requested)
	hud.retry_game_requested.connect(_on_retry_game_requested)
	hud.home_game_requested.connect(_on_home_game_requested)
	
	player.landed_safely.connect(_on_player_landed)
	player.crashed.connect(_on_player_crashed)
	
	camera.follow_target = player
	
	# Start at Main Menu
	go_to_main_menu()

func _process(_delta: float) -> void:
	if background and camera:
		background.update_camera_offset(camera.global_position)
	# Drive terrain streaming each frame — gives the "travelling world" feel.
	# Pass the camera's current world-space X so chunks spawn ahead and recycle behind.
	if current_state == GameState.PLAYING or current_state == GameState.COUNTDOWN:
		world_gen.update_terrain_streaming(camera.global_position.x)

func go_to_main_menu() -> void:
	current_state = GameState.MAIN_MENU
	get_tree().paused = false
	player.set_control_enabled(false)
	
	current_pad = 0
	consecutive_perfects = 0
	current_zone_idx = 0
	
	# Reset environment to Solar Valley baseline
	var zone0 = SunZoneData.get_zone_by_index(0)
	if background and background.has_method("apply_zone_visuals_instant"):
		background.apply_zone_visuals_instant(zone0)
	
	# Reset world and place player on start pad
	var start_pad = world_gen.initialize_world(player)
	player.spawn_on_platform(start_pad)
	if camera:
		camera.global_position = Vector2(start_pad.global_position.x, start_pad.global_position.y + camera.default_vertical_offset)
	_update_target_platform(1)
	
	hud.update_progress(current_pad, SunZoneData.TOTAL_PADS, best_pad)
	hud.show_main_menu(best_pad)
	print("[GAME_STATE] Transitioned to MAIN_MENU")

func _on_play_game_requested() -> void:
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
	print("[GAME_STATE] Transitioned to PAUSED")

func _on_resume_game_requested() -> void:
	if current_state != GameState.PAUSED:
		return
	current_state = GameState.PLAYING
	get_tree().paused = false
	hud.hide_pause_menu()
	player.set_control_enabled(true)
	print("[GAME_STATE] Resumed to PLAYING")

func _on_retry_game_requested() -> void:
	get_tree().paused = false
	hud.hide_pause_menu()
	hud.hide_game_over()
	
	# Cleanly reset run
	current_pad = 0
	consecutive_perfects = 0
	current_zone_idx = 0
	hud.update_progress(0, SunZoneData.TOTAL_PADS, best_pad)
	
	# Reset environment to Solar Valley baseline
	var zone0 = SunZoneData.get_zone_by_index(0)
	if background and background.has_method("apply_zone_visuals_instant"):
		background.apply_zone_visuals_instant(zone0)
	
	var start_pad = world_gen.initialize_world(player)
	player.spawn_on_platform(start_pad)
	_update_target_platform(1)
	
	_start_countdown_and_play()
	print("[GAME_STATE] Retrying game - fresh run started")

func _on_home_game_requested() -> void:
	go_to_main_menu()

func _update_target_platform(next_idx: int) -> void:
	var next_pad = world_gen.get_platform_by_index(next_idx)
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
		current_pad = solar_platform.platform_index
		
		if is_perfect:
			consecutive_perfects += 1
		else:
			consecutive_perfects = 0
		
		var is_new_best = current_pad > best_pad
		if is_new_best:
			best_pad = current_pad
			save_best_score()
			
		hud.update_progress(current_pad, SunZoneData.TOTAL_PADS, best_pad)
		
		# Zone transition check (triggered AFTER landing confirmation)
		var new_zone_idx = SunZoneData.get_zone_index(current_pad)
		if new_zone_idx != current_zone_idx:
			current_zone_idx = new_zone_idx
			var zone = SunZoneData.get_zone_by_index(new_zone_idx)
			
			# Zone arrival banner
			hud.show_zone_arrival_banner(zone)
			sound_manager.play_record()
			
			# Smooth 2.0s environment transition
			if background and background.has_method("transition_to_zone"):
				background.transition_to_zone(zone, 2.0)
				
			print("[JOURNEY] Entered %s! (Zone %d)" % [zone["name"], new_zone_idx])
		
		# Journey completion check
		if SunZoneData.is_journey_complete(current_pad):
			hud.show_journey_complete(current_pad, SunZoneData.TOTAL_PADS)
			sound_manager.play_record()
			print("[JOURNEY] ☀️ SUN JOURNEY COMPLETE! %d / %d" % [current_pad, SunZoneData.TOTAL_PADS])
			
		var alert_text = "PERFECT! PAD %d" % current_pad if is_perfect else "LANDED! PAD %d" % current_pad
		hud.show_landing_alert(alert_text, is_perfect)
		solar_platform.on_player_landed(is_perfect)
		world_gen.on_platform_reached(solar_platform)
		
		# Target next pad along the continuous route
		_update_target_platform(current_pad + 1)
		camera.notify_landed(solar_platform)
		camera.add_trauma(0.18)
		sound_manager.play_land(is_perfect)

func _on_player_crashed(reason: String) -> void:
	if current_state != GameState.PLAYING:
		return
		
	current_state = GameState.GAME_OVER
	player.set_control_enabled(false)
	camera.add_trauma(0.85)
	
	var is_new = current_pad >= best_pad and current_pad > 0
	hud.show_game_over(current_pad, best_pad, is_new, reason)
	print("[GAME_STATE] Transitioned to GAME_OVER (Pad: %d, Reason: %s)" % [current_pad, reason])

func load_best_score() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			best_pad = file.get_32()
			file.close()
	else:
		best_pad = 0

func save_best_score() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_32(best_pad)
		file.close()
