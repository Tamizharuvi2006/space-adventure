extends Node

# Procedural Sound Manager for Explore Sun
# Generates dynamic retro/modern synth SFX at runtime using AudioStreamWAV buffers.

var thruster_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var chime_player: AudioStreamPlayer

var thruster_stream: AudioStreamWAV
var land_stream: AudioStreamWAV
var perfect_land_stream: AudioStreamWAV
var crash_stream: AudioStreamWAV
var warning_stream: AudioStreamWAV
var click_stream: AudioStreamWAV
var record_stream: AudioStreamWAV

func _ready() -> void:
	thruster_player = AudioStreamPlayer.new()
	sfx_player = AudioStreamPlayer.new()
	chime_player = AudioStreamPlayer.new()
	
	add_child(thruster_player)
	add_child(sfx_player)
	add_child(chime_player)
	
	_generate_audio_streams()

func _generate_audio_streams() -> void:
	thruster_stream = _create_thruster_sound()
	land_stream = _create_chime_sound([523.25, 659.25, 783.99], 0.35) # C5, E5, G5
	perfect_land_stream = _create_chime_sound([523.25, 659.25, 783.99, 1046.50], 0.55) # C-E-G-C major chord
	crash_stream = _create_crash_sound()
	warning_stream = _create_beep_sound(880.0, 0.1)
	click_stream = _create_beep_sound(1200.0, 0.04)
	record_stream = _create_chime_sound([523.25, 659.25, 783.99, 1046.50, 1318.51], 0.75)

func play_thruster(active: bool) -> void:
	if active:
		if not thruster_player.playing:
			thruster_player.stream = thruster_stream
			thruster_player.volume_db = -10.0
			thruster_player.play()
	else:
		if thruster_player.playing:
			thruster_player.stop()

func play_land(is_perfect: bool = false) -> void:
	chime_player.stream = perfect_land_stream if is_perfect else land_stream
	chime_player.volume_db = -4.0
	chime_player.play()

func play_crash() -> void:
	sfx_player.stream = crash_stream
	sfx_player.volume_db = -2.0
	sfx_player.play()

func play_warning() -> void:
	if not sfx_player.playing:
		sfx_player.stream = warning_stream
		sfx_player.volume_db = -6.0
		sfx_player.play()

func play_click() -> void:
	sfx_player.stream = click_stream
	sfx_player.volume_db = -8.0
	sfx_player.play()

func play_record() -> void:
	chime_player.stream = record_stream
	chime_player.volume_db = -3.0
	chime_player.play()

# Generate noise-based thruster hum
func _create_thruster_sound() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.5
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples * 2) # 16-bit
	
	var last_val = 0.0
	for i in range(num_samples):
		# Low-passed filtered white noise + low hum
		var white = randf_range(-1.0, 1.0)
		last_val = lerpf(last_val, white, 0.25)
		var hum = sin(float(i) / sample_rate * TAU * 110.0) * 0.35
		var sample = clampf((last_val * 0.65 + hum), -1.0, 1.0)
		var val_16 = int(sample * 24000.0)
		data.encode_s16(i * 2, val_16)
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = num_samples
	wav.data = data
	return wav

# Generate melodic bell/chime chord
func _create_chime_sound(frequencies: Array, duration: float) -> AudioStreamWAV:
	var sample_rate = 44100
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var t = float(i) / float(sample_rate)
		var envelope = exp(-5.0 * (t / duration)) # Exponential decay
		var sample = 0.0
		for freq in frequencies:
			sample += sin(t * TAU * freq)
		sample = (sample / float(frequencies.size())) * envelope
		var val_16 = int(clampf(sample, -1.0, 1.0) * 28000.0)
		data.encode_s16(i * 2, val_16)
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

# Generate deep impact explosion
func _create_crash_sound() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.7
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var t = float(i) / float(sample_rate)
		var envelope = exp(-4.0 * (t / duration))
		var noise = randf_range(-1.0, 1.0)
		var pitch = lerpf(120.0, 35.0, t / duration)
		var boom = sin(t * TAU * pitch)
		var sample = (boom * 0.7 + noise * 0.3) * envelope
		var val_16 = int(clampf(sample, -1.0, 1.0) * 30000.0)
		data.encode_s16(i * 2, val_16)
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

# Generate warning blip
func _create_beep_sound(freq: float, duration: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var t = float(i) / float(sample_rate)
		var sample = sin(t * TAU * freq) * 0.5
		var val_16 = int(sample * 25000.0)
		data.encode_s16(i * 2, val_16)
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav
