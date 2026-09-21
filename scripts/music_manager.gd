extends Node
## MusicManager — Sci-Fi Exploration Soundtrack for Explore Sun V8.3
## Real musical composition: 16 bars @ 70 BPM (54.86s seamless loop)
## Chords: Dm7 -> Bbmaj7 -> F -> C -> Dm9 -> Bbmaj7 -> F -> Csus4 -> Gm7 -> Am7 -> Bbmaj7 -> C -> Dm
## Layers: Melodic electric piano/pluck motif, lush analog pads, sub bass, heartbeat kick & space rim pulse.

const SAMPLE_RATE: int = 44100
const BPM: float = 70.0
const BEAT_S: float = 60.0 / BPM
const BAR_S: float = BEAT_S * 4.0
const TOTAL_BARS: int = 16
const LOOP_DURATION_S: float = BAR_S * float(TOTAL_BARS) # 54.857142857 s
const SOUNDTRACK_PATH: String = "res://assets/audio/soundtrack.wav"
const TABLE_SIZE: int = 2048

# Music volume in dB — user-adjustable via pause menu slider
var music_volume_db: float = -15.0
var _base_volume_db: float = -15.0  # target nominal (default 70% slider = -15 dB)

# Zone volume tints (delta dB added on top of base)
const ZONE_VOLUME_TINT: Array[float] = [-0.0, -0.0, 1.5, -1.5, 2.0]

var _music_player: AudioStreamPlayer
var _soundtrack_stream: AudioStreamWAV = null
var _gen_thread: Thread = null

var music_volume_pct: float = 70.0
var _volume_tween: Tween = null
var _is_playing: bool = false
var _sine_table: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 1. Ensure dedicated 'Music' audio bus exists and routes to Master
	var music_bus_idx = AudioServer.get_bus_index("Music")
	if music_bus_idx == -1:
		AudioServer.add_bus()
		music_bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(music_bus_idx, "Music")
		AudioServer.set_bus_send(music_bus_idx, "Master")
	AudioServer.set_bus_mute(music_bus_idx, false)
	AudioServer.set_bus_volume_db(music_bus_idx, 0.0)

	var master_bus_idx = AudioServer.get_bus_index("Master")
	if master_bus_idx != -1:
		AudioServer.set_bus_mute(master_bus_idx, false)
		if AudioServer.get_bus_volume_db(master_bus_idx) < -30.0:
			AudioServer.set_bus_volume_db(master_bus_idx, 0.0)

	# 2. AudioStreamPlayer configuration
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "AmbientMusicPlayer"
	_music_player.bus = "Music"
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player.volume_db = -80.0
	add_child(_music_player)

	# 3. Load or generate the 54.86s seamless exploration soundtrack
	if FileAccess.file_exists(SOUNDTRACK_PATH):
		_soundtrack_stream = AudioStreamWAV.load_from_file(SOUNDTRACK_PATH)
		if _soundtrack_stream:
			_soundtrack_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			_soundtrack_stream.loop_begin = 0
			_soundtrack_stream.loop_end = int(LOOP_DURATION_S * SAMPLE_RATE)
			_music_player.stream = _soundtrack_stream
			print("[MUSIC] Loaded master sci-fi exploration soundtrack (%.2fs loop)" % _soundtrack_stream.get_length())
	
	if not _soundtrack_stream:
		# Fallback: synthesize in background thread without blocking main thread
		_gen_thread = Thread.new()
		_gen_thread.start(_bg_generate_soundtrack)

func _bg_generate_soundtrack() -> void:
	var stream = _generate_musical_soundtrack()
	_soundtrack_stream = stream
	call_deferred("_on_soundtrack_generated")

func _on_soundtrack_generated() -> void:
	if _music_player and _soundtrack_stream and not _music_player.stream:
		_music_player.stream = _soundtrack_stream
	print("[MUSIC] Soundtrack synthesized in background (%.2fs loop)" % [
		_soundtrack_stream.get_length() if _soundtrack_stream else 0.0
	])

