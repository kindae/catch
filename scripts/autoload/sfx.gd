## Audio 100 % procédural et original : les sons sont synthétisés au démarrage
## (aucun fichier audio externe). La musique (rythme rumba/seben originale) est
## générée dans un thread pour ne pas bloquer le démarrage.
extends Node

const RATE := 22050
const BPM := 132.0
const POOL_SIZE := 10

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _crowd: AudioStreamPlayer
var _music_task := -1
var _music_data: PackedFloat32Array
var _rng := RandomNumberGenerator.new()
var music_wanted := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 243
	_setup_buses()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	_music.volume_db = -4.0
	add_child(_music)
	_crowd = AudioStreamPlayer.new()
	_crowd.bus = &"SFX"
	_crowd.volume_db = -12.0
	add_child(_crowd)
	_build_sfx()
	_music_task = WorkerThreadPool.add_task(_generate_music)
	Settings._apply_audio()

func _setup_buses() -> void:
	for n in ["Music", "SFX"]:
		if AudioServer.get_bus_index(n) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, n)
			AudioServer.set_bus_send(i, &"Master")

func _process(_dt: float) -> void:
	if _music_task >= 0 and WorkerThreadPool.is_task_completed(_music_task):
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
		_music.stream = _to_wav(_music_data, true)
		_music_data = PackedFloat32Array()
		if music_wanted:
			_music.play()

func play(name: StringName, pitch_var := 0.06, vol_db := 0.0) -> void:
	var s: AudioStream = _streams.get(name)
	if s == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.pitch_scale = 1.0 + _rng.randf_range(-pitch_var, pitch_var)
	p.volume_db = vol_db
	p.play()

func play_music(on: bool) -> void:
	music_wanted = on
	if on:
		if _music.stream and not _music.playing:
			_music.play()
	else:
		_music.stop()

func play_crowd(on: bool) -> void:
	if on and not _crowd.playing:
		_crowd.stream = _streams[&"crowd_loop"]
		_crowd.play()
	elif not on:
		_crowd.stop()

func crowd_intensity(v: float) -> void:
	_crowd.volume_db = lerpf(-16.0, -5.0, clampf(v, 0.0, 1.0))

# ---------------------------------------------------------------- synthèse
func _env(t: float, a: float, d: float) -> float:
	if t < a:
		return t / a
	return exp(-(t - a) * d)

func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b

