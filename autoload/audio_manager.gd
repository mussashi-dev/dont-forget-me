class_name AudioManagerService
extends Node
## Autoload global para direção de áudio, efeitos sonoros procedurais (SFX),
## trilha/ambiência dinâmica por região e controle de silêncio dramático (PROB-11).

static var instance: AudioManagerService = null

signal music_state_changed(new_state: String)

enum MusicState {
	SILENCE,
	BEDROOM_CALM,
	ESQUECIDO_INITIAL,
	VILA_PEACEFUL,
	ESQUECIDO_DEEP,
	BOSS_BATTLE,
	EPILOGUE_WARM
}

var current_music_state: String = "SILENCE"
var master_muted: bool = false
var sfx_volume_db: float = -6.0
var ambient_volume_db: float = -12.0

var _sfx_cache: Dictionary = {}
var _ambient_cache: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _ambient_player: AudioStreamPlayer = null
var _next_sfx_idx: int = 0
const SFX_POOL_SIZE: int = 6
const SAMPLE_RATE: int = 22050

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_players()
	_generate_procedural_library()

static func get_am() -> AudioManagerService:
	return instance

func _init_players() -> void:
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		p.volume_db = sfx_volume_db
		add_child(p)
		_sfx_players.append(p)
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbientPlayer"
	_ambient_player.volume_db = ambient_volume_db
	add_child(_ambient_player)

func _generate_procedural_library() -> void:
	# SFX de Combate e Movimento
	_sfx_cache["physical_hit_1"] = _synth_tone(190.0, 95.0, 0.09, 0.35, true)
	_sfx_cache["physical_hit_2"] = _synth_tone(230.0, 110.0, 0.10, 0.40, true)
	_sfx_cache["physical_hit_3"] = _synth_tone(140.0, 65.0, 0.14, 0.50, true)
	_sfx_cache["sonic_pulse"] = _synth_tone(520.0, 880.0, 0.18, 0.05, false)
	_sfx_cache["dash"] = _synth_tone(340.0, 180.0, 0.10, 0.25, false)
	_sfx_cache["hurt"] = _synth_tone(160.0, 80.0, 0.18, 0.55, true)
	# SFX de Mundo e Interface
	_sfx_cache["crystal_activate"] = _synth_chord([523.25, 659.25, 783.99], 0.32)
	_sfx_cache["pickup_encarte"] = _synth_chord([440.0, 554.37, 659.25, 880.0], 0.38)
	_sfx_cache["dialogue_blip"] = _synth_tone(640.0, 680.0, 0.03, 0.0, false)
	_sfx_cache["wardrobe_slide"] = _synth_tone(110.0, 75.0, 0.28, 0.45, false)
	_sfx_cache["boss_roar"] = _synth_tone(130.0, 55.0, 0.45, 0.65, true)
	_sfx_cache["ui_confirm"] = _synth_chord([587.33, 880.0], 0.14)

	# Ambiências curtas em loop (pads suaves por região)
	_ambient_cache["BEDROOM_CALM"] = _synth_ambient_loop([261.63, 329.63, 392.00], 2.0, 0.22)
	_ambient_cache["ESQUECIDO_INITIAL"] = _synth_ambient_loop([220.00, 261.63, 329.63], 2.0, 0.24)
	_ambient_cache["VILA_PEACEFUL"] = _synth_ambient_loop([293.66, 369.99, 440.00], 2.0, 0.22)
	_ambient_cache["ESQUECIDO_DEEP"] = _synth_ambient_loop([196.00, 233.08, 293.66], 2.0, 0.25)
	_ambient_cache["BOSS_BATTLE"] = _synth_ambient_loop([164.81, 196.00, 246.94], 1.5, 0.30)
	_ambient_cache["EPILOGUE_WARM"] = _synth_ambient_loop([261.63, 329.63, 493.88], 2.0, 0.20)