func _exit_tree() -> void:
	if _gen_thread and _gen_thread.is_alive():
		_gen_thread.wait_to_finish()

# ─── Public API ──────────────────────────────────────────────────────────────

func play_ambient(fade_duration: float = 2.0) -> void:
	if _is_playing and _music_player and _music_player.playing:
		return
	if _gen_thread and _gen_thread.is_alive():
		_gen_thread.wait_to_finish()
	if _music_player and not _music_player.stream and _soundtrack_stream:
		_music_player.stream = _soundtrack_stream
	_is_playing = true
	_music_player.volume_db = -80.0
	_music_player.play()
	_fade_volume_to(_base_volume_db, fade_duration)

	print("[MUSIC] playback started (target: %.1f dB, fade: %.1fs)" % [_base_volume_db, fade_duration])
	print("[MUSIC] player.playing = %s" % [_music_player.playing])

func is_playing() -> bool:
	return _is_playing and _music_player != null and _music_player.playing

func stop_ambient(fade_duration: float = 1.0) -> void:
	if not _is_playing:
		return
	_is_playing = false
	_fade_volume_to(-80.0, fade_duration, func():
		_music_player.stop()
	)

func on_pause() -> void:
	if not _is_playing:
		return
	_fade_volume_to(-80.0, 0.8)

func on_resume() -> void:
	if not _is_playing:
		return
	_fade_volume_to(_base_volume_db, 0.8)

func on_crash() -> void:
	if not _is_playing:
		return
	_cancel_tween()
	var tween = create_tween().bind_node(self)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_music_player, "volume_db", -28.0, 0.15)

func on_rewind_complete() -> void:
	if not _is_playing:
		return
	_fade_volume_to(_base_volume_db, 0.9)

func on_land() -> void:
	if not _is_playing:
		return
	_cancel_tween()
	var tween = create_tween().bind_node(self)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_music_player, "volume_db", _base_volume_db + 2.0, 0.18)
	tween.tween_property(_music_player, "volume_db", _base_volume_db, 0.32)

func on_zone_changed(zone_idx: int) -> void:
	var tint: float = 0.0
	if zone_idx >= 0 and zone_idx < ZONE_VOLUME_TINT.size():
		tint = ZONE_VOLUME_TINT[zone_idx]
	_base_volume_db = music_volume_db + tint
	_fade_volume_to(_base_volume_db, 2.0)

## Called from HUD slider (value 0–100)
func set_music_volume_from_slider(value: float) -> void:
	music_volume_pct = clampf(value, 0.0, 100.0)
	if value <= 0.0:
		music_volume_db = -80.0
	else:
		# Maps 0..100 to -36 dB .. -6 dB (gentle atmospheric background)
		# At default 70%: -36 + 0.70 * 30 = -15 dB (~25-30% perceived loudness)
		music_volume_db = lerpf(-36.0, -6.0, value / 100.0)
	_base_volume_db = music_volume_db
	if _is_playing and _music_player:
		_cancel_tween()
		_music_player.volume_db = _base_volume_db

# ─── Internal helpers ─────────────────────────────────────────────────────────

func _fade_volume_to(target_db: float, duration: float, on_done: Callable = Callable()) -> void:
	_cancel_tween()
	_volume_tween = create_tween().bind_node(self)
	_volume_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_volume_tween.tween_property(_music_player, "volume_db", target_db, duration).set_trans(Tween.TRANS_SINE)
	if on_done.is_valid():
		_volume_tween.tween_callback(on_done)

func _cancel_tween() -> void:
	if _volume_tween and _volume_tween.is_valid():
		_volume_tween.kill()

# ─── Full Musical Soundtrack Synthesis Engine ─────────────────────────────────

