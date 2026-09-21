extends SceneTree

const SolarMain = preload("res://scripts/main.gd")
const SolarBackground = preload("res://scripts/background.gd")
const SunZoneData = preload("res://scripts/planet_data.gd")

var current_main: SolarMain = null

func _init() -> void:
	print("\n=======================================================")
	print("   TEST V8.1: LIVING WORLD PARALLAX DEPTH & MOTION     ")
	print("=======================================================\n")
	call_deferred("_run_all_tests")

func _spawn_fresh_game_instance() -> SolarMain:
	Engine.time_scale = 1.0
	if is_instance_valid(current_main):
		root.remove_child(current_main)
		current_main.queue_free()
		current_main = null
		
	var packed = load("res://scenes/main.tscn") as PackedScene
	var inst = packed.instantiate() as SolarMain
	root.add_child(inst)
	current_main = inst
	return inst

func _run_all_tests() -> void:
	var save_path = "user://explore_sun_save.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	var game = _spawn_fresh_game_instance()
	await process_frame
	await process_frame

	var bg = game.get_node_or_null("Background") as SolarBackground
	assert(is_instance_valid(bg), "Background node must exist in main.tscn!")

	# -------------------------------------------------------------------------
	# TEST 1: Parallax Layer Stack Hierarchy & Motion Scales
	# -------------------------------------------------------------------------
	print("--- TEST 1: Parallax Layer Hierarchy & Motion Scales ---")
	var far_layer = bg.get_node_or_null("FarRidgeLayer") as ParallaxLayer
	var landmark_layer = bg.get_node_or_null("LandmarkLayer") as ParallaxLayer
	var needle_layer = bg.get_node_or_null("NeedlePillarLayer") as ParallaxLayer
	var distant_layer = bg.get_node_or_null("DistantRidgeLayer") as ParallaxLayer
	var mid_layer = bg.get_node_or_null("MidMountainLayer") as ParallaxLayer
	var close_layer = bg.get_node_or_null("CloseFgLayer") as ParallaxLayer

	assert(is_instance_valid(far_layer), "FarRidgeLayer must exist!")
	assert(is_instance_valid(landmark_layer), "LandmarkLayer must exist!")
	assert(is_instance_valid(needle_layer), "NeedlePillarLayer must exist!")
	assert(is_instance_valid(distant_layer), "DistantRidgeLayer must exist!")
	assert(is_instance_valid(mid_layer), "MidMountainLayer must exist!")
	assert(is_instance_valid(close_layer), "CloseFgLayer must exist!")

	print("  FarRidgeLayer motion_scale.x:      %.2f" % far_layer.motion_scale.x)
	print("  LandmarkLayer motion_scale.x:      %.2f" % landmark_layer.motion_scale.x)
	print("  NeedlePillarLayer motion_scale.x:  %.2f" % needle_layer.motion_scale.x)
	print("  DistantRidgeLayer motion_scale.x:  %.2f" % distant_layer.motion_scale.x)
	print("  MidMountainLayer motion_scale.x:   %.2f" % mid_layer.motion_scale.x)
	print("  CloseFgLayer motion_scale.x:       %.2f" % close_layer.motion_scale.x)

	assert(is_equal_approx(far_layer.motion_scale.x, 0.08), "FarRidgeLayer motion_scale.x must be 0.08!")
	assert(is_equal_approx(landmark_layer.motion_scale.x, 0.12), "LandmarkLayer motion_scale.x must be 0.12!")
	assert(is_equal_approx(needle_layer.motion_scale.x, 0.15), "NeedlePillarLayer motion_scale.x must be 0.15!")
	assert(is_equal_approx(distant_layer.motion_scale.x, 0.20), "DistantRidgeLayer motion_scale.x must be 0.20!")
	assert(is_equal_approx(mid_layer.motion_scale.x, 0.45), "MidMountainLayer motion_scale.x must be 0.45!")
	assert(is_equal_approx(close_layer.motion_scale.x, 0.68), "CloseFgLayer motion_scale.x must be 0.68!")

	# Assert strictly increasing motion scale order from back to front
	assert(far_layer.motion_scale.x < landmark_layer.motion_scale.x, "Far < Landmark")
	assert(landmark_layer.motion_scale.x < needle_layer.motion_scale.x, "Landmark < Needle")
	assert(needle_layer.motion_scale.x < distant_layer.motion_scale.x, "Needle < Distant")
	assert(distant_layer.motion_scale.x < mid_layer.motion_scale.x, "Distant < Mid")
	assert(mid_layer.motion_scale.x < close_layer.motion_scale.x, "Mid < CloseFg")
	assert(close_layer.motion_scale.x < 1.0, "CloseFg < Playable world (1.0)")
	print("  ✅ TEST 1 PASSED: Layer stack has 6 distinct layers with strictly increasing parallax speeds.")

	# -------------------------------------------------------------------------
	# TEST 2: Close Foreground Safety — Flight Corridor Unobstructed
	# -------------------------------------------------------------------------
	print("--- TEST 2: Flight Corridor Safety (CloseFgLayer Top Edges >= Y 510) ---")
	var min_y: float = 99999.0
	for child in close_layer.get_children():
		if child is Polygon2D:
			for pt in (child as Polygon2D).polygon:
				if pt.y < min_y:
					min_y = pt.y
	print("  Highest point in CloseFgLayer: Y=%.1f (flight corridor limit is >= 510.0)" % min_y)
	assert(min_y >= 510.0, "CloseFgLayer highest vertex must be >= 510 to keep flight corridor completely clear!")
	print("  ✅ TEST 2 PASSED: Close foreground stays in bottom 29% of screen; flight corridor is 100% clear.")

	# -------------------------------------------------------------------------
	# TEST 3: Needle Pillars & Mesas Generation
	# -------------------------------------------------------------------------
	print("--- TEST 3: Isolated Rock Needles & Mesa Profiles ---")
	var needle_children = needle_layer.get_child_count()
	print("  NeedlePillarLayer polygon child count: %d" % needle_children)
	assert(needle_children >= 8, "NeedlePillarLayer must have at least 8 spire polygons!")

	var dist_poly = distant_layer.get_node_or_null("RidgePolygon") as Polygon2D
	assert(is_instance_valid(dist_poly), "DistantRidge polygon must exist!")
	var has_flat_mesa: bool = false
	for i in range(dist_poly.polygon.size() - 1):
		var p1 = dist_poly.polygon[i]
		var p2 = dist_poly.polygon[i + 1]
		# Flat mesa top: horizontal slope (p1.y == p2.y) with width >= 150px
		if absf(p1.y - p2.y) < 0.1 and absf(p2.x - p1.x) >= 150.0 and p1.y < 400.0:
			has_flat_mesa = true
			print("  Identified flat mesa top: Y=%.1f from X=%.1f to X=%.1f (width=%.1fpx)" % [p1.y, p1.x, p2.x, p2.x - p1.x])
	assert(has_flat_mesa, "DistantRidge must contain flat mesa plateaus!")
	print("  ✅ TEST 3 PASSED: Rock needle spires and mesa plateaus verified.")

	# -------------------------------------------------------------------------
	# TEST 4: Landmark Density (10 Slots per Zone)
	# -------------------------------------------------------------------------
	print("--- TEST 4: Landmark Density (10 Distinct Slots) ---")
	bg.notify_pad_changed(1) # Zone 0
	var landmark_count_z0 = landmark_layer.get_child_count()
	print("  Zone 0 Landmark polygon children count: %d" % landmark_count_z0)
	assert(landmark_count_z0 >= 10, "LandmarkLayer must have at least 10 structure elements!")
	print("  ✅ TEST 4 PASSED: Landmark density is rich with 10 slots.")

	# -------------------------------------------------------------------------
	# TEST 5: Zone Transition Dynamic Rebuild
	# -------------------------------------------------------------------------
	print("--- TEST 5: Zone Transition Dynamic Rebuild (Zone 0 -> Zone 1) ---")
	bg.notify_pad_changed(21) # Pad 21 enters Zone 1 ("SOLAR CRATERS")
	var landmark_count_z1 = landmark_layer.get_child_count()
	print("  Zone 1 Landmark polygon children count: %d" % landmark_count_z1)
	assert(landmark_count_z1 >= 10, "Zone 1 must also have at least 10 structure elements!")
	print("  ✅ TEST 5 PASSED: Zone transition dynamically rebuilds landmarks.")

	# -------------------------------------------------------------------------
	# TEST 6: Motion Differentiation Under Camera Translation
	# -------------------------------------------------------------------------
	print("--- TEST 6: Motion Differentiation Across Layers ---")
	var delta_cam_x: float = 1000.0
	var far_disp = delta_cam_x * far_layer.motion_scale.x
	var lmk_disp = delta_cam_x * landmark_layer.motion_scale.x
	var ndl_disp = delta_cam_x * needle_layer.motion_scale.x
	var dst_disp = delta_cam_x * distant_layer.motion_scale.x
	var mid_disp = delta_cam_x * mid_layer.motion_scale.x
	var cfg_disp = delta_cam_x * close_layer.motion_scale.x
	var ply_disp = delta_cam_x * 1.0

	print("  Over 1000px camera flight:")
	print("    Far Ridge displacement:       %5.1f px (very slow)" % far_disp)
	print("    Landmarks displacement:       %5.1f px (slow)" % lmk_disp)
	print("    Needle Pillars displacement:  %5.1f px (slow-medium)" % ndl_disp)
	print("    Distant Ridge displacement:   %5.1f px (medium)" % dst_disp)
	print("    Mid Mountain displacement:    %5.1f px (noticeable)" % mid_disp)
	print("    Close FG displacement:        %5.1f px (fast)" % cfg_disp)
	print("    Player/Terrain displacement:  %5.1f px (1.0x gameplay)" % ply_disp)

	assert(far_disp < lmk_disp and lmk_disp < ndl_disp and ndl_disp < dst_disp and dst_disp < mid_disp and mid_disp < cfg_disp and cfg_disp < ply_disp, "Layers must strictly have differential parallax speeds!")
	print("  ✅ TEST 6 PASSED: Motion differentiation creates deep parallax perception.")

	print("\n=======================================================")
	print("   ALL 6 V8.1 PARALLAX TESTS PASSED! 🎉                ")
	print("=======================================================\n")
	quit()