func _build_sfx() -> void:
	var b: PackedFloat32Array
	# Coup léger : bruit filtré + impact grave
	b = _buf(0.14)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1, 1) - lp) * 0.35
		b[i] = (lp * 0.9 + sin(TAU * (150.0 - t * 400.0) * t) * 0.8) * _env(t, 0.002, 38.0)
	_streams[&"hit_light"] = _to_wav(b)
	# Coup lourd
	b = _buf(0.32)
	lp = 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1, 1) - lp) * 0.18
		b[i] = (lp * 1.1 + sin(TAU * (95.0 - t * 120.0) * t) * 1.0) * _env(t, 0.003, 14.0)
	_streams[&"hit_heavy"] = _to_wav(b)
	# Blocage : claquement sec
	b = _buf(0.1)
	lp = 0.0
	for i in b.size():
		var t := float(i) / RATE
		var n := _rng.randf_range(-1, 1)
		lp += (n - lp) * 0.5
		b[i] = ((n - lp) * 0.8 + sin(TAU * 900.0 * t) * 0.3) * _env(t, 0.001, 50.0)
	_streams[&"block"] = _to_wav(b)
	# Souffle (coup dans le vide)
	b = _buf(0.2)
	lp = 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1, 1) - lp) * (0.05 + t * 0.8)
		b[i] = lp * sin(PI * t / 0.2) * 0.9
	_streams[&"whoosh"] = _to_wav(b)
	# Chute sur le tapis + vibration des cordes
	b = _buf(0.6)
	lp = 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1, 1) - lp) * 0.12
		var thump := sin(TAU * (60.0 - t * 40.0) * t) * _env(t, 0.002, 9.0)
		var rope := sin(TAU * 180.0 * t) * sin(TAU * 7.0 * t) * _env(t, 0.01, 6.0) * 0.25
		b[i] = (lp * _env(t, 0.002, 10.0) * 1.2 + thump * 1.2 + rope)
	_streams[&"slam"] = _to_wav(b)
	# Pouvoir mystique : montée + vibrato
	b = _buf(0.7)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * (220.0 + t * 700.0 + sin(TAU * 18.0 * t) * 30.0) / RATE
		b[i] = (sin(ph) * 0.5 + sin(ph * 1.5) * 0.25 + _rng.randf_range(-0.2, 0.2)) * sin(PI * t / 0.7)
	_streams[&"power"] = _to_wav(b)
	# Électricité
	b = _buf(0.5)
	for i in b.size():
		var t := float(i) / RATE
		var buzz := signf(sin(TAU * 70.0 * t)) * 0.3
		var crackle := _rng.randf_range(-1, 1) * (1.0 if _rng.randf() < 0.15 else 0.2)
		b[i] = (buzz + crackle * 0.6) * _env(t, 0.005, 4.0)
	_streams[&"zap"] = _to_wav(b)
	# Transformation : accord qui enfle
	b = _buf(1.4)
	for i in b.size():
		var t := float(i) / RATE
		var s := 0.0
		for f in [110.0, 164.8, 220.0, 277.2, 329.6]:
			s += sin(TAU * f * t * (1.0 + t * 0.05))
		var trem := 0.7 + 0.3 * sin(TAU * (4.0 + t * 10.0) * t)
		b[i] = (s * 0.16 * trem + _rng.randf_range(-1, 1) * 0.25 * t) * minf(t * 2.0, 1.0) * clampf((1.4 - t) * 4.0, 0.0, 1.0)
	_streams[&"transform"] = _to_wav(b)
	# Cloche du ring
	b = _buf(1.2)
	for i in b.size():
		var t := float(i) / RATE
		var s := 0.0
		for k in [[1.0, 1.0], [2.01, 0.5], [3.12, 0.3], [4.7, 0.15]]:
			s += sin(TAU * 830.0 * k[0] * t) * k[1]
		var t2 := fmod(t, 0.35)
		b[i] = s * 0.35 * _env(t2, 0.001, 5.0)
	_streams[&"bell"] = _to_wav(b)
	# K.O. : impact + cloche grave
	b = _buf(1.0)
	lp = 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1, 1) - lp) * 0.1
		b[i] = lp * _env(t, 0.002, 6.0) + sin(TAU * 55.0 * t) * _env(t, 0.002, 4.0) + sin(TAU * 220.0 * t) * 0.3 * _env(t, 0.01, 3.0)
	_streams[&"ko"] = _to_wav(b)
	# Clic d'interface
	b = _buf(0.05)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * 1400.0 * t) * _env(t, 0.001, 90.0) * 0.6
	_streams[&"ui"] = _to_wav(b)
	# Foule : rumeur en boucle
	b = _buf(4.0)
	var lp1 := 0.0
	var lp2 := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var n := _rng.randf_range(-1, 1)
		lp1 += (n - lp1) * 0.08
		lp2 += (lp1 - lp2) * 0.3
		var mod := 0.7 + 0.2 * sin(TAU * 0.5 * t) + 0.1 * sin(TAU * 1.75 * t + 1.0)
		b[i] = (lp1 - lp2 * 0.5) * mod * 1.6
	_streams[&"crowd_loop"] = _to_wav(b, true)
	# Acclamation
	b = _buf(1.8)
	lp1 = 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp1 += (_rng.randf_range(-1, 1) - lp1) * 0.25
		b[i] = lp1 * sin(PI * t / 1.8) * (0.8 + 0.2 * sin(TAU * 9.0 * t)) * 1.4
	_streams[&"cheer"] = _to_wav(b)

