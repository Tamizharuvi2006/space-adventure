extends SceneTree

func _init() -> void:
	print("--- Running FuelDroplets Multi-Tier 3-Color Flame Tests ---")
	var DropletsClass = load("res://scripts/fuel_droplets.gd")
	var droplets = DropletsClass.new()
	root.add_child(droplets)
	
	# Test 1: Solar Tier (76–100%)
	var pal_solar = droplets.get_current_palette(90.0)
	assert(pal_solar.outer.r > 0.9 and pal_solar.outer.g > 0.3, "Solar outer must be orange")
	assert(pal_solar.middle.g > 0.7, "Solar middle must be gold/yellow")
	assert(pal_solar.core.r > 0.95 and pal_solar.core.g > 0.95, "Solar core must be soft white")
	print("  ✅ TEST 1 PASSED: 76–100% Solar Flame palette verified (Orange -> Gold -> White).")
	
	# Test 2: Plasma Blue Tier (51–75%)
	var pal_plasma = droplets.get_current_palette(65.0)
	assert(pal_plasma.outer.b > 0.8 and pal_plasma.outer.r < 0.2, "Plasma outer must be deep blue")
	assert(pal_plasma.middle.b > 0.9 and pal_plasma.middle.g > 0.7, "Plasma middle must be bright cyan")
	assert(pal_plasma.core.r > 0.8 and pal_plasma.core.b > 0.9, "Plasma core must be pale blue/white")
	print("  ✅ TEST 2 PASSED: 51–75% Plasma Blue palette verified (Deep Blue -> Cyan -> White).")
	
	# Test 3: Void Violet Tier (26–50%)
	var pal_violet = droplets.get_current_palette(40.0)
	assert(pal_violet.outer.r > 0.4 and pal_violet.outer.b > 0.7, "Void outer must be deep purple")
	assert(pal_violet.middle.r > 0.7 and pal_violet.middle.b > 0.9, "Void middle must be violet")
	assert(pal_violet.core.r > 0.9 and pal_violet.core.b > 0.9, "Void core must be pink-white")
	print("  ✅ TEST 3 PASSED: 26–50% Void Violet palette verified (Purple -> Violet -> Pink-White).")
	
	# Test 4: Danger Flame Tier (1–25%)
	var pal_danger = droplets.get_current_palette(15.0)
	assert(pal_danger.outer.r > 0.85 and pal_danger.outer.g < 0.2, "Danger outer must be deep red")
	assert(pal_danger.middle.r > 0.9 and pal_danger.middle.g > 0.4, "Danger middle must be hot orange")
	assert(pal_danger.core.r > 0.9 and pal_danger.core.g > 0.85, "Danger core must be bright yellow/white")
	print("  ✅ TEST 4 PASSED: 1–25% Danger Flame palette verified (Red -> Hot Orange -> Yellow-White).")
	
	# Test 5: Smooth Transition across boundaries
	var pal_trans_75 = droplets.get_current_palette(75.0)
	assert(pal_trans_75.outer.b > 0.2 and pal_trans_75.outer.r > 0.4, "75% boundary must smoothly blend blue & orange")
	var pal_trans_50 = droplets.get_current_palette(50.0)
	assert(pal_trans_50.outer.b > 0.4 and pal_trans_50.outer.r > 0.2, "50% boundary must smoothly blend violet & blue")
	var pal_trans_25 = droplets.get_current_palette(25.0)
	assert(pal_trans_25.outer.r > 0.6 and pal_trans_25.outer.b > 0.2, "25% boundary must smoothly blend red & purple")
	print("  ✅ TEST 5 PASSED: Smooth transition blending verified across 75%, 50%, and 25% boundaries.")
	
	# Test 6: Continuous partial mapping & rendering
	for test_pct in [100.0, 75.0, 63.4, 27.8, 7.0, 0.0]:
		droplets.set_fuel_percent(test_pct, true)
		droplets._process(0.016)
		droplets.queue_redraw()
	print("  ✅ TEST 6 PASSED: Continuous fuel percentage setting & rendering execution verified.")
	
	print("🎉 ALL FUEL DROPLETS 3-COLOR FLAME TESTS PASSED!")
	quit()
