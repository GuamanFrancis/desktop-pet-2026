extends Node
## audio_manager.gd — Gestor de Audio Centralizado (Autoload)
## Genera SFX procedurales con AudioStreamGenerator.
## No requiere archivos de audio externos.

## --- Configuración ---
const SAMPLE_RATE: float = 22050.0
const MASTER_VOLUME: float = 0.35

## --- Pool de Players ---
var _players: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 4


func _ready() -> void:
	# Crear pool de AudioStreamPlayers
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.volume_db = linear_to_db(MASTER_VOLUME)
		player.bus = "Master"
		add_child(player)
		_players.append(player)
	
	print("[AudioManager] ✅ Sistema de audio inicializado (%d canales)." % POOL_SIZE)


## --- API Pública ---

func play_eat() -> void:
	# Tono ascendente corto (ñam)
	_play_tone_sequence([
		{"freq": 440.0, "dur": 0.06},
		{"freq": 523.0, "dur": 0.06},
		{"freq": 659.0, "dur": 0.08},
	])

func play_play() -> void:
	# 3 notas alegres ascendentes
	_play_tone_sequence([
		{"freq": 523.0, "dur": 0.08},
		{"freq": 659.0, "dur": 0.08},
		{"freq": 784.0, "dur": 0.12},
	])

func play_sleep() -> void:
	# Tono descendente suave
	_play_tone_sequence([
		{"freq": 392.0, "dur": 0.15},
		{"freq": 330.0, "dur": 0.15},
		{"freq": 262.0, "dur": 0.25},
	])

func play_sad() -> void:
	# Tono menor descendente
	_play_tone_sequence([
		{"freq": 330.0, "dur": 0.12},
		{"freq": 294.0, "dur": 0.15},
		{"freq": 262.0, "dur": 0.2},
	])

func play_level_up() -> void:
	# Fanfarria de 5 notas ascendentes
	_play_tone_sequence([
		{"freq": 523.0, "dur": 0.08},
		{"freq": 587.0, "dur": 0.08},
		{"freq": 659.0, "dur": 0.08},
		{"freq": 784.0, "dur": 0.08},
		{"freq": 1047.0, "dur": 0.2},
	])

func play_click() -> void:
	# Click UI corto
	_play_tone_sequence([
		{"freq": 800.0, "dur": 0.025},
		{"freq": 600.0, "dur": 0.02},
	])

func play_notification() -> void:
	# Ding de notificación
	_play_tone_sequence([
		{"freq": 880.0, "dur": 0.06},
		{"freq": 1100.0, "dur": 0.12},
	])


## --- Generación Procedural ---

func _play_tone_sequence(notes: Array) -> void:
	var player := _get_available_player()
	if not player:
		return
	
	# Calcular duración total
	var total_dur := 0.0
	for note: Dictionary in notes:
		total_dur += note["dur"] as float
	
	# Generar buffer
	var total_samples := int(total_dur * SAMPLE_RATE)
	var stream := AudioStreamWAV.new()
	stream.mix_rate = int(SAMPLE_RATE)
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	
	var data := PackedByteArray()
	data.resize(total_samples * 2)  # 16-bit = 2 bytes por muestra
	
	var sample_idx := 0
	for note: Dictionary in notes:
		var freq: float = note["freq"] as float
		var dur: float = note["dur"] as float
		var note_samples := int(dur * SAMPLE_RATE)
		
		for i in range(note_samples):
			if sample_idx >= total_samples:
				break
			
			var t := float(i) / SAMPLE_RATE
			var envelope := 1.0
			
			# ADSR simplificado: attack rápido, decay suave
			var note_progress := float(i) / float(note_samples)
			if note_progress < 0.05:
				envelope = note_progress / 0.05  # Attack
			elif note_progress > 0.6:
				envelope = 1.0 - (note_progress - 0.6) / 0.4  # Release
			
			# Onda sinusoidal + armónico suave
			var sample := sin(t * freq * TAU) * 0.7
			sample += sin(t * freq * 2.0 * TAU) * 0.15  # Armónico 2
			sample += sin(t * freq * 3.0 * TAU) * 0.05  # Armónico 3
			sample *= envelope * 0.5
			
			# Convertir a 16-bit
			var value := int(clampf(sample, -1.0, 1.0) * 32000.0)
			data[sample_idx * 2] = value & 0xFF
			data[sample_idx * 2 + 1] = (value >> 8) & 0xFF
			sample_idx += 1
	
	stream.data = data
	player.stream = stream
	player.play()


func _get_available_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	# Si todos están ocupados, usar el primero (interrumpir)
	return _players[0] if _players.size() > 0 else null
