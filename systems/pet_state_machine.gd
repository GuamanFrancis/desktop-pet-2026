class_name PetStateMachine
extends Node
## pet_state_machine.gd — Máquina de Estados Finita
## Gobierna el comportamiento autónomo de la mascota basado en sus stats.

## --- Estados ---
enum State {
	IDLE,      ## Reposo: bobbing suave, mira al cursor
	WALKING,   ## Caminando: se mueve a una posición aleatoria
	SLEEPING,  ## Durmiendo: ojos cerrados, recupera energía
	EATING,    ## Comiendo: animación de masticar
	PLAYING,   ## Jugando: rebote enérgico
	SAD,       ## Triste: movimiento lento, color gris
	MISCHIEF_STEAL_CURSOR, ## Travesura: roba el cursor
	MISCHIEF_SCARE,        ## Travesura: empujoncito al cursor
	MISCHIEF_BLOCK,        ## Travesura: bloquea el centro o cursor
	MISCHIEF_DROP,         ## Travesura: suelta un objeto en pantalla
	MISCHIEF_TREMOR        ## Travesura: tiembla la ventana
}

## --- Señales ---
signal state_changed(old_state: State, new_state: State)
signal walk_requested(target_position: Vector2)
signal action_finished()
signal spawn_dropped_object_requested()
signal show_dialogue_requested(text: String)
signal play_audio_requested(audio_name: String)

## --- Estado Actual ---
var current_state: State = State.IDLE
var _previous_state: State = State.IDLE

## --- Timers Internos ---
var _state_timer: float = 0.0        # Tiempo en estado actual
var _idle_walk_timer: float = 0.0     # Countdown para caminar
var _idle_walk_interval: float = 12.0 # Segundos entre caminatas (aleatorio 8-20)
var _action_duration: float = 0.0     # Duración de acciones temporales
var _action_timer: float = 0.0       # Timer de acción actual
var _original_window_pos: Vector2i = Vector2i.ZERO # Para evitar drift en el tremor

## --- Configuración ---
const SLEEP_THRESHOLD: float = 20.0       # Energía para dormirse
const WAKE_THRESHOLD: float = 60.0        # Energía para despertarse
const SAD_THRESHOLD: float = 25.0         # Felicidad para ponerse triste
const HAPPY_THRESHOLD: float = 50.0       # Felicidad para dejar de estar triste
const WALK_MIN_INTERVAL: float = 8.0      # Mínimo entre caminatas
const WALK_MAX_INTERVAL: float = 20.0     # Máximo entre caminatas
const EATING_DURATION: float = 2.5        # Duración de comer
const PLAYING_DURATION: float = 3.0       # Duración de jugar
const ENERGY_RECOVERY_RATE: float = 0.15  # Energía/seg al dormir


func _ready() -> void:
	_randomize_walk_timer()
	print("[StateMachine] ✅ Máquina de estados inicializada. Estado: IDLE")


func _process(delta: float) -> void:
	_state_timer += delta
	
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.WALKING:
			_process_walking(delta)
		State.SLEEPING:
			_process_sleeping(delta)
		State.EATING:
			_process_eating(delta)
		State.PLAYING:
			_process_playing(delta)
		State.SAD:
			_process_sad(delta)
		State.MISCHIEF_STEAL_CURSOR:
			_process_mischief_steal_cursor(delta)
		State.MISCHIEF_SCARE:
			_process_mischief_scare(delta)
		State.MISCHIEF_BLOCK:
			_process_mischief_block(delta)
		State.MISCHIEF_DROP:
			_process_mischief_drop(delta)
		State.MISCHIEF_TREMOR:
			_process_mischief_tremor(delta)


## --- Procesamiento por Estado ---

func _process_idle(delta: float) -> void:
	var stats := _get_stats()
	if not stats:
		return
	
	# Verificar transiciones automáticas por prioridad
	if stats.energy < SLEEP_THRESHOLD:
		transition_to(State.SLEEPING)
		return
	
	if stats.happiness < SAD_THRESHOLD:
		transition_to(State.SAD)
		return
	
	# Timer para caminar aleatoriamente
	_idle_walk_timer -= delta
	if _idle_walk_timer <= 0.0:
		_start_walking()