func play_sfx(sfx_name: String, pitch_scale: float = 1.0) -> void:
	if master_muted or not _sfx_cache.has(sfx_name):
		return
	if _sfx_players.is_empty():
		return
	var p: AudioStreamPlayer = _sfx_players[_next_sfx_idx]
	_next_sfx_idx = (_next_sfx_idx + 1) % _sfx_players.size()
	p.stream = _sfx_cache[sfx_name]
	p.pitch_scale = clampf(pitch_scale, 0.5, 2.0)
	p.volume_db = sfx_volume_db
	p.play()

func set_music_state(state_name: String) -> void:
	if current_music_state == state_name:
		return
	current_music_state = state_name
	music_state_changed.emit(current_music_state)
	if _ambient_player == null:
		return
	if state_name == "SILENCE" or master_muted or not _ambient_cache.has(state_name):
		_ambient_player.stop()
		return
	_ambient_player.stream = _ambient_cache[state_name]
	_ambient_player.volume_db = ambient_volume_db
	_ambient_player.play()

func stop_music_for_dramatic_silence() -> void:
	set_music_state("SILENCE")

func set_music_for_level(level_idx: int) -> void:
	match level_idx:
		1:
			set_music_state("BEDROOM_CALM")
		2, 5, 6:
			set_music_state("ESQUECIDO_INITIAL")
		4:
			set_music_state("VILA_PEACEFUL")
		8, 9:
			set_music_state("ESQUECIDO_DEEP")
		3, 7, 10:
			set_music_state("BOSS_BATTLE")
		_:
			set_music_state("ESQUECIDO_INITIAL")

func _synth_tone(freq_start: float, freq_end: float, duration: float, noise_mix: float, square_wave: bool) -> AudioStreamWAV:
	var samples: int = maxi(64, int(duration * float(SAMPLE_RATE)))
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var env: float = (1.0 - t) * minf(1.0, t * 18.0)
		var freq: float = lerpf(freq_start, freq_end, t)
		phase += (freq / float(SAMPLE_RATE)) * TAU
		var wave: float = (1.0 if sin(phase) >= 0.0 else -1.0) if square_wave else sin(phase)
		if noise_mix > 0.0:
			var pseudo_noise: float = sin(float(i) * 12.9898) * 43758.5453
			pseudo_noise = (pseudo_noise - floor(pseudo_noise)) * 2.0 - 1.0
			wave = lerpf(wave, pseudo_noise, noise_mix)
		var val: int = clampi(int(wave * env * 14000.0), -32767, 32767)
		data.encode_s16(i * 2, val)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav

func _synth_chord(freqs: Array, duration: float) -> AudioStreamWAV:
	var samples: int = maxi(64, int(duration * float(SAMPLE_RATE)))
	var data := PackedByteArray()
	data.resize(samples * 2)
	var count: float = maxf(1.0, float(freqs.size()))
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var env: float = (1.0 - t) * minf(1.0, t * 14.0)
		var sum_wave: float = 0.0
		for f in freqs:
			sum_wave += sin((float(i) / float(SAMPLE_RATE)) * float(f) * TAU)
		var val: int = clampi(int((sum_wave / count) * env * 15000.0), -32767, 32767)
		data.encode_s16(i * 2, val)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav

func _synth_ambient_loop(freqs: Array, duration: float, amplitude: float) -> AudioStreamWAV:
	var samples: int = maxi(256, int(duration * float(SAMPLE_RATE)))
	var data := PackedByteArray()
	data.resize(samples * 2)
	var count: float = maxf(1.0, float(freqs.size()))
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var lfo: float = 0.75 + 0.25 * sin(t * TAU)
		var sum_wave: float = 0.0
		for f in freqs:
			# Usa múltiplos inteiros do ciclo para loop suave
			var cycles: float = round(float(f) * duration)
			sum_wave += sin(t * cycles * TAU)
		var val: int = clampi(int((sum_wave / count) * lfo * amplitude * 12000.0), -32767, 32767)
		data.encode_s16(i * 2, val)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = samples
	wav.data = data
	return wav