func _generate_musical_soundtrack() -> AudioStreamWAV:
	if _sine_table.size() != TABLE_SIZE:
		_sine_table.resize(TABLE_SIZE)
		for i in range(TABLE_SIZE):
			_sine_table[i] = sin(float(i) / float(TABLE_SIZE) * TAU)

	var ns: int = int(LOOP_DURATION_S * SAMPLE_RATE)
	var xfade_samples: int = int(2.0 * SAMPLE_RATE)
	var total_samples: int = ns + xfade_samples

	var buf_l = PackedFloat32Array()
	var buf_r = PackedFloat32Array()
	buf_l.resize(total_samples)
	buf_r.resize(total_samples)

	# Frequencies
	var D2 = 73.416; var F2 = 87.307; var G2 = 97.999; var A2 = 110.000; var Bb2 = 116.541; var C3 = 130.813
	var D3 = 146.832; var E3 = 164.814; var F3 = 174.614; var G3 = 196.000; var A3 = 220.000; var Bb3 = 233.082; var C4 = 261.626
	var D4 = 293.665; var E4 = 329.628; var F4 = 349.228; var G4 = 392.000; var A4 = 440.000; var Bb4 = 466.164; var C5 = 523.251
	var D5 = 587.330; var E5 = 659.255; var F5 = 698.456; var G5 = 783.991; var A5 = 880.000

	# 16-Bar Chord Progression: Dm7 -> Bbmaj7 -> F -> C ...
	var chord_seq = [
		{"bass": D2,  "pad": [D3, F3, A3, C4]},       # Bar 1: Dm7
		{"bass": Bb2, "pad": [Bb2, D3, F3, A3]},      # Bar 2: Bbmaj7
		{"bass": F2,  "pad": [C3, F3, A3, C4]},       # Bar 3: F
		{"bass": C3,  "pad": [C3, E3, G3, C4]},       # Bar 4: C
		{"bass": D2,  "pad": [D3, F3, A3, E4]},       # Bar 5: Dm9
		{"bass": Bb2, "pad": [Bb2, D3, F3, A3]},      # Bar 6: Bbmaj7
		{"bass": F2,  "pad": [C3, F3, A3, C4]},       # Bar 7: F
		{"bass": C3,  "pad": [C3, F3, G3, E3]},       # Bar 8: Csus4 -> C
		{"bass": G2,  "pad": [G3, Bb3, D4, F4]},      # Bar 9: Gm7
		{"bass": A2,  "pad": [A3, C4, E4, G4]},       # Bar 10: Am7
		{"bass": Bb2, "pad": [Bb3, D4, F4, A4]},      # Bar 11: Bbmaj7
		{"bass": C3,  "pad": [C4, E4, G4, C5]},       # Bar 12: C
		{"bass": D2,  "pad": [D3, F3, A3, D4]},       # Bar 13: Dm
		{"bass": Bb2, "pad": [Bb2, F3, A3, D4]},      # Bar 14: Bbmaj7
		{"bass": F2,  "pad": [A2, C3, F3, C4]},       # Bar 15: F/A
		{"bass": C3,  "pad": [C3, D3, G3, C4]}        # Bar 16: Csus2
	]

	var table = _sine_table
	var t_size = float(TABLE_SIZE)
	var sr_f = float(SAMPLE_RATE)
	var t_size_i = TABLE_SIZE

	# 1. SYNTH PADS & SUB BASS
	for bar_idx in range(TOTAL_BARS):
		var chord = chord_seq[bar_idx]
		var bar_start_s = bar_idx * BAR_S
		var bar_start_i = int(bar_start_s * SAMPLE_RATE)
		var bar_len_i = int(BAR_S * SAMPLE_RATE)
		var bass_freq = chord["bass"]
		var pad_freqs = chord["pad"]
		var pad_dur_i = bar_len_i + int(SAMPLE_RATE * 0.75)

		for vi in range(pad_freqs.size()):
			var freq = pad_freqs[vi]
			var pan = -0.35 + 0.70 * (float(vi) / float(pad_freqs.size() - 1))
			var gain_l = (1.0 - pan) * 0.085
			var gain_r = (1.0 + pan) * 0.085

			var phase1: float = 0.0
			var phase2: float = 0.0
			var inc1 = freq * t_size / sr_f
			var inc2 = (freq + 0.22) * t_size / sr_f
			var end_sample = mini(bar_start_i + pad_dur_i, total_samples)

			for idx in range(bar_start_i, end_sample):
				var s = idx - bar_start_i
				var t = float(s) / sr_f
				var env = 1.0
				if t < 0.65:
					env = t / 0.65
				elif t > BAR_S:
					env = clampf(1.0 - (t - BAR_S) / 0.75, 0.0, 1.0)

				var o1 = table[int(phase1) % t_size_i]
				var o2 = table[int(phase2) % t_size_i]
				var val = (o1 * 0.65 + o2 * 0.35) * env
				buf_l[idx] += val * gain_l
				buf_r[idx] += val * gain_r
				phase1 += inc1
				phase2 += inc2

		var bass_phase: float = 0.0
		var bass_inc = bass_freq * t_size / sr_f
		var bass_oct_phase: float = 0.0
		var bass_oct_inc = (bass_freq * 2.0) * t_size / sr_f
		var bass_len_i = int(BAR_S * 0.95 * SAMPLE_RATE)
		var bass_end = mini(bar_start_i + bass_len_i, total_samples)

		for idx in range(bar_start_i, bass_end):
			var s = idx - bar_start_i
			var t = float(s) / sr_f
			var env = clampf(t / 0.08, 0.0, 1.0) * exp(-t * 0.40)
			var b1 = table[int(bass_phase) % t_size_i]
			var b2 = table[int(bass_oct_phase) % t_size_i]
			var bass_sig = (b1 * 0.78 + b2 * 0.22) * env * 0.17
			buf_l[idx] += bass_sig
			buf_r[idx] += bass_sig
			bass_phase += bass_inc
			bass_oct_phase += bass_oct_inc

	# 2. MELODIC LEAD MOTIF
	var melody_events = [
		[0, 2.0, A4, 1.8, 0.13], [1, 0.0, F4, 2.0, 0.14], [2, 2.0, D4, 1.8, 0.13], [3, 0.0, C5, 2.2, 0.15],
		[4, 0.0, A4, 1.6, 0.19], [4, 2.0, F4, 1.0, 0.16], [4, 3.0, D4, 1.0, 0.17],
		[5, 0.0, F4, 1.8, 0.19], [5, 2.0, D4, 1.0, 0.15], [5, 3.0, A4, 1.2, 0.18],
		[6, 0.0, C5, 1.8, 0.21], [6, 2.0, A4, 1.0, 0.17], [6, 3.0, G4, 1.0, 0.16],
		[7, 0.0, E4, 2.2, 0.19], [7, 2.5, D4, 1.4, 0.15],
		[8, 0.0, D5, 1.4, 0.18], [8, 1.5, F5, 1.2, 0.16], [8, 3.0, D5, 1.0, 0.15],
		[9, 0.0, E5, 1.6, 0.19], [9, 2.0, C5, 1.2, 0.17], [9, 3.0, A4, 1.0, 0.15],
		[10, 0.0, F5, 1.8, 0.20], [10, 2.0, D5, 1.2, 0.17], [10, 3.0, F5, 1.0, 0.16],
		[11, 0.0, G5, 2.0, 0.22], [11, 2.0, E5, 1.4, 0.18],
		[12, 0.0, A4, 2.2, 0.17], [12, 2.5, F4, 1.2, 0.14],
		[13, 0.0, D4, 2.4, 0.16],
		[14, 0.0, F4, 2.2, 0.17], [14, 2.0, A4, 1.4, 0.16],
		[15, 0.0, C5, 2.6, 0.19], [15, 2.5, A4, 1.8, 0.15]
	]

	for ev in melody_events:
		var bar_i = ev[0]; var beat_off = ev[1]; var freq = ev[2]; var dur_s = ev[3]; var vel = ev[4]
		var start_s = (bar_i * BAR_S) + (beat_off * BEAT_S)
		var start_i = int(start_s * SAMPLE_RATE)
		var len_i = int(dur_s * SAMPLE_RATE)
		var end_sample = mini(start_i + len_i, total_samples)

		var p1: float = 0.0; var p2: float = 0.0; var p3: float = 0.0
		var inc1 = freq * t_size / sr_f
		var inc2 = (freq * 2.002) * t_size / sr_f
		var inc3 = (freq * 3.004) * t_size / sr_f
		var decay_rate = 3.2 / dur_s

		for idx in range(start_i, end_sample):
			var s = idx - start_i
			var t = float(s) / sr_f
			var env = clampf(t / 0.008, 0.0, 1.0) * exp(-t * decay_rate)
			var o1 = table[int(p1) % t_size_i]
			var o2 = table[int(p2) % t_size_i]
			var o3 = table[int(p3) % t_size_i]
			var sig = (o1 * 0.70 + o2 * 0.20 + o3 * 0.10) * env * vel
			buf_l[idx] += sig * 0.85
			buf_r[idx] += sig * 0.85
			p1 += inc1; p2 += inc2; p3 += inc3

			var d_l = idx + int(0.28 * SAMPLE_RATE)
			var d_r = idx + int(0.42 * SAMPLE_RATE)
			if d_l < total_samples:
				buf_l[d_l] += sig * 0.26
			if d_r < total_samples:
				buf_r[d_r] += sig * 0.26

	# 3. LIGHT RHYTHMIC PULSE
	for bar_idx in range(2, 15):
		for beat_idx in range(4):
			var pulse_s = (bar_idx * BAR_S) + (beat_idx * BEAT_S)
			var start_i = int(pulse_s * SAMPLE_RATE)

			if beat_idx == 0 or (beat_idx == 2 and bar_idx >= 4):
				var k_len = int(0.16 * SAMPLE_RATE)
				var k_end = mini(start_i + k_len, total_samples)
				var k_phase: float = 0.0
				for idx in range(start_i, k_end):
					var s = idx - start_i
					var t = float(s) / sr_f
					var p_freq = lerpf(85.0, 42.0, t / 0.16)
					var k_env = clampf(t / 0.005, 0.0, 1.0) * exp(-t * 24.0)
					k_phase += p_freq * t_size / sr_f
					var k_sig = table[int(k_phase) % t_size_i] * k_env * 0.12
					buf_l[idx] += k_sig
					buf_r[idx] += k_sig

			if (beat_idx == 1 or beat_idx == 3) and bar_idx >= 4 and bar_idx <= 12:
				var t_len = int(0.04 * SAMPLE_RATE)
				var t_end = mini(start_i + t_len, total_samples)
				var t_p1: float = 0.0; var t_p2: float = 0.0
				var t_inc1 = 4800.0 * t_size / sr_f
				var t_inc2 = 6200.0 * t_size / sr_f
				for idx in range(start_i, t_end):
					var s = idx - start_i
					var t = float(s) / sr_f
					var t_env = exp(-t * 75.0)
					var o1 = table[int(t_p1) % t_size_i]
					var o2 = table[int(t_p2) % t_size_i]
					var t_sig = (o1 * 0.6 + o2 * 0.4) * t_env * 0.038
					buf_l[idx] += t_sig * 0.7
					buf_r[idx] += t_sig * 1.0
					t_p1 += t_inc1; t_p2 += t_inc2

	# 4. EQUAL-POWER CROSSFADE OF TAIL INTO HEAD
	for i in range(xfade_samples):
		var alpha: float = float(i) / float(xfade_samples)
		var head_gain: float = sqrt(alpha)
		var tail_gain: float = sqrt(1.0 - alpha)
		buf_l[i] = buf_l[i] * head_gain + buf_l[ns + i] * tail_gain
		buf_r[i] = buf_r[i] * head_gain + buf_r[ns + i] * tail_gain

	# 5. ENCODE TO 16-BIT STEREO PCM
	var data = PackedByteArray()
	data.resize(ns * 4)
	for i in range(ns):
		var s_l = clampf(buf_l[i], -0.98, 0.98)
		var s_r = clampf(buf_r[i], -0.98, 0.98)
		data.encode_s16(i * 4,     int(s_l * 28000.0))
		data.encode_s16(i * 4 + 2, int(s_r * 28000.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = true
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = ns
	wav.data = data
	return wav