func _process_walking(_delta: float) -> void:
	# El movimiento real lo maneja PetMovement
	# Aquí solo verificamos si hay emergencias
	var stats := _get_stats()
	if stats and stats.energy < SLEEP_THRESHOLD * 0.5:
		transition_to(State.SLEEPING)


func _process_sleeping(delta: float) -> void:
	var stats := _get_stats()
	if not stats:
		return
	
	# Recuperar energía mientras duerme
	stats.rest(ENERGY_RECOVERY_RATE * delta)
	
	# Despertar cuando tiene suficiente energía
	if stats.energy >= WAKE_THRESHOLD:
		transition_to(State.IDLE)
		print("[StateMachine] 😊 ¡La mascota se despertó descansada!")


func _process_eating(delta: float) -> void:
	_action_timer += delta
	if _action_timer >= _action_duration:
		transition_to(State.IDLE)
		action_finished.emit()


func _process_playing(delta: float) -> void:
	_action_timer += delta
	if _action_timer >= _action_duration:
		transition_to(State.IDLE)
		action_finished.emit()


func _process_sad(_delta: float) -> void:
	var stats := _get_stats()
	if not stats:
		return
	
	# Salir de tristeza si la felicidad sube
	if stats.happiness >= HAPPY_THRESHOLD:
		transition_to(State.IDLE)
		print("[StateMachine] 😊 ¡La mascota se siente mejor!")


## --- Procesamiento de Travesuras ---

func _process_mischief_steal_cursor(delta: float) -> void:
	_action_timer += delta
	var window := get_window()
	var pet_center := window.position + window.size / 2
	var mouse_pos := DisplayServer.mouse_get_position()

	if _action_timer < 2.0:
		# Fase 1: Moverse rápido hacia el cursor (lo hace Main a través de pet_movement, o aquí directo si está muy cerca)
		# For this state, we assume the pet was told to move near the cursor upon entering the state
		# Once close, it grabs the cursor.
		if Vector2(pet_center).distance_to(Vector2(mouse_pos)) < 150.0:
			DisplayServer.warp_mouse(pet_center)
	elif _action_timer < 4.0:
		# Fase 2: Forzar el cursor a una esquina mientras se mueve
		# Start walking to the corner on exactly frame 2.0
		if _action_timer - delta < 2.0:
			var screen_rect := DisplayServer.screen_get_usable_rect()
			var margin := 80
			var corners := [
				Vector2(screen_rect.position.x + margin, screen_rect.position.y + margin),
				Vector2(screen_rect.position.x + screen_rect.size.x - margin, screen_rect.position.y + margin),
				Vector2(screen_rect.position.x + margin, screen_rect.position.y + screen_rect.size.y - margin),
				Vector2(screen_rect.position.x + screen_rect.size.x - margin, screen_rect.position.y + screen_rect.size.y - margin)
			]
			walk_requested.emit(corners.pick_random())
		DisplayServer.warp_mouse(pet_center)
	else:
		transition_to(State.IDLE)

func _process_mischief_scare(delta: float) -> void:
	_action_timer += delta
	if _action_timer >= 0.5:
		# Fase única: empujón repentino
		var current_mouse := DisplayServer.mouse_get_position()
		var push := Vector2i(randi_range(-50, 50), randi_range(-50, 50))
		if abs(push.x) < 20: push.x = 50 * sign(push.x) if push.x != 0 else 50
		DisplayServer.warp_mouse(current_mouse + push)
		transition_to(State.IDLE)

func _process_mischief_block(delta: float) -> void:
	_action_timer += delta
	if _action_timer >= 5.0:
		transition_to(State.IDLE)

func _process_mischief_drop(delta: float) -> void:
	_action_timer += delta
	if _action_timer >= 1.0:
		transition_to(State.IDLE)