## Boucle musicale originale : 4 mesures de rythme inspiré de la rumba/seben
## (grosse caisse, caisse claire, shaker, basse et guitare/likembe en
## Karplus-Strong sur une gamme pentatonique).
func _generate_music() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1960
	var beat := 60.0 / BPM
	var bars := 4
	var n := int(bars * 4 * beat * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var step := beat / 4.0
	var steps := bars * 16
	# Batterie
	for s in steps:
		var t0 := int(s * step * RATE)
		var in_bar := s % 16
		if in_bar in [0, 6, 8, 14]:
			_add_kick(out, t0)
		if in_bar in [4, 12]:
			_add_snare(out, t0, rng, 0.45)
		if in_bar in [10] and (s / 16) % 2 == 1:
			_add_snare(out, t0, rng, 0.25)
		_add_shaker(out, t0, rng, 0.12 if s % 2 == 0 else 0.07)
	# Basse
	var bass_line := [55.0, 0.0, 0.0, 55.0, 0.0, 0.0, 73.4, 0.0, 82.4, 0.0, 0.0, 73.4, 0.0, 65.4, 0.0, 0.0]
	var roots := [1.0, 1.0, 1.335, 1.122]
	for s in steps:
		var f: float = bass_line[s % 16]
		if f > 0.0:
			_add_bass(out, int(s * step * RATE), f * roots[s / 16], step * 2.5)
	# Guitare seben / likembe (Karplus-Strong)
	var scale := [440.0, 493.9, 554.4, 659.3, 740.0, 880.0, 987.8, 1108.7]
	var pattern := [0, 2, 4, 2, 5, 4, 2, 4, 3, 5, 7, 5, 4, 2, 3, 1]
	for s in steps:
		var bar := s / 16
		var idx: int = pattern[(s + bar * 3) % 16]
		var f2: float = scale[idx] * (roots[bar] if roots[bar] < 1.3 else roots[bar] * 0.5)
		_add_pluck(out, int(s * step * RATE), f2 * 0.5, 0.17, rng)
	# Normalisation douce
	var peak := 0.001
	for v in out:
		peak = maxf(peak, absf(v))
	var g := 0.8 / peak
	for i in n:
		out[i] = tanh(out[i] * g)
	_music_data = out

func _add_kick(out: PackedFloat32Array, t0: int) -> void:
	var len := int(0.25 * RATE)
	var ph := 0.0
	for i in len:
		if t0 + i >= out.size():
			break
		var t := float(i) / RATE
		ph += TAU * (45.0 + 90.0 * exp(-t * 30.0)) / RATE
		out[t0 + i] += sin(ph) * exp(-t * 12.0) * 0.9

func _add_snare(out: PackedFloat32Array, t0: int, rng: RandomNumberGenerator, amp: float) -> void:
	var len := int(0.15 * RATE)
	for i in len:
		if t0 + i >= out.size():
			break
		var t := float(i) / RATE
		out[t0 + i] += (rng.randf_range(-1, 1) * 0.7 + sin(TAU * 190.0 * t) * 0.4) * exp(-t * 28.0) * amp

func _add_shaker(out: PackedFloat32Array, t0: int, rng: RandomNumberGenerator, amp: float) -> void:
	var len := int(0.05 * RATE)
	var prev := 0.0
	for i in len:
		if t0 + i >= out.size():
			break
		var t := float(i) / RATE
		var nz := rng.randf_range(-1, 1)
		out[t0 + i] += (nz - prev) * exp(-t * 70.0) * amp
		prev = nz

func _add_bass(out: PackedFloat32Array, t0: int, f: float, dur: float) -> void:
	var len := int(dur * RATE)
	for i in len:
		if t0 + i >= out.size():
			break
		var t := float(i) / RATE
		var v := sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)
		out[t0 + i] += v * 0.35 * minf(t * 200.0, 1.0) * exp(-t * 3.0)

func _add_pluck(out: PackedFloat32Array, t0: int, f: float, amp: float, rng: RandomNumberGenerator) -> void:
	var period := maxi(2, int(RATE / f))
	var ring := PackedFloat32Array()
	ring.resize(period)
	for i in period:
		ring[i] = rng.randf_range(-1, 1)
	var len := int(0.45 * RATE)
	var idx := 0
	for i in len:
		if t0 + i >= out.size():
			break
		var nxt := (idx + 1) % period
		var v := ring[idx]
		ring[idx] = (v + ring[nxt]) * 0.497
		out[t0 + i] += v * amp
		idx = nxt

func _to_wav(b: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	for i in b.size():
		bytes.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 32000.0))
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = b.size()
	return w