func _process_mischief_tremor(delta: float) -> void:
	_action_timer += delta
	var window := get_window()
	# Temblor vigoroso
	var offset := Vector2i(randi_range(-10, 10), randi_range(-10, 10))
	window.position = _original_window_pos + offset

	if _action_timer >= 2.0:
		window.position = _original_window_pos
		transition_to(State.IDLE)


## --- Transiciones ---

## Cambia al nuevo estado, emitiendo la señal correspondiente.
func transition_to(new_state: State) -> void:
	if new_state == current_state:
		return
	
	# Limpiar estado anterior
	if current_state == State.MISCHIEF_TREMOR:
		get_window().position = _original_window_pos

	_previous_state = current_state
	current_state = new_state
	_state_timer = 0.0
	_action_timer = 0.0
	
	# Configurar nuevo estado
	match new_state:
		State.IDLE:
			_randomize_walk_timer()
		State.EATING:
			_action_duration = EATING_DURATION
		State.PLAYING:
			_action_duration = PLAYING_DURATION
		State.SLEEPING:
			print("[StateMachine] 😴 La mascota se quedó dormida (energía baja)")
		State.SAD:
			print("[StateMachine] 😢 La mascota está triste (felicidad baja)")
		State.MISCHIEF_STEAL_CURSOR:
			var target := DisplayServer.mouse_get_position()
			walk_requested.emit(target)
		State.MISCHIEF_SCARE:
			var target := DisplayServer.mouse_get_position()
			walk_requested.emit(target)
		State.MISCHIEF_BLOCK:
			var screen_rect := DisplayServer.screen_get_usable_rect()
			var target := Vector2(screen_rect.position.x + screen_rect.size.x / 2.0, screen_rect.position.y + screen_rect.size.y / 2.0)
			walk_requested.emit(target)
			show_dialogue_requested.emit("¡Descansa un rato!")
		State.MISCHIEF_DROP:
			spawn_dropped_object_requested.emit()
		State.MISCHIEF_TREMOR:
			play_audio_requested.emit("sad") # Usar audio existente
			_original_window_pos = get_window().position
	
	state_changed.emit(_previous_state, new_state)
	print("[StateMachine] %s → %s" % [State.keys()[_previous_state], State.keys()[new_state]])


## --- Acciones del Usuario ---

## Llamado cuando el usuario alimenta a la mascota.
func trigger_eating() -> void:
	if current_state == State.SLEEPING:
		return  # No interrumpir el sueño
	transition_to(State.EATING)


## Llamado cuando el usuario juega con la mascota.
func trigger_playing() -> void:
	if current_state == State.SLEEPING:
		return
	transition_to(State.PLAYING)


## Llamado cuando la mascota termina de caminar (desde PetMovement).
func on_walk_completed() -> void:
	if current_state == State.WALKING:
		transition_to(State.IDLE)


## --- Utilidades ---

func _start_walking() -> void:
	transition_to(State.WALKING)
	
	# Generar posición aleatoria en la pantalla
	var screen_rect := DisplayServer.screen_get_usable_rect()
	var margin := 80
	var target := Vector2(
		randf_range(screen_rect.position.x + margin, screen_rect.position.x + screen_rect.size.x - margin),
		randf_range(screen_rect.position.y + margin, screen_rect.position.y + screen_rect.size.y - margin)
	)
	walk_requested.emit(target)


func _randomize_walk_timer() -> void:
	_idle_walk_timer = randf_range(WALK_MIN_INTERVAL, WALK_MAX_INTERVAL)


func _get_stats() -> PetStats:
	if SaveManager and SaveManager.pet_stats:
		return SaveManager.pet_stats
	return null


## Retorna el nombre legible del estado actual.
func get_state_name() -> String:
	return State.keys()[current_state]


## Retorna true si la mascota puede ser interrumpida por el usuario.
func can_interact() -> bool:
	return current_state != State.SLEEPING or _state_timer > 2.0
